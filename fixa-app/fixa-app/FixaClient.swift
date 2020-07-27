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

func startListening() {
	do {
		listener = try NWListener(using: .tcp)
		let deviceName = UIDevice.current.name
		let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Unknown app"
		
		listener.service = NWListener.Service(name: "\(appName) - \(deviceName)", type: "_fixa._tcp", domain: nil, txtRecord: NWTXTRecord([
			"deviceName": deviceName,
			"appName": appName
		]))
		
		listener.stateUpdateHandler = { newState in
			print(newState)
		}
		
		listener.newConnectionHandler = { connection in
			print(connection)
		}
		
		listener.start(queue: .main)
	} catch (let error) {
		print(error.localizedDescription)
	}
	
}
