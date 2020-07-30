//
//  AppDelegate.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Cocoa
import Combine
import Network
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	var window: NSWindow!
	var timer: DispatchSourceTimer!
	var controlClient: FixaClient!
	var connectSubject: AnyCancellable!

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		controlClient = FixaClient()
		
		let controlPanelView = BrowserView(availableFixaApps: controlClient.browserResults)

		// Create the window and set the content view. 
		window = NSWindow(
		    contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
		    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
		    backing: .buffered, defer: false)
		window.center()
		window.setFrameAutosaveName("Main Window")
		window.contentView = NSHostingView(rootView: controlPanelView)
		window.makeKeyAndOrderFront(nil)
		
		controlClient.startBrowsing()
		connectSubject = controlPanelView.connectSubject
			.sink { (endpoint) in
				self.controlClient.stopBrowsing()
				self.controlClient.openConnection(to: endpoint)
			}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

