//
//  FixaServer.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network

var browser: NWBrowser!

func startBrowsing() {
	let parameters = NWParameters()
	parameters.includePeerToPeer = true
	browser = NWBrowser(for: .bonjour(type: "_fixa._tcp", domain: nil), using: parameters)
	browser.stateUpdateHandler = { newState in
		print(newState)
	}
	
	browser.browseResultsChangedHandler = { results, changes in
		print(results)
	}
	
	browser.start(queue: .main)
}
