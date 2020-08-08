//
//  FixaClient.swift
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

	init() {
		connecting = false
		connected = false
		tweakValues = [:]
	}
	
	func tweakValueBinding(for key: String) -> Binding<Float> {
		return .init(
			get: {
				let tweak = self.tweakValues[key, default: .none]
				switch tweak {
					case .range(let value, _, _): return value
					case .none: return 0.0
				}
			},
			set: {
				let tweak = self.tweakValues[key, default: .none]
				switch tweak {
					case .range(_ , let min, let max):
						self.tweakValues[key] = .range(value: $0, min: min, max: max)
					case .none: break
				}
			})
	}
}

class FixaClient {
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
			}
	}
	
	func openConnection(to endpoint: NWEndpoint) {
		clientState.connecting = true
		let parameters = NWParameters.tcp
		parameters.prohibitedInterfaceTypes = [.loopback]
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
						} else {
							self.clientConnection?.cancel()
					}
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
}
