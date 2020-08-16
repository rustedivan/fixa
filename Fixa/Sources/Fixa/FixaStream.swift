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
	
	public init(_ value: T, name: FixableName.Label) {
		self.value = value
		self.newValues = PassthroughSubject<T, Never>()
		self.register(as: name)
	}
	
	func register(as name: FixableName.Label) {
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
	
	fileprivate var bools: [FixableName.Label : (config: FixaTweakable, label: String, instances: NSHashTable<FixableBool>)] = [:]
	fileprivate var floats: [FixableName.Label : (config: FixaTweakable, label: String, instances: NSHashTable<FixableFloat>)] = [:]
	
	func addTweak(named name: FixableName.Label, _ tweak: FixaTweakable) {
		switch tweak {
			case .bool:
				bools[name] = (tweak, name, NSHashTable<FixableBool>(options: [.weakMemory, .objectPointerPersonality]))
			case .float:
				floats[name] = (tweak, name, NSHashTable<FixableFloat>(options: [.weakMemory, .objectPointerPersonality]))
			case .none:
				break
		}
	}
	
	static func registerInstance<T>(_ name: FixableName.Label, instance: Fixable<T>) {
		switch instance {
			case let boolInstance as FixableBool:
				FixaRepository.shared.bools[name]?.instances.add(boolInstance)
			case let floatInstance as FixableFloat:
				FixaRepository.shared.floats[name]?.instances.add(floatInstance)
			default: break
		}
	}
	
	func updateValue(_ name: FixableName.Label, to value: FixaTweakable) {
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
	private var tweakConfigurations: FixaTweakables
	private var tweakDictionary: FixaRepository
	
	public init(tweakDefinitions: [(FixableName.Label, FixaTweakable)]) {
		self.tweakConfigurations = [:]
		self.tweakDictionary = FixaRepository.shared
		for (name, definition) in tweakDefinitions {
			self.tweakConfigurations[name] = definition
			self.tweakDictionary.addTweak(named: name, definition)
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
		
		guard let tweakables = try? PropertyListDecoder().decode(FixaTweakables.self, from: valueUpdateData) else {
			print("Fixa stream: value update could not be parsed. Disconnecting.")
			return false
		}
		
		for updatedTweak in tweakables {
			FixaRepository.shared.updateValue(updatedTweak.key, to: updatedTweak.value)
		}

		return true
	}
}
