//
//  AppDelegate.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	var app: FixaCnCApp!
	
	func applicationDidFinishLaunching(_ aNotification: Notification) {
		app = FixaCnCApp()
		app.startBrowsing()
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
}
