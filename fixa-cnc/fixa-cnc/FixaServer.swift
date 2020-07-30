//
//  FixaServer.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Combine
import Network
import SwiftUI

var browser: NWBrowser!

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

class FixaServer {
	static let bonjourType = "_fixa._tcp"
	let browserResults: BrowserResults
	var clientConnection: NWConnection?
	
	init() {
		self.browserResults = BrowserResults()
	}
	
	func startBrowsing() {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		browser = NWBrowser(for: .bonjourWithTXTRecord(type: FixaServer.bonjourType, domain: nil), using: parameters)
		browser.stateUpdateHandler = { newState in
			switch newState {
				case .ready: self.browserResults.browsing = true
				default: self.browserResults.browsing = false
			}
		}
		
		browser.browseResultsChangedHandler = { results, changes in
			print("Browse results updated - \(results.count) visible services")
			let fixaApps = results.filter { result in
				if case .service(_, let type, _, _) = result.endpoint, type == FixaServer.bonjourType {
					return true
				} else {
					return false
				}
			}
			self.browserResults.foundApps = fixaApps.compactMap { BrowserResult($0) }
		}
		
		browser.start(queue: .main)
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
					print("Server is connected to client")
					self.receiveMessage()
				default: break
			}
		}
		clientConnection?.start(queue: .main)
		print("Server opened connection: \(String(describing: clientConnection?.endpoint.debugDescription))")
	}
	
	func receiveMessage() {
		clientConnection?.receiveMessage(completion: { (data, context, _, error) in
			if let error = error {
				print(error.localizedDescription)
				
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				print("Server received message from client...")
				print("\(String(data: data!, encoding: .unicode))")
				self.receiveMessage()
			}
		})
	}
}

