//
//  FixaStream.swift
//  fixa-app-example
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network
#if canImport(UIKit)
	import UIKit.UIDevice
#endif

class FixaRepository {
	static let shared = FixaRepository()
	
	fileprivate var bools: [FixableId : (setup: FixableConfig, instances: NSHashTable<FixableBool>)] = [:]
	fileprivate var floats: [FixableId : (setup: FixableConfig, instances: NSHashTable<FixableFloat>)] = [:]
	fileprivate var colors: [FixableId : (setup: FixableConfig, instances: NSHashTable<FixableColor>)] = [:]
	
	func addFixable(_ key: FixableId, _ config: FixableConfig) {
		switch config {
			case .bool:
				bools[key] = (config, NSHashTable<FixableBool>(options: [.weakMemory, .objectPointerPersonality]))
			case .float:
				floats[key] = (config, NSHashTable<FixableFloat>(options: [.weakMemory, .objectPointerPersonality]))
			case .color:
				colors[key] = (config, NSHashTable<FixableColor>(options: [.weakMemory, .objectPointerPersonality]))
			case .divider: break
		}
	}
	
	func registerInstance<T>(_ key: FixableId, instance: Fixable<T>) {
		switch instance {
			case let boolInstance as FixableBool:
				bools[key]?.instances.add(boolInstance)
			case let floatInstance as FixableFloat:
				floats[key]?.instances.add(floatInstance)
			case let colorInstance as FixableColor:
				colors[key]?.instances.add(colorInstance)
			default: break
		}
	}
	
	func updateFixable(_ key: FixableId, to value: FixableConfig) {
		let repository = FixaRepository.shared
		switch value {
			case .bool(let value, _):
				guard let instances = repository.bools[key]?.instances.allObjects else { return }
				instances.forEach { $0.value = value }
			case .float(let value, _, _, _):
				guard let instances = repository.floats[key]?.instances.allObjects else { return }
				instances.forEach { $0.value = value }
			case .color(let value, _):
				guard let instances = repository.colors[key]?.instances.allObjects else { return }
				instances.forEach { $0.value = value }
			case .divider: break
		}
	}
	
	func allFixables() -> NamedFixables {
		var out: [FixableId : FixableConfig] = [:]
		for b in bools {
			out[b.key] = b.value.setup
		}
		for f in floats {
			out[f.key] = f.value.setup
		}
		for c in colors {
			out[c.key] = c.value.setup
		}
		return out
	}
}

public class FixaStream {
	public static var DidUpdateValues = Notification.Name(rawValue: "FixaStream.NewValues")
	
	private var streamName: String
	private var listener: NWListener!
	private var controllerConnection: NWConnection?
	private var fixablesDictionary: FixaRepository
	
	public init(fixableSetups definitions: [(FixableId, FixableConfig)]) {
		streamName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Unknown app"
		
		self.fixablesDictionary = FixaRepository.shared
		
		for (i, fixable) in definitions.enumerated() {
			let key = fixable.0
			let config = fixable.1
			var orderedConfig: FixableConfig
			switch config {
				case let .bool(v, d): orderedConfig = .bool(value: v, display: FixableDisplay(d.label, order: i))
				case let .float(v, min, max, d): orderedConfig = .float(value: v, min: min, max: max, display: FixableDisplay(d.label, order: i))
				case let .color(v, d): orderedConfig = .color(value: v, display: FixableDisplay(d.label, order: i))
				case let .divider(d): orderedConfig = .divider(display: FixableDisplay(d.label, order: i))
			}
			self.fixablesDictionary.addFixable(key, orderedConfig)
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
		let txtRecord = NWTXTRecord([
			"deviceName": deviceName,
			"appName": streamName
		])
		listener.service = NWListener.Service(name: "\(streamName) - \(deviceName)", type: FixaProtocol.bonjourType, domain: nil, txtRecord: txtRecord)
		
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
						print("Fixa stream: listening to \(self.controllerConnection?.endpoint.debugDescription ?? "no endpoint"). Registering fixables...")
						self.receiveMessage()
						self.sendFixableRegistration()
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
	
	func sendFixableRegistration() {
		let message = NWProtocolFramer.Message(fixaMessageType: .registerFixables)
		let context = NWConnection.ContentContext(identifier: "FixaRegistration", metadata: [message])
		
		let setupData: Data
		do {
			let registration = FixaMessageRegister(streamName: streamName,
																						 fixables: fixablesDictionary.allFixables())
			setupData = try PropertyListEncoder().encode(registration)
		} catch let error {
			print("Could not serialize fixables dictionary: \(error)")
			return
		}
		
		self.controllerConnection!.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			if let error = error {
				print("Could not register fixables: \(error)")
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
					case .updateFixables:
						if !self.applyValueUpdate(valueUpdateData: data) {
							self.controllerConnection?.cancel()
						}
					case .hangUp:
						print("Fixa stream: controller hung up.")
						self.controllerConnection?.cancel()
					// Not valid for stream side
					case .registerFixables: fallthrough
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
		
		guard let update = try? PropertyListDecoder().decode(FixaMessageUpdate.self, from: valueUpdateData) else {
			print("Fixa stream: value update could not be parsed. Disconnecting.")
			return false
		}
		
		for updatedFixable in update.updates {
			FixaRepository.shared.updateFixable(updatedFixable.key, to: updatedFixable.value)
		}
		
		let fixableNames = update.updates.map { $0.key }
		NotificationCenter.default.post(name: FixaStream.DidUpdateValues, object: fixableNames)

		return true
	}
}
