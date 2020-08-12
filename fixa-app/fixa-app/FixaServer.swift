//
//  FixaServer.swift
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
	
	var setCallback: ((T) -> ())?
	
	init(_ value: T, name: Tweakables, _ callback: ((T) -> ())? = nil) {
		self.value = value
		self.setCallback = callback
		self.register(as: name)
	}
	
	func register(as name: Tweakables) {
		switch self {
			case is TweakableBool: TweakableValues.registerBoolInstance(name, instance: self as! TweakableBool)
			case is TweakableFloat: TweakableValues.registerFloatInstance(name, instance: self as! TweakableFloat)
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

class TweakableValues {
	private static var _shared: TweakableValues?
	fileprivate static var shared: TweakableValues { get {
			if let shared = _shared {
				return shared
			} else {
				_shared = TweakableValues()
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
		TweakableValues.shared.bools[name]?.instances.add(instance)
	}
	
	static func registerFloatInstance(_ name: Tweakables, instance: TweakableFloat) {
		TweakableValues.shared.floats[name]?.instances.add(instance)
	}
	
	func updateBool(_ name: Tweakables, to value: Bool) {
		guard let instances = TweakableValues.shared.bools[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
	
	func updateFloat(_ name: Tweakables, to value: Float) {
		guard let instances = TweakableValues.shared.floats[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
}

// $ Rename
class FixaServer {
	var listener: NWListener!
	var clientConnection: NWConnection?	// $ Fix this name
	var tweakConfigurations: FixaTweakables
	var tweakDictionary: TweakableValues
	
	init(tweakDefinitions: [(Tweakables, FixaTweakable)]) {
		self.tweakConfigurations = [:]
		self.tweakDictionary = TweakableValues.shared
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
			print("Fixa app: Could not create listener: \(error.localizedDescription)")
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
				case .ready: print("Fixa app: Listening for control client over TCP...")
				case .cancelled: print("Fixa app: Stopped listening for connections.")
				default: break
			}
		}
		
		listener.newConnectionHandler = { (newConnection: NWConnection) in
			if let oldConnection = self.clientConnection {
				print("Fixa app: Moving to new connection...")
				oldConnection.cancel()
			}
			
			self.clientConnection = newConnection
			self.clientConnection!.stateUpdateHandler = { newState in
				switch newState {
					case .ready:
						print("Fixa app: listening to \(self.clientConnection?.endpoint.debugDescription ?? "no endpoint"). Sending handshake...")
						self.receiveMessage()
						self.sendHandshake()
					case .failed(let error):
						print("Fixa app: Connection failed: \(error)")
						self.clientConnection!.cancel()
					case .cancelled:
						print("Fixa app: Connection was cancelled.")
					default: break
				}
			}
			self.clientConnection!.start(queue: .main)
		}
		
		listener.start(queue: .main)
	}
	
	func sendHandshake() {
		let message = NWProtocolFramer.Message(fixaMessageType: .handshake)
		let context = NWConnection.ContentContext(identifier: "FixaHandshake", metadata: [message])
		
		let setupData: Data
		do {
			// $ Send in some kind of order
			setupData = try PropertyListEncoder().encode(tweakConfigurations)
		} catch let error {
			print("Could not serialize tweakables dictionary: \(error)")
			return
		}
		
		// $ This should send the start values set in the model
		self.clientConnection!.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			if let error = error {
				print("Could not handshake: \(error)")
			}
		})
	}
	
	func receiveMessage() {
		clientConnection?.receiveMessage(completion: { (data, context, _, error) in
			if let error = error {
				print("Fixa app: failed to receive message: \(error.localizedDescription)")
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				switch message.fixaMessageType {
					case .valueUpdates:
						if let updatedTweakables = self.parseValueUpdate(valueUpdateData: data) {
							print("Updated \(updatedTweakables.map { $0.key })")
						} else {
							self.clientConnection?.cancel()
						}
					case .handshake:
						print("Fixa app: got a handshake, that's not expected")
					case .invalid:
						print("Fixa controller: received unknown message type. Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
	
	private func parseValueUpdate(valueUpdateData: Data?) -> FixaTweakables? {
		guard let valueUpdateData = valueUpdateData else {
			print("Fixa app: received empty value update")
			return nil
		}
		
		guard let tweakables = try? PropertyListDecoder().decode(FixaTweakables.self, from: valueUpdateData) else {
			print("Fixa app: value update could not be parsed. Disconnecting.")
			return nil
		}
		
		for updatedTweak in tweakables {
			guard let tweakName = Tweakables(rawValue: updatedTweak.key) else { continue }
			switch updatedTweak.value {
				case .bool(let value):
					TweakableValues.shared.updateBool(tweakName, to: value)
				case .float(let value, _, _):
					TweakableValues.shared.updateFloat(tweakName, to: value)
				case .none: break
			}
		}

		return tweakables
	}
}
