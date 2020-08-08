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
	@ObservedObject var clientState: ControllerState
	
	var body: some View {
		VStack {
			if clientState.connecting {
				ActivityIndicator()
			} else if clientState.connected {
				ForEach(Array(clientState.tweakValues.keys), id: \.self) { (key) in
					BorderControls(value: self.clientState.tweakValueBinding(for: key), label: key)
				}
			}
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}
}

struct BorderControls: View {
	@Binding var widthValue: Float
	@State private var brightnessValue: Float
	let label: String
	let sliderWidth: CGFloat = 200.0
	
	init(value: Binding<Float>, label: String) {
		self.label = label
		_widthValue = value
		_brightnessValue = State(initialValue: 0.5)
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
				Slider(value: $brightnessValue, in: 0.0 ... 1.0)
					.frame(width: sliderWidth)
			}
		}
		.padding(.top, 16.0)
	}
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
			let previewState = ControllerState()
			previewState.connected = true
			previewState.connecting = false
			previewState.tweakValues = ["Slider 1": 0.5, "Slider 2": 5.2]
			return ControlPanelView(clientState: previewState)
				.frame(width: 400.0, height: 600.0)
    }
}
