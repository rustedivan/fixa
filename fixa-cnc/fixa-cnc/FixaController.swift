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
	var controllerValueChanged = PassthroughSubject<Void, Never>()
	@Published var connecting: Bool
	@Published var connected: Bool
	@Published var tweakValues: FixaTweakables {
		didSet { controllerValueChanged.send() }
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
				switch self.tweakValues[key, default: .none] {
					case .bool(let value): return value
					default: return false
				}
			},
			set: {
				self.dirtyKeys.append(key)
				switch self.tweakValues[key, default: .none] {	// $ fucking if case let syntax
					case .bool:
						self.tweakValues[key] = .bool(value: $0)
					default: break
				}
			})
	}
	
	func tweakFloatBinding(for key: String) -> Binding<Float> {
		return .init(
			get: {
				switch self.tweakValues[key, default: .none] {
					case .float(let value, _, _): return value
					default: return 0.0
				}
			},
			set: {
				switch self.tweakValues[key, default: .none] {
					case .float(_ , let min, let max):
						self.tweakValues[key] = .float(value: $0, min: min, max: max)
					default: break
				}
				self.dirtyKeys.append(key)
			})
	}
}

class FixaController {
	var clientConnection: NWConnection?
	let clientState: ControllerState
	var valueChangedStream: AnyCancellable?
	
	init() {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientState = ControllerState()
		
		valueChangedStream = clientState.controllerValueChanged
			.sink {
				let dirtyTweakables = self.clientState.tweakValues.filter {
					self.clientState.dirtyKeys.contains($0.key)
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
				print("Fixa controller: failed to receive message: \(error.localizedDescription)")
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				self.clientState.connecting = false
				switch message.fixaMessageType {
					case .handshake:
						if let initialTweakables = self.parseHandshake(handshakeData: data) {
							self.clientState.tweakValues = initialTweakables
							self.clientState.connected = true
							print("Fixa controller: received handshake from app: \(initialTweakables.count) tweakables registered: \(initialTweakables.keys)")
							print("Fixa controller: synching back to app")
							self.sendTweakableUpdates(dirtyTweakables: self.clientState.tweakValues)
						} else {
							self.clientConnection?.cancel()
						}
					case .valueUpdates:
						print("Fixa controller: received upstream value update. Ignoring.")
					case .invalid:
						print("Fixa controller: received unknown message type. Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
	
	private func parseHandshake(handshakeData: Data?) -> FixaTweakables? {
		guard let handshakeData = handshakeData else {
			print("Fixa controller: received empty handshake")
			return nil
		}
		
		guard let tweakables = try? PropertyListDecoder().decode(FixaTweakables.self, from: handshakeData) else {
			print("Fixa controller: handshake could not be parsed. Disconnecting.")
			return nil
		}

		return tweakables
	}
	
	private func sendTweakableUpdates(dirtyTweakables: FixaTweakables) {
		let message = NWProtocolFramer.Message(fixaMessageType: .valueUpdates)
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
}
