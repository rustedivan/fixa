//
//  FixaController.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Combine
import Network
import SwiftUI

class ControllerState: ObservableObject {
	var controllerValueChanged = PassthroughSubject<[String], Never>()
	@Published var connecting: Bool
	@Published var connected: Bool
	@Published var tweakValues: FixaTweakables {
		didSet { controllerValueChanged.send(dirtyKeys) }
	}
	var dirtyKeys: [String]

	init() {
		connecting = false
		connected = false
		tweakValues = [:]
		dirtyKeys = []
	}
	
	func tweakBoolBinding(for key: String) -> Binding<Bool> {
		return .init(
			get: {
				guard case let .bool(value) = self.tweakValues[key] else { return false }
				return value
			},
			set: {
				guard case .bool = self.tweakValues[key] else { return }
				self.dirtyKeys.append(key)	// Mark the key as dirty before updating the value, otherwise valueChangedStream won't see it
				self.tweakValues[key] = .bool(value: $0)
			})
	}
	
	func tweakFloatBinding(for key: String) -> Binding<Float> {
		return .init(
			get: {
				guard case let .float(value, _, _) = self.tweakValues[key] else { return 0.0 }
				return value
			},
			set: {
				guard case .float(_, let min, let max) = self.tweakValues[key] else { return }
				self.dirtyKeys.append(key)	// Mark the key as dirty before updating the value, otherwise valueChangedStream won't see it
				self.tweakValues[key] = .float(value: $0, min: min, max: max)
			})
	}
}

class FixaController {
	enum SendFrequency: Double {
		case immediately = 0.0
		case normal = 0.02
		case careful = 0.5
	}
	var clientConnection: NWConnection?
	let clientState: ControllerState
	var valueChangedStream: AnyCancellable?
	
	init(frequency: SendFrequency) {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientState = ControllerState()
		
		valueChangedStream = clientState.controllerValueChanged
			.throttle(for: .seconds(frequency.rawValue), scheduler: DispatchQueue.main, latest: true)
			.sink { dirtyKeys in
				let dirtyTweakables = self.clientState.tweakValues.filter {
					dirtyKeys.contains($0.key)
				}
				self.sendTweakableUpdates(dirtyTweakables: dirtyTweakables)
				self.clientState.dirtyKeys = []
			}
	}
	
	func openConnection(to endpoint: NWEndpoint) {
		clientState.connecting = true
		let parameters = NWParameters.tcp
		parameters.prohibitedInterfaceTypes = [.loopback, .wiredEthernet]
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientConnection = NWConnection(to: endpoint, using: parameters)
		clientConnection?.stateUpdateHandler = { newState in
			switch newState {
				case .ready:
					self.receiveMessage()
				default: break
			}
		}
		clientConnection?.start(queue: .main)
		print("Fixa controller: opened connection to \(clientConnection?.endpoint.debugDescription ?? "unknown endpoint")")
	}
	
	func receiveMessage() {
		clientConnection?.receiveMessage(completion: { (data, context, _, error) in
			if let error = error {
				switch error {
					case .posix(let errorCode) where errorCode.rawValue == ECANCELED:
						print("Fixa controller: connection ended.")
					default:
						print("Fixa controller: failed to receive message: \(error)")
				}
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				self.clientState.connecting = false
				switch message.fixaMessageType {
					case .registerTweakables:
						if let initialTweakables = self.parseRegistration(registrationData: data) {
							self.clientState.tweakValues = initialTweakables
							self.clientState.connected = true
							print("Fixa controller: received registration from app: \(initialTweakables.count) tweakables registered: \(initialTweakables.keys)")
							print("Fixa controller: synching back to app")
							self.sendTweakableUpdates(dirtyTweakables: self.clientState.tweakValues)
						} else {
							self.clientConnection?.cancel()
						}
					case .hangUp:
						print("Fixa controller: app hung up.")
						self.clientConnection?.cancel()
						self.clientState.connected = false
					case .updateTweakables: fallthrough
					case .invalid:
						print("Fixa controller: received unknown message type (\(message.fixaMessageType)). Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
	
	private func parseRegistration(registrationData: Data?) -> FixaTweakables? {
		guard let registrationData = registrationData else {
			print("Fixa controller: received empty registration")
			return nil
		}
		
		guard let tweakables = try? PropertyListDecoder().decode(FixaTweakables.self, from: registrationData) else {
			print("Fixa controller: registration could not be parsed. Disconnecting.")
			return nil
		}

		return tweakables
	}
	
	private func sendTweakableUpdates(dirtyTweakables: FixaTweakables) {
		let message = NWProtocolFramer.Message(fixaMessageType: .updateTweakables)
		let context = NWConnection.ContentContext(identifier: "FixaValues", metadata: [message])
		
		let setupData: Data
		do {
			setupData = try PropertyListEncoder().encode(dirtyTweakables)
		} catch let error {
			print("Could not serialize tweakable updates: \(error)")
			return
		}
		
		self.clientConnection!.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			if let error = error {
				print("Could not update values: \(error)")
			}
		})
	}
	
	func hangUp() {
		let message = NWProtocolFramer.Message(fixaMessageType: .hangUp)
		let context = NWConnection.ContentContext(identifier: "FixaHangup", metadata: [message])
		
		self.clientConnection!.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			self.clientConnection!.cancel()
		})
	}
}
