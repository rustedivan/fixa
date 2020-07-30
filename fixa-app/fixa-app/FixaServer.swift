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


class FixaServer {
	var listener: NWListener!
	var clientConnection: NWConnection?

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
		let greeting = "I am \(UIDevice.current.name)".data(using: .unicode)
		self.clientConnection!.send(content: greeting, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			print(error ?? "- Message sent.")
		})
	}
}
