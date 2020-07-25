//
//  AppDelegate.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Cocoa
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

	var window: NSWindow!


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		let connectedApp = "Connected app name"
		let connectedDevice = "Connected device"
		// Create the SwiftUI view that provides the window contents.
		let controlPanelView = ControlPanelView(connectedAppName: connectedApp, connectedDeviceName: connectedDevice)

		// Create the window and set the content view. 
		window = NSWindow(
		    contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
		    styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
		    backing: .buffered, defer: false)
		window.center()
		window.setFrameAutosaveName("Main Window")
		window.contentView = NSHostingView(rootView: controlPanelView)
		window.makeKeyAndOrderFront(nil)
		
		startBrowsing()
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}


}

