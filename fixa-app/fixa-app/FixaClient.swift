//
//  FixaClient.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network

var listener: NWListener!

func startListening() {
	do {
		listener = try NWListener(using: .tcp)
		listener.service = NWListener.Service(name: "Fixa Client", type: "_fixa._tcp")
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
