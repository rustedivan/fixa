//
//  ControlPanelView.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

///////////////////
// $ Until XCode 12
// SwiftUI cannot yet create ActivityIndicator, and Slider config support is too weak.
///////////////////

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

struct ValueSlider: NSViewRepresentable {
	class Coordinator: NSObject {
		@Binding var value: Float
		init(value: Binding<Float>) {
			self._value = value
		}
		@objc func valueChanged(_ sender: NSSlider) {
			self.value = sender.floatValue
		}
	}
	
	@Binding var value: Float
	let minValue: Float
	let maxValue: Float
	typealias NSViewType = NSSlider
	
	func makeCoordinator() -> Coordinator {
		return Coordinator(value: $value)
	}
	
	func makeNSView(context: Context) -> NSSlider {
		let view = NSSlider(value: Double(value),
												minValue: Double(minValue), maxValue: Double(maxValue),
												target: context.coordinator,
												action: #selector(Coordinator.valueChanged(_:)))
		view.numberOfTickMarks = 10
		return view
	}
	
	func updateNSView(_ nsView: NSSlider, context: Context) {
		nsView.floatValue = value
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
						.padding(.bottom)
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
				controller = AnyView(FixableToggle(value: binding, label: name))
			case .float(_, let min, let max):
				let binding = self.clientState.fixableFloatBinding(for: name)
				controller = AnyView(FixableSlider(value: binding, label: name, min: min, max: max))
			case .divider:
				controller = AnyView(Text(name).bold())
			case .none:
				controller = AnyView(Text(name))
		}
		
		return AnyView(
			controller.frame(maxWidth: .infinity)
		)
	}
}

struct FixableToggle: View {
	@Binding var value: Bool
	let label: String
	
	var body: some View {
		HStack{
			Text(label)
			Toggle(isOn: $value) { Text("") }
			Spacer()
		}
	}
}

struct FixableSlider: View {
	@Binding var value: Float
	let label: String
	let min: Float
	let max: Float
	
	var body: some View {
		let format = NumberFormatter()
		format.usesSignificantDigits = true
		format.minimumSignificantDigits = 2
		format.maximumSignificantDigits = 5
		return VStack {
			Text(label).frame(maxWidth: .infinity, alignment: .leading)
			HStack {
				VStack {
					ValueSlider(value: $value, minValue: min, maxValue: max)
					HStack {
						Text(format.string(from: NSNumber(value: min))!).font(.system(size: 10.0)).foregroundColor(.gray)
						Spacer()
						Text(format.string(from: NSNumber(value: max))!).font(.system(size: 10.0)).foregroundColor(.gray)
					}
				}.padding(.leading)
				TextField("", value: $value, formatter: format).frame(maxWidth: 50.0)
			}
		}
	}
}

struct ControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
			let previewState = ControllerState()
			previewState.connected = true
			previewState.connecting = false
			previewState.fixableValues = [
				"Slider 1" : .float(value: 0.5, min: 0.25, max: 1.0),
				"Slider 2" : .float(value: 90.0, min: 0.0, max: 360.55),
				"Toggle" : .bool(value: true)
			]
			return ControlPanelView(clientState: previewState)
				.frame(width: 450.0, height: 600.0)
    }
}
