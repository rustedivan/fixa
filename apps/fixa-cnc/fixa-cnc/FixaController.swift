//
//  FixaController.swift
//  fixa-cnc
//
//  Created by Ivan Milles on 2020-07-24.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Combine
import Network
import SwiftUI

class ControllerState: ObservableObject {
	var controllerValueChanged = PassthroughSubject<[String], Never>()
	@Published var connecting: Bool
	@Published var connected: Bool
	@Published var fixableValues: NamedFixables {
		didSet { controllerValueChanged.send(dirtyKeys) }
	}
	var dirtyKeys: [String]

	init() {
		connecting = false
		connected = false
		fixableValues = [:]
		dirtyKeys = []
	}
	
	func fixableBoolBinding(for key: String) -> Binding<Bool> {
		let bound = fixableValues[key]
		return .init(
			get: {
				guard case let .bool(value, _) = bound else { return false }
				return value
			},
			set: {
				guard case let .bool(_, i) = bound else { return }
				self.dirtyKeys.append(key)	// Mark the key as dirty before updating the value, otherwise valueChangedStream won't see it
				self.fixableValues[key] = .bool(value: $0, order: i)
			})
	}
	
	func fixableFloatBinding(for key: String) -> Binding<Float> {
		return .init(
			get: {
				guard case let .float(value, _, _, _) = self.fixableValues[key] else { return 0.0 }
				return value
			},
			set: {
				guard case .float(_, let min, let max, let order) = self.fixableValues[key] else { return }
				self.dirtyKeys.append(key)	// Mark the key as dirty before updating the value, otherwise valueChangedStream won't see it
				self.fixableValues[key] = .float(value: $0, min: min, max: max, order: order)
			})
	}
}

class FixaController {
	enum SendFrequency: Double {
		case immediately = 0.0
		case normal = 0.02
		case careful = 0.5
	}
	var clientConnection: NWConnection?
	let clientState: ControllerState
	var valueChangedStream: AnyCancellable?
	
	init(frequency: SendFrequency) {
		let parameters = NWParameters.tcp
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientState = ControllerState()
		
		valueChangedStream = clientState.controllerValueChanged
			.throttle(for: .seconds(frequency.rawValue), scheduler: DispatchQueue.main, latest: true)
			.sink { dirtyKeys in
				let dirtyFixables = self.clientState.fixableValues.filter {
					dirtyKeys.contains($0.key)
				}
				self.sendFixableUpdates(dirtyFixables)
				self.clientState.dirtyKeys = []
			}
	}
	
	func openConnection(to endpoint: NWEndpoint) {
		clientState.connecting = true
		let parameters = NWParameters.tcp
		parameters.prohibitedInterfaceTypes = [.loopback, .wiredEthernet]
		let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
		parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
		clientConnection = NWConnection(to: endpoint, using: parameters)
		clientConnection?.stateUpdateHandler = { newState in
			switch newState {
				case .ready:
					self.receiveMessage()
				default: break
			}
		}
		clientConnection?.start(queue: .main)
		print("Fixa controller: opened connection to \(clientConnection?.endpoint.debugDescription ?? "unknown endpoint")")
	}
	
	func receiveMessage() {
		clientConnection?.receiveMessage(completion: { (data, context, _, error) in
			if let error = error {
				switch error {
					case .posix(let errorCode) where errorCode.rawValue == ECANCELED:
						print("Fixa controller: connection ended.")
					default:
						print("Fixa controller: failed to receive message: \(error)")
				}
			} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
				self.clientState.connecting = false
				switch message.fixaMessageType {
					case .registerFixables:
						if let initialFixables = self.parseRegistration(registrationData: data) {
							self.clientState.fixableValues = initialFixables
							self.clientState.connected = true
							print("Fixa controller: received registration from app: \(initialFixables.count) fixables registered: \(initialFixables.keys)")
							print("Fixa controller: synching back to app")
							self.sendFixableUpdates(self.clientState.fixableValues)
						} else {
							self.clientConnection?.cancel()
						}
					case .hangUp:
						print("Fixa controller: app hung up.")
						self.clientConnection?.cancel()
						self.clientState.connected = false
					case .updateFixables: fallthrough
					case .invalid:
						print("Fixa controller: received unknown message type (\(message.fixaMessageType)). Ignoring.")
				}
				
				self.receiveMessage()
			}
		})
	}
	
	private func parseRegistration(registrationData: Data?) -> NamedFixables? {
		guard let registrationData = registrationData else {
			print("Fixa controller: received empty registration")
			return nil
		}
		
		guard let fixables = try? PropertyListDecoder().decode(NamedFixables.self, from: registrationData) else {
			print("Fixa controller: registration could not be parsed. Disconnecting.")
			return nil
		}

		return fixables
	}
	
	private func sendFixableUpdates(_ dirtyFixables: NamedFixables) {
		let message = NWProtocolFramer.Message(fixaMessageType: .updateFixables)
		let context = NWConnection.ContentContext(identifier: "FixaValues", metadata: [message])
		
		let setupData: Data
		do {
			setupData = try PropertyListEncoder().encode(dirtyFixables)
		} catch let error {
			print("Could not serialize fixables updates: \(error)")
			return
		}
		
		self.clientConnection!.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			if let error = error {
				print("Could not update values: \(error)")
			}
		})
	}
	
	func hangUp() {
		let message = NWProtocolFramer.Message(fixaMessageType: .hangUp)
		let context = NWConnection.ContentContext(identifier: "FixaHangup", metadata: [message])
		
		self.clientConnection!.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { error in
			self.clientConnection!.cancel()
		})
	}
}
