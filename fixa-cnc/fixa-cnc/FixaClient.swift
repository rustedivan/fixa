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

struct BrowserResult {
	let deviceName: String
	let appName: String
	let interfaces: String
	let endpoint: NWEndpoint!
	
	init?(_ nwResult: NWBrowser.Result) {
		guard case .service = nwResult.endpoint else { return nil }
		guard case .bonjour(let metadata) = nwResult.metadata else { return nil }
		
		self.deviceName = metadata.dictionary["deviceName"] ?? "Unknown device"
		self.appName = metadata.dictionary["appName"] ?? "Unknown app"
		self.interfaces = nwResult.interfaces.map { interface in
			switch interface.type {
				case .wifi: return "wifi"
				case .loopback: return "local"
				default: return "other"
			}
		}.joined(separator: " ")
		
		self.endpoint = nwResult.endpoint
	}
}

class BrowserResults: ObservableObject {
	@Published var browsing: Bool
	@Published var foundApps: [BrowserResult]
	
	init() {
		self.browsing = true
		self.foundApps = []
	}
}

class FixaClient {
	let browser: NWBrowser
	let browserResults: BrowserResults
	var clientConnection: NWConnection?
	
	init() {
		self.browserResults = BrowserResults()
		
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		self.browser = NWBrowser(for: .bonjourWithTXTRecord(type: FixaProtocol.bonjourType, domain: nil), using: parameters)
	}
	
	func startBrowsing() {
		browser.stateUpdateHandler = { newState in
			switch newState {
				case .ready: self.browserResults.browsing = true
				default: self.browserResults.browsing = false
			}
		}
		
		browser.browseResultsChangedHandler = { results, changes in
			print("Browse results updated - \(results.count) visible services")
			let fixaApps = results.filter { result in
				if case .service(_, let type, _, _) = result.endpoint, type == FixaProtocol.bonjourType {
					return true
				} else {
					return false
				}
			}
			self.browserResults.foundApps = fixaApps.compactMap { BrowserResult($0) }
		}
		
		browser.start(queue: .main)
	}
	
	func stopBrowsing() {
		browser.cancel()
	}
	
	func openConnection(to endpoint: NWEndpoint) {
		let parameters = NWParameters.tcp
		parameters.prohibitedInterfaceTypes = [.loopback]
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientConnection = NWConnection(to: endpoint, using: parameters)
		clientConnection?.stateUpdateHandler = { newState in
			switch newState {
				case .ready:
					print("Fixa controller: client is connected to app")
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
				switch message.fixaMessageType {
					case .handshake:
						print("Fixa controller: received handshake from app: \(String(data: data!, encoding: .unicode) ?? "malformed message")")
					case .invalid:
						print("Fixa controller: received unknown message type. Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
}

