//
//  ContentView.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@ObservedObject var envelopeState: VisualEnvelope
	var body: some View {
		Image(systemName: envelopeState.open ? "envelope.open.fill" : "envelope.fill")
			.font(.system(size: CGFloat(envelopeState.size)))
			.rotationEffect(Angle(degrees: Double(envelopeState.angle)))
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
		let envelopeState = VisualEnvelope()
		return ContentView(envelopeState: envelopeState)
	}
}
