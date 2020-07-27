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
import NetworkExtension
import SwiftUI

var browser: NWBrowser!

struct BrowserResult {
	let deviceName: String
	let appName: String
	let interfaces: String
	let endpoint: NWBonjourServiceEndpoint!
	
	init?(_ nwResult: NWBrowser.Result) {
		guard case .service(let name, let type, let domain, _) = nwResult.endpoint else { return nil }
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
		
		self.endpoint = NWBonjourServiceEndpoint(name: name, type: type, domain: domain)
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
	
	init() {
		self.browserResults = BrowserResults()
	}
	
	func startBrowsing() {
		let parameters = NWParameters()
		parameters.includePeerToPeer = true
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
	
	func openConnection(to endpoint: NWBonjourServiceEndpoint) {
		print("Connecting to \(endpoint)")
	}
}

