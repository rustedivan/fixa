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
					self.insertTypedController(self.clientState.tweakValues[key] ?? .none, named: key)
				}
			}
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}

	func insertTypedController(_ tweak: FixableConfig, named name: String) -> AnyView {
		let controller: AnyView
		switch tweak {
			case .bool:
				let binding = self.clientState.tweakBoolBinding(for: name)
				controller = AnyView(TweakableBoolController(value: binding, label: name))
			case .float(_, let min, let max):
				let binding = self.clientState.tweakFloatBinding(for: name)
				controller = AnyView(TweakableFloatController(value: binding, min: min, max: max, label: name))
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

struct TweakableBoolController: View {
	@Binding var tweakValue: Bool
	let label: String
	
	init(value: Binding<Bool>, label: String) {
		self.label = label
		_tweakValue = value
	}
	
	var body: some View {
		Toggle(isOn: $tweakValue) { Text("") }
	}
}

struct TweakableFloatController: View {
	@Binding var tweakValue: Float
	let min: Float
	let max: Float
	let label: String
	let sliderWidth: CGFloat = 200.0
	
	init(value: Binding<Float>, min: Float, max: Float, label: String) {
		self.label = label
		_tweakValue = value
		self.min = min
		self.max = max
	}
	
	var body: some View {
		let slider = Slider(value: $tweakValue, in: min ... max)
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
			previewState.tweakValues = [
				"Slider 1" : .float(value: 0.2, min: 0.0, max: 1.0),
				"Slider 2" : .float(value: 90.0, min: 0.0, max: 360.0),
				"Toggle" : .bool(value: true)
			]
			return ControlPanelView(clientState: previewState)
				.frame(width: 400.0, height: 600.0)
    }
}
