//
//  FixaStream.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Combine
import Network
#if canImport(UIKit)
	import UIKit.UIDevice
#endif

// MARK: App values
public class Fixable<T> {
	var value: T { didSet {
			newValues.send(value)
		}
	}
	
	public var newValues: PassthroughSubject<T, Never>
	
	public init(_ setup: FixableSetup) {
		do {
			switch setup.config {
				case .bool(let value) where value is T:
					self.value = value as! T
				case .float(let value, _, _) where value is T:
					self.value = value as! T
				case .none:
					throw(FixaError.typeError("Fixable \(setup.label) was setup with FixableConfig.none"))
				default:
					throw(FixaError.typeError("Fixable \"\(setup.label)\" is of type \(T.self) but was setup with \(setup.config)"))
			}
		} catch let error as FixaError {
			fatalError(error.errorDescription)
		} catch {
			fatalError(error.localizedDescription)
		}
		
		self.newValues = PassthroughSubject<T, Never>()
		self.register(as: setup.label)
	}
	
	func register(as name: FixableSetup.Label) {
		FixaRepository.registerInstance(name, instance: self)
	}
}

// Bool tweakable
public typealias FixableBool = Fixable<Bool>
extension Bool {
	public init(_ tweakable: FixableBool) {
		self = tweakable.value
	}
}

// Float tweakable
public typealias FixableFloat = Fixable<Float>
extension Float {
	public init(_ tweakable: FixableFloat) {
		self = tweakable.value
	}
}

fileprivate class FixaRepository {
	private static var _shared: FixaRepository?
	fileprivate static let shared = FixaRepository()
	
	fileprivate var bools: [FixableSetup.Label : (setup: FixableConfig, label: String, instances: NSHashTable<FixableBool>)] = [:]
	fileprivate var floats: [FixableSetup.Label : (setup: FixableConfig, label: String, instances: NSHashTable<FixableFloat>)] = [:]
	
	func addTweak(_ setup: FixableSetup) {
		switch setup.config {
			case .bool:
				bools[setup.label] = (setup.config, setup.label, NSHashTable<FixableBool>(options: [.weakMemory, .objectPointerPersonality]))
			case .float:
				floats[setup.label] = (setup.config, setup.label, NSHashTable<FixableFloat>(options: [.weakMemory, .objectPointerPersonality]))
			case .none:
				break
		}
	}
	
	static func registerInstance<T>(_ name: FixableSetup.Label, instance: Fixable<T>) {
		switch instance {
			case let boolInstance as FixableBool:
				FixaRepository.shared.bools[name]?.instances.add(boolInstance)
			case let floatInstance as FixableFloat:
				FixaRepository.shared.floats[name]?.instances.add(floatInstance)
			default: break
		}
	}
	
	func updateFixable(_ name: FixableSetup.Label, to value: FixableConfig) {
		let repository = FixaRepository.shared
		switch value {
			case .bool(let value):
				guard let instances = repository.bools[name]?.instances.allObjects else { return }
				_ = instances.map { $0.value = value }
			case .float(let value, _, _):
				guard let instances = repository.floats[name]?.instances.allObjects else { return }
				_ = instances.map { $0.value = value }
			case .none: break
		}
	}
}

public class FixaStream {
	private var listener: NWListener!
	private var controllerConnection: NWConnection?
	private var tweakConfigurations: [FixableSetup.Label : FixableConfig]
	private var tweakDictionary: FixaRepository
	
	public init(tweakDefinitions: [FixableSetup]) {	// $ rename
		self.tweakConfigurations = [:]
		self.tweakDictionary = FixaRepository.shared
		
		// $ Add the fixables' indices here
		for definition in tweakDefinitions {
			self.tweakConfigurations[definition.label] = definition.config
			self.tweakDictionary.addTweak(definition)
		}
	}

	public func startListening() {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		
		do {
			listener = try NWListener(using: parameters)
		} catch let error {
			print("Fixa stream: Could not create listener: \(error.localizedDescription)")
			return
		}
		
		#if canImport(UIKit)
			let deviceName = UIDevice.current.name
		#else
			let deviceName = Host.current().name ?? "Unknown device"
		#endif
		let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Unknown app"
		let txtRecord = NWTXTRecord([
			"deviceName": deviceName,
			"appName": appName
		])
		listener.service = NWListener.Service(name: "\(appName) - \(deviceName)", type: FixaProtocol.bonjourType, domain: nil, txtRecord: txtRecord)
		
		listener.stateUpdateHandler = { newState in
			switch newState {
				case .ready: print("Fixa stream: Listening for control client over TCP...")
				case .cancelled: print("Fixa stream: Stopped listening for connections.")
				default: print("Fixa stream: unhandled state transition to \(newState)")
			}
		}
		
		listener.newConnectionHandler = { (newConnection: NWConnection) in
			if let oldConnection = self.controllerConnection {
				print("Fixa stream: Moving to new connection...")
				oldConnection.cancel()
			}
			
			self.controllerConnection = newConnection
			self.controllerConnection!.stateUpdateHandler = { newState in
				switch newState {
					case .ready:
						print("Fixa stream: listening to \(self.controllerConnection?.endpoint.debugDescription ?? "no endpoint"). Registering tweakables...")
						self.receiveMessage()
						self.sendTweakableRegistration()
					case .failed(let error):
						print("Fixa stream: Connection failed: \(error)")
						self.controllerConnection!.cancel()
					case .cancelled:
						print("Fixa stream: Connection was cancelled.")
					default:
						print("Fixa stream: Connection was \(newState)")
						break
				}
			}
			self.controllerConnection!.start(queue: .main)
		}
		
		listener.start(queue: .main)
	}
	
	// $ Can this stay internal?
	func sendTweakableRegistration() {
		let message = NWProtocolFramer.Message(fixaMessageType: .registerTweakables)
		let context = NWConnection.ContentContext(identifier: "FixaRegistration", metadata: [message])
		
		let setupData: Data
		do {
			// $ Send in some kind of order
			setupData = try PropertyListEncoder().encode(tweakConfigurations)
		} catch let error {
			print("Could not serialize tweakables dictionary: \(error)")
			return
		}
		
		self.controllerConnection!.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			if let error = error {
				print("Could not register tweakables: \(error)")
			}
		})
	}
	
	func receiveMessage() {
		controllerConnection?.receiveMessage(completion: { (data, context, _, error) in
			if let error = error {
				switch error {
					case .posix(let errorCode) where errorCode.rawValue == ECANCELED:
						print("Fixa stream: connection ended.")
					default:
						print("Fixa stream: failed to receive message: \(error)")
				}
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				switch message.fixaMessageType {
					case .updateTweakables:
						if !self.applyValueUpdate(valueUpdateData: data) {
							self.controllerConnection?.cancel()
						}
					case .hangUp:
						print("Fixa stream: controller hung up.")
						self.controllerConnection?.cancel()
					// Not valid for stream side
					case .registerTweakables: fallthrough
					case .invalid:
						print("Fixa stream: received unknown message type (\(message.fixaMessageType)). Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
	
	private func applyValueUpdate(valueUpdateData: Data?) -> Bool {
		guard let valueUpdateData = valueUpdateData else {
			print("Fixa stream: received empty value update")
			return false
		}
		
		guard let fixables = try? PropertyListDecoder().decode([FixableSetup.Label : FixableConfig].self, from: valueUpdateData) else {
			print("Fixa stream: value update could not be parsed. Disconnecting.")
			return false
		}
		
		for updatedFixable in fixables {
			FixaRepository.shared.updateFixable(updatedFixable.key, to: updatedFixable.value)
		}

		return true
	}
}
