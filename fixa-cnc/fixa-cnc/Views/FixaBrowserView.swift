//
//  FixaBrowserView.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-25.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import SwiftUI

struct FixaBrowserView: View {
	@ObservedObject var availableFixaApps: FixaBrowserResults
	var body: some View {
			VStack {
				HStack {
					VStack(alignment: .leading) {
						Text("Fixa clients").font(.title)
						Text("Browsing...").font(.subheadline)
						Text("Found \(availableFixaApps.foundApps.count) apps")
					}
					Spacer()
				}
				Spacer()
			}.padding(16.0)
			 .frame(minWidth: 320.0)
	}
}

struct FixaBrowserView_Previews: PreviewProvider {
	
  static var previews: some View {
		let appList = FixaBrowserResults(apps: ["App 1", "App 2", "App 3"])
		
		return FixaBrowserView(availableFixaApps: appList)
			.frame(width: 400.0, height: 600)
	}
}
