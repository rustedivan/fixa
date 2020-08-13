//
//  FixaCnCApp.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-08-13.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Cocoa
import Combine
import Network
import SwiftUI

class FixaCnCApp: NSObject, NSWindowDelegate {
	var browserWindow: NSWindow!
	var fixaBrowser = FixaBrowser()
	var connectSubject: AnyCancellable!

	var controlWindowControllers: [NSWindowController] = []
	var controlClient: FixaController?
	
	override init() {
		super.init()
		let browserView = BrowserView(availableFixaApps: fixaBrowser.browserResults)
		browserWindow = makeBrowserWindow(forView: browserView)

		connectSubject = browserView.connectSubject
			.sink { (browserResult) in
				self.connectController(to: browserResult)
			}
	}
	
	func connectController(to result: BrowserResult) {
		controlClient = FixaController()
		let controlView = ControlPanelView(clientState: controlClient!.clientState)
		
		controlClient!.openConnection(to: result.endpoint)
		
		let controlWindow = self.makeControlWindow(forView: controlView, appName: result.appName, deviceName: result.deviceName)
		controlWindowControllers.append(NSWindowController(window: controlWindow))
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
													styleMask: [.titled, .miniaturizable, .resizable, .closable, .fullSizeContentView],
													backing: .buffered, defer: true)
		window.center()
		window.title = "\(appName) on \(deviceName)"
		window.setFrameAutosaveName("Control Window")
		window.contentView = NSHostingView(rootView: controlPanel)
		window.makeKeyAndOrderFront(nil)
		window.delegate = self
		return window
	}
	
	func startBrowsing() {
		fixaBrowser.startBrowsing()
	}
	
	func windowWillClose(_ notification: Notification) {
		controlClient!.hangUp()
	}
}
