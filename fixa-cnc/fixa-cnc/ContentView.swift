//
//  ContentView.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	let connectedAppName: String
	let connectedDeviceName: String
	
	var body: some View {
		VStack {
			HStack {
				VStack(alignment: .leading) {
					Text(connectedAppName).font(.title)
					Text("on \(connectedDeviceName)").font(.subheadline)
				}
				Spacer()
			}
			BorderControls(label: "Continent border")
			BorderControls(label: "Country border")
			BorderControls(label: "Province border")
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}
}

struct BorderControls: View {
	let label: String
	let sliderWidth: CGFloat = 200.0
	var body: some View {
		GroupBox(label: Text(label)) {
			HStack {
				Text("Width")
				Spacer()
				Slider(value: .constant(2.0), in: 0.1 ... 10.0)
					.frame(width: sliderWidth)
			}
			HStack {
				Text("Brightness")
				Spacer()
				Slider(value: .constant(0.5), in: 0.0 ... 1.0)
					.frame(width: sliderWidth)
			}
		}
		.padding(.top, 16.0)
	}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
			ContentView(connectedAppName: "Connected App", connectedDeviceName: "connected device")
				.frame(width: 400.0, height: 600.0)
    }
}
