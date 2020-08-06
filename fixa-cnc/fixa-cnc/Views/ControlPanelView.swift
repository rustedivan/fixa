//
//  ControlPanelView.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

/////////////////// $ Until XCode 12
struct ActivityIndicator: NSViewRepresentable {
	typealias NSViewType = NSProgressIndicator
	func makeNSView(context: Context) -> NSProgressIndicator {
		let view = NSProgressIndicator()
		view.isIndeterminate = true
		view.startAnimation(nil)
		view.style = .spinning
		view.controlSize = .small
		return view
	}
	
	func updateNSView(_ nsView: NSProgressIndicator, context: Context) {
	}
}
//////////////////

struct ControlPanelView: View {
	@ObservedObject var clientState: ClientState
	
	var body: some View {
		VStack {
			if clientState.connecting {
				ActivityIndicator()
			} else if clientState.connected {
				BorderControls(value: 0.5, label: "Continent border")
				BorderControls(value: 0.25, label: "Country border")
				BorderControls(value: 0.75, label: "Province border")
			}
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}
}

struct BorderControls: View {
	@State private var widthValue: Float
	@State private var brightnessValue: Float
	let label: String
	let sliderWidth: CGFloat = 200.0
	
	init(value: Float, label: String) {
		self.label = label
		_widthValue = State(initialValue: 10.0 * value)
		_brightnessValue = State(initialValue: value)
	}
	
	var body: some View {
		GroupBox(label: Text(label)) {
			HStack {
				Text("Width")
				Spacer()
				Slider(value: $widthValue, in: 0.1 ... 10.0)
					.frame(width: sliderWidth)
			}
			HStack {
				Text("Brightness")
				Spacer()
				Slider(value: $brightnessValue, in: 0.0 ... 1.0) { val in
					print("Slider changed: \(val)")
				}
				.frame(width: sliderWidth)
			}
		}
		.padding(.top, 16.0)
	}
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
			ControlPanelView(clientState: ClientState())
				.frame(width: 400.0, height: 600.0)
    }
}
