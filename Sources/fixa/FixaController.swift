//
//  FixaController.swift
//  
//
//  Created by Ivan Milles on 2020-09-16.
//

import Foundation
import Network

public protocol FixaProtocolDelegate {
	func sessionDidStart(_ name: String, withFixables: NamedFixables)
	func sessionDidEnd()
}
fileprivate var sharedProtocolDelegate: FixaProtocolDelegate? = nil

public func fixaInitProtocol(withDelegate delegate: FixaProtocolDelegate) {
	sharedProtocolDelegate = delegate
	let parameters = NWParameters.tcp
	let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
	parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
}

public func fixaMakeConnection(to endpoint: NWEndpoint) -> NWConnection {
	let parameters = NWParameters.tcp
	parameters.prohibitedInterfaceTypes = [.loopback, .wiredEthernet]
	let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
	parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
	return NWConnection(to: endpoint, using: parameters)
}

public func fixaSendUpdates(_ fixables: NamedFixables, over connection: NWConnection) {
	let message = NWProtocolFramer.Message(fixaMessageType: .updateFixables)
	let context = NWConnection.ContentContext(identifier: "FixaValues", metadata: [message])
	
	let setupData: Data
	do {
		let update = FixaMessageUpdate(updates: fixables)
		setupData = try PropertyListEncoder().encode(update)
	} catch let error {
		print("Could not serialize fixables updates: \(error)")
		return
	}
	
	connection.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
		if let error = error {
			print("Could not update values: \(error)")
		}
	})
}

public func fixaReceiveMessage(data: Data?, context: NWConnection.ContentContext?, error: NWError?) {
	if let error = error {
		switch error {
			case .posix(let errorCode) where errorCode.rawValue == ECANCELED:
				print("Fixa controller: connection ended.")
				sharedProtocolDelegate?.sessionDidEnd()
			default:
				print("Fixa controller: failed to receive message: \(error)")
		}
	} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
		switch message.fixaMessageType {
			case .registerFixables:
				if let (streamName, initialFixables) = parseRegistration(registrationData: data) {
					print("Fixa controller: received registration from \(streamName): \(initialFixables.count) fixables registered: \(initialFixables.keys)")
					
					sharedProtocolDelegate?.sessionDidStart(streamName, withFixables: initialFixables)
				} else {
					sharedProtocolDelegate?.sessionDidEnd()
				}
			case .hangUp:
				print("Fixa controller: app hung up.")
				sharedProtocolDelegate?.sessionDidEnd()
			case .updateFixables: fallthrough
			case .invalid:
				print("Fixa controller: received unknown message type (\(message.fixaMessageType)). Ignoring.")
		}
	}
}

public func fixaEndConnection(_ connection: NWConnection) {
	let message = NWProtocolFramer.Message(fixaMessageType: .hangUp)
	let context = NWConnection.ContentContext(identifier: "FixaHangup", metadata: [message])
	
	connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { error in
		connection.cancel()
	})
}

func parseRegistration(registrationData: Data?) -> (String, NamedFixables)? {
	guard let registrationData = registrationData else {
		print("Fixa controller: received empty registration")
		return nil
	}
	
	guard let registration = try? PropertyListDecoder().decode(FixaMessageRegister.self, from: registrationData) else {
		print("Fixa controller: registration could not be parsed. Disconnecting.")
		return nil
	}

	return (registration.streamName, registration.fixables)
}
