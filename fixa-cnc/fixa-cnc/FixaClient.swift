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

class ClientState: ObservableObject {
	var clientValueChanged = PassthroughSubject<Void, Never>()
	@Published var connecting: Bool
	@Published var connected: Bool
	@Published var valueDictionary: [String : Float] {
		didSet { clientValueChanged.send() }
	}

	init() {
		connecting = false
		connected = false
		valueDictionary = [
			"Static slider 1": 1.0,
			"Static slider 2": 0.5
		]
	}
}

class FixaClient {
	var clientConnection: NWConnection?
	let clientState: ClientState
	var valueChangedStream: AnyCancellable?
	
	init() {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientState = ClientState()
		
		valueChangedStream = clientState.clientValueChanged
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
						print("Fixa controller: received handshake from app: \(String(data: data!, encoding: .unicode) ?? "malformed message")")
						self.clientState.connected = true
					case .invalid:
						print("Fixa controller: received unknown message type. Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
}
