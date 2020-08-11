//
//  ContentView.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

struct ContentView: View {
	@State private var angle = 0.0
	@State private var size = 50.0
	var body: some View {
		Image(systemName: "envelope.fill").font(.system(size: CGFloat(size)))
	}
}

struct ContentView_Previews: PreviewProvider {
	static var previews: some View {
			ContentView()
	}
}
