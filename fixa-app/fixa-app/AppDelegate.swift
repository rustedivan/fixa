//
//  AppDelegate.swift
//  fixa-app
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import UIKit

enum Tweakables: String {
	case size = "Envelope size"
	case angle = "Envelope angle"
	case open = "Letter read"
}

class VisualEnvelope: ObservableObject {
	@Published var size = TweakableFloat(10.0, name: .size)
	@Published var angle = TweakableFloat(0.0, name: .angle)
	@Published var open = TweakableBool(false, name: .open)
	
	init() {
		// $ Got to be possible to shorten this
		size.setCallback = { _ in self.objectWillChange.send() }	// $ setCallback -> didTweak
		angle.setCallback = { _ in self.objectWillChange.send() }
		open.setCallback = { _ in self.objectWillChange.send() }
	}
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	var envelope: VisualEnvelope?
	
	// $ forward these to TweakableValues.listenFor
	var fixaServer = FixaServer(tweakables: [Tweakables.angle.rawValue : FixaTweakable.float(value: 00.0, min: 0.0, max: 360.0),
																					 Tweakables.size.rawValue :  FixaTweakable.float(value: 50.0, min: 10.0, max: 150.0),
																					 Tweakables.open.rawValue : FixaTweakable.bool(value: false)])

	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		// $ listenForFloat/Bool, don't pass as .float, just take the parameters directly.
		// $ The value: parameters should be sent in the handshake
		// $ Move TweakableValues into the FixaServer
		TweakableValues.listenFor(tweak: .float(value: 5.0, min: 1.0, max: 10.0), named: .size)
		TweakableValues.listenFor(tweak: .float(value: 90.0, min: 0.0, max: 360.0), named: .angle)
		TweakableValues.listenFor(tweak: .bool(value: false), named: .open)
		
		envelope = VisualEnvelope()
		
		fixaServer.startListening()
		return true
	}
	
	// stop/restart the listener
	
	// MARK: UISceneSession Lifecycle

	func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
		// Called when a new scene session is being created.
		// Use this method to select a configuration to create the new scene with.
		return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
	}

	func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
		// Called when the user discards a scene session.
		// If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
		// Use this method to release any resources that were specific to the discarded scenes, as they will not return.
	}

	

}

