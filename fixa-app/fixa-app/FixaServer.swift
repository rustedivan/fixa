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
	var clientConnection: NWConnection?	// $ Fix this name
	var tweakableValues: FixaTweakables
	
	init(tweakables: FixaTweakables) {
		self.tweakableValues = tweakables
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
			setupData = try PropertyListEncoder().encode(tweakableValues)
		} catch let error {
			print("Could not serialize tweakables dictionary: \(error)")
			return
		}
		
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
							print(updatedTweakables)
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

		return tweakables
	}
}
