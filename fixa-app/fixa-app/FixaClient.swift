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
		listener = try NWListener(using: .tcp)
		let deviceName = UIDevice.current.name
		let appName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? "Unknown app"
		
		listener.service = NWListener.Service(name: "\(appName) - \(deviceName)", type: "_fixa._tcp", domain: nil, txtRecord: NWTXTRecord([
			"deviceName": deviceName,
			"appName": appName
		]))
		
		listener.stateUpdateHandler = { newState in
			print("Client's listener changed state: \(newState)")
		}
		
		listener.newConnectionHandler = { newConnection in
			connection = newConnection
			connection!.stateUpdateHandler = { newState in
				print("Client's connection changed state: \(newState)")
				switch newState {
					case .ready:
						DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
							let greeting = "I am \(deviceName)".data(using: .unicode)
							connection!.send(content: greeting, contentContext: .defaultMessage, isComplete: true, completion: .idempotent)
						}
					case .failed(let error):
						print("Client's connection failed: \(error)")
						connection!.cancel()
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
