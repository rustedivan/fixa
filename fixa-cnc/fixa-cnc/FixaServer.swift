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
		let parameters = NWParameters()
//		parameters.includePeerToPeer = true
		browser = NWBrowser(for: .bonjourWithTXTRecord(type: FixaServer.bonjourType, domain: nil), using: parameters)
		browser.stateUpdateHandler = { newState in
			switch newState {
				case .ready: self.browserResults.browsing = true
				default: self.browserResults.browsing = false
			}
		}
		
		browser.browseResultsChangedHandler = { results, changes in
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
		clientConnection = NWConnection(to: endpoint, using: .tcp)
		clientConnection?.stateUpdateHandler = { newState in
			print("Server's connection \(self.clientConnection) changed state: \(newState)")
		}
//		clientConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65355, completion: { (data, _, _, error) in
		clientConnection?.receiveMessage(completion: { (data, _, _, error) in
			print("Server received message from client...")
			if let error = error {
				print(error.localizedDescription)
			} else if let data = data {
				let message = String(data: data, encoding: .unicode)
				print("Received \"\(message)\"")
			} else {
				print("No data received")
			}
		})
		clientConnection?.start(queue: .main)
		print("Server opened connection: \(clientConnection)")
	}
}

