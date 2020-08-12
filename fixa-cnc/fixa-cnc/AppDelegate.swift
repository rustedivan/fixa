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

	var browserWindow: NSWindow!
	var fixaBrowser: FixaBrowser!
	var connectSubject: AnyCancellable!

	var controlWindow: NSWindow?
	var controlClient: FixaController?
	var messageSubject: AnyCancellable!
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		fixaBrowser = FixaBrowser()
		
		let browserView = BrowserView(availableFixaApps: fixaBrowser.browserResults)
		browserWindow = makeBrowserWindow(forView: browserView)
		
		connectSubject = browserView.connectSubject
			.sink { (browserResult) in
				self.fixaBrowser.stopBrowsing()
				
				let controlClient = FixaController()
				let controlView = ControlPanelView(clientState: controlClient.clientState)
				controlClient.openConnection(to: browserResult.endpoint)
				self.controlClient = controlClient
				self.controlWindow = self.makeControlWindow(forView: controlView, appName: browserResult.appName, deviceName: browserResult.deviceName)
			}
		fixaBrowser.startBrowsing()
	}

	func makeBrowserWindow(forView browser: BrowserView) -> NSWindow {
		// Create the window and set the content view.
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 300),
													styleMask: [.titled, .miniaturizable, .resizable, .fullSizeContentView],
														backing: .buffered, defer: false)
		window.center()
		window.setFrameAutosaveName("Main Window")
		window.contentView = NSHostingView(rootView: browser)
		window.makeKeyAndOrderFront(nil)
		return window
	}
	
	func makeControlWindow(forView controlPanel: ControlPanelView, appName: String, deviceName: String) -> NSWindow {
		// Create the window and set the content view.
		let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
													styleMask: [.titled, .miniaturizable, .resizable, .fullSizeContentView],
														backing: .buffered, defer: false)
		window.center()
		window.title = "\(appName) on \(deviceName)"
		window.setFrameAutosaveName("Control Window")
		window.contentView = NSHostingView(rootView: controlPanel)
		window.makeKeyAndOrderFront(nil)
		return window
	}
	
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
}
