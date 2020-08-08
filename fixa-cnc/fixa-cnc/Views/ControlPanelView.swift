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
					TweakableController(value: self.clientState.tweakValueBinding(for: key),
															tweak: self.clientState.tweakValues[key] ?? .none,
															label: key)
				}
			}
			Spacer()
		}.padding(16.0)
		 .frame(minWidth: 320.0)
	}
}

struct TweakableController: View {
	@Binding var tweakValue: Float
	let tweak: FixaTweakable
	let label: String
	let sliderWidth: CGFloat = 200.0
	
	init(value: Binding<Float>, tweak: FixaTweakable, label: String) {
		self.label = label
		_tweakValue = value
		self.tweak = tweak
	}
	
	var body: some View {
		return HStack {
			Text(label)
			Spacer()
			buildContent(tweak: tweak)
		}
	}
	
	// $ XCode12 will allow switch statements in HStack
	func buildContent(tweak: FixaTweakable) -> AnyView {
		switch tweak {
			case .range(_, let min, let max):
				let slider = Slider(value: $tweakValue,
														in: min ... max)
					.frame(width: sliderWidth)
				let stack = HStack {
					Text("\(min)")
					slider
					Text("\(max)")
				}
				return AnyView(stack)

			case .none:
				return AnyView(Text(label))
		}
	}
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
			let previewState = ControllerState()
			previewState.connected = true
			previewState.connecting = false
			previewState.tweakValues = [
				"Slider 1" : .range(value: 0.2, min: 0.0, max: 1.0),
				"Slider 2" : .range(value: 90.0, min: 0.0, max: 360.0)
			]
			return ControlPanelView(clientState: previewState)
				.frame(width: 400.0, height: 600.0)
    }
}
