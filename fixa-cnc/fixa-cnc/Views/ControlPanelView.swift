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
				ForEach(Array(clientState.fixableValues.keys), id: \.self) { (key) in
					self.insertTypedController(self.clientState.fixableValues[key] ?? .none, named: key)
				}
			}
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}

	func insertTypedController(_ fixable: FixableConfig, named name: String) -> AnyView {
		let controller: AnyView
		switch fixable {
			case .bool:
				let binding = self.clientState.fixableBoolBinding(for: name)
				controller = AnyView(FixableToggle(value: binding, label: name))	// $ Could controller side be named "Fixing" and stream side "Fixable"?
			case .float(_, let min, let max):
				let binding = self.clientState.fixableFloatBinding(for: name)
				controller = AnyView(FixableSlider(value: binding, min: min, max: max, label: name))
			case .none:
				controller = AnyView(Text(name))
		}
		
		return AnyView(HStack {
			Text(name)
			Spacer()
			controller
		})
	}
}

struct FixableToggle: View {
	@Binding var fixableValue: Bool
	let label: String
	
	init(value: Binding<Bool>, label: String) {
		self.label = label
		_fixableValue = value
	}
	
	var body: some View {
		Toggle(isOn: $fixableValue) { Text("") }
	}
}

struct FixableSlider: View {
	@Binding var fixableValue: Float
	let min: Float
	let max: Float
	let label: String
	let sliderWidth: CGFloat = 200.0
	
	init(value: Binding<Float>, min: Float, max: Float, label: String) {
		self.label = label
		_fixableValue = value
		self.min = min
		self.max = max
	}
	
	var body: some View {
		let slider = Slider(value: $fixableValue, in: min ... max)
										.frame(width: sliderWidth)
		return HStack {
			Text("\(min)")
			slider
			Text("\(max)")
		}
	}
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
			let previewState = ControllerState()
			previewState.connected = true
			previewState.connecting = false
			previewState.fixableValues = [
				"Slider 1" : .float(value: 0.2, min: 0.0, max: 1.0),
				"Slider 2" : .float(value: 90.0, min: 0.0, max: 360.0),
				"Toggle" : .bool(value: true)
			]
			return ControlPanelView(clientState: previewState)
				.frame(width: 400.0, height: 600.0)
    }
}
