//
//  FixaClient.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network
import UIKit

var listener: NWListener!
var connection: NWConnection?

func startListening() {
	do {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		listener = try NWListener(using: parameters)
		let deviceName = UIDevice.current.name
		let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Unknown app"
		
		listener.service = NWListener.Service(name: "\(appName) - \(deviceName)", type: "_fixa._tcp", domain: nil, txtRecord: NWTXTRecord([
			"deviceName": deviceName,
			"appName": appName
		]))
		
		listener.stateUpdateHandler = { newState in
			switch newState {
				case .ready: print("Client is listening for connections...")
				case .cancelled: print("Client stopped listening for connections.")
				default: break
			}
		}
		
		listener.newConnectionHandler = { newConnection in
			connection = newConnection
			connection!.stateUpdateHandler = { newState in
				switch newState {
					case .ready:
						print("Client connected to \(connection!). Sending message...")
						
						let message = NWProtocolFramer.Message(fixaMessageType: .handshake)
						let context = NWConnection.ContentContext(identifier: "FixaHandshake", metadata: [message])
						let greeting = "I am \(deviceName)".data(using: .unicode)
						connection!.send(content: greeting, contentContext: context, isComplete: true, completion: .contentProcessed { error in
							print(error ?? "- Message sent.")
						})
					case .failed(let error):
						print("Client's connection failed: \(error)")
						connection!.cancel()
					case .cancelled:
						print("Client's connection was cancelled.")
					default: break
				}
			}
			connection!.start(queue: .main)
			print("Opening new connection...")
		}
		
		listener.start(queue: .main)
	} catch (let error) {
		print(error.localizedDescription)
	}
	
}
