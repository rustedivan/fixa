//
//  FixaStream.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network
import UIKit

// MARK: App values
class Tweakable<T> {
	fileprivate var value: T { didSet {
			setCallback?(value)
		}
	}
	
	var setCallback: ((T) -> ())?	// $ Remake into a publisher
	
	init(_ value: T, name: Tweakables, _ callback: ((T) -> ())? = nil) {
		self.value = value
		self.setCallback = callback
		self.register(as: name)
	}
	
	func register(as name: Tweakables) {
		switch self {
			case is TweakableBool: FixaRepository.registerBoolInstance(name, instance: self as! TweakableBool)
			case is TweakableFloat: FixaRepository.registerFloatInstance(name, instance: self as! TweakableFloat)
			default: break
		}
	}
}

// Bool tweakable
typealias TweakableBool = Tweakable<Bool>
extension Bool {
	init(_ tweakable: TweakableBool) {
		self = tweakable.value
	}
}

// Float tweakable
typealias TweakableFloat = Tweakable<Float>
extension Float {
	init(_ tweakable: TweakableFloat) {
		self = tweakable.value
	}
}

fileprivate class FixaRepository {
	private static var _shared: FixaRepository?
	fileprivate static var shared: FixaRepository { get {
			if let shared = _shared {
				return shared
			} else {
				_shared = FixaRepository()
				return _shared!
			}
		}
	}
	
	fileprivate var bools: [Tweakables : (config: FixaTweakable, label: String, instances: NSHashTable<TweakableBool>)] = [:]
	fileprivate var floats: [Tweakables : (config: FixaTweakable, label: String, instances: NSHashTable<TweakableFloat>)] = [:]
	
	func addTweak(named name: Tweakables, _ tweak: FixaTweakable) {
		switch tweak {
			case .bool:
				bools[name] = (tweak, name.rawValue, NSHashTable<TweakableBool>(options: [.weakMemory, .objectPointerPersonality]))
			case .float:
				floats[name] = (tweak, name.rawValue, NSHashTable<TweakableFloat>(options: [.weakMemory, .objectPointerPersonality]))
			case .none:
				break
		}
	}
	
	static func registerBoolInstance(_ name: Tweakables, instance: TweakableBool) {
		FixaRepository.shared.bools[name]?.instances.add(instance)
	}
	
	static func registerFloatInstance(_ name: Tweakables, instance: TweakableFloat) {
		FixaRepository.shared.floats[name]?.instances.add(instance)
	}
	
	func updateBool(_ name: Tweakables, to value: Bool) {
		guard let instances = FixaRepository.shared.bools[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
	
	func updateFloat(_ name: Tweakables, to value: Float) {
		guard let instances = FixaRepository.shared.floats[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
}

class FixaStream {
	private var listener: NWListener!
	private var controllerConnection: NWConnection?
	private var tweakConfigurations: FixaTweakables
	private var tweakDictionary: FixaRepository
	
	init(tweakDefinitions: [(Tweakables, FixaTweakable)]) {
		self.tweakConfigurations = [:]
		self.tweakDictionary = FixaRepository.shared
		for (name, definition) in tweakDefinitions {
			self.tweakConfigurations[name.rawValue] = definition
			self.tweakDictionary.addTweak(named: name, definition)
		}
	}

	func startListening() {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		
		do {
			listener = try NWListener(using: parameters)
		} catch let error {
			print("Fixa stream: Could not create listener: \(error.localizedDescription)")
			return
		}
		
		let deviceName = UIDevice.current.name
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
				default: break
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
						if let updatedTweakables = self.parseValueUpdate(valueUpdateData: data) {
							print("Updated \(updatedTweakables.map { $0.key })")
						} else {
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
	
	private func parseValueUpdate(valueUpdateData: Data?) -> FixaTweakables? {
		guard let valueUpdateData = valueUpdateData else {
			print("Fixa stream: received empty value update")
			return nil
		}
		
		guard let tweakables = try? PropertyListDecoder().decode(FixaTweakables.self, from: valueUpdateData) else {
			print("Fixa stream: value update could not be parsed. Disconnecting.")
			return nil
		}
		
		for updatedTweak in tweakables {
			guard let tweakName = Tweakables(rawValue: updatedTweak.key) else { continue }
			switch updatedTweak.value {
				case .bool(let value):
					FixaRepository.shared.updateBool(tweakName, to: value)
				case .float(let value, _, _):
					FixaRepository.shared.updateFloat(tweakName, to: value)
				case .none: break
			}
		}

		return tweakables
	}
}
