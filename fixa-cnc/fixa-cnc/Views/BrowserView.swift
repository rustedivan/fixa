//
//  BrowserView.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-25.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI
import Combine
import Network

struct BrowserView: View {
	@ObservedObject var availableFixaApps: BrowserResults
	var connectSubject = PassthroughSubject<BrowserResult, Never>()
	
	var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text("Fixa clients").font(.title)
				List(availableFixaApps.foundApps, id: \.deviceName) { (result) in
					DeviceCell(device: result) { endpoint in
						self.connectSubject.send(endpoint)
					}
				}
				Spacer()
				Text("Found \(availableFixaApps.foundApps.count) Fixa-enabled apps")
			}
			Spacer()
		}.padding(16.0)
	}
}

struct DeviceCell: View {
	typealias Output = NWEndpoint
	typealias Failure = Never
	
	let device: BrowserResult
	let callback: (BrowserResult) -> ()
	var body: some View {
		HStack {
			VStack(alignment: .leading) {
				Text("\(device.appName) on \(device.deviceName)")
				Text("Available over \(device.interfaces)").font(.caption)
			}
			Spacer()
			Button("Connect") {
				self.callback(self.device)
			}
		}
	}
}

struct BrowserView_Previews: PreviewProvider {
	
  static var previews: some View {
		let appList = BrowserResults()
		appList.foundApps = [BrowserResult(deviceName: "Device 1", appName: "App A", interfaces: "wifi"),
												 BrowserResult(deviceName: "Device 2", appName: "App A", interfaces: "wifi, other")]
		
		return BrowserView(availableFixaApps: appList)
			.frame(width: 400.0, height: 600)
	}
}

extension BrowserResult {
	init(deviceName: String, appName: String, interfaces: String) {
		self.deviceName = deviceName
		self.appName = appName
		self.interfaces = interfaces
		self.endpoint = nil
	}
}
