//
//  FixaBrowser.swift
//  fixa
//
//  Created by Ivan Milles on 2020-08-06.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Combine
import Network
import SwiftUI

public struct BrowserResult {
	public let deviceName: String
	public let appName: String
	public let interfaces: String
	public let endpoint: NWEndpoint!
	
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
		}.joined(separator: "/")
		
		self.endpoint = nwResult.endpoint
	}
	
	public init(deviceName: String, appName: String, interfaces: String) {
		self.deviceName = deviceName
		self.appName = appName
		self.interfaces = interfaces
		self.endpoint = nil
	}
}

public class BrowserResults: ObservableObject {
	@Published public var browsing: Bool
	@Published public var foundApps: [BrowserResult]
	
	public init() {
		self.browsing = true
		self.foundApps = []
	}
}

public class FixaBrowser {
	let browser: NWBrowser
	public let browserResults: BrowserResults
	
	public init() {
		self.browserResults = BrowserResults()
		
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		self.browser = NWBrowser(for: .bonjourWithTXTRecord(type: FixaProtocol.bonjourType, domain: nil), using: parameters)
	}
	
	public func startBrowsing() {
		browser.stateUpdateHandler = { newState in
			switch newState {
				case .ready: self.browserResults.browsing = true
				default: self.browserResults.browsing = false
			}
		}
		
		browser.browseResultsChangedHandler = { results, changes in
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
	
	public func stopBrowsing() {
		browser.cancel()
	}
}
