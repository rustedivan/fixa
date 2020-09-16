//
//  FixaProtocol.swift
//  fixa-client
//
//  Created by Ivan Milles on 2020-07-28.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network

public struct FixableSetup: Codable {
	public typealias Label = String
	public init(_ label: Label, config: FixableConfig) {
		self.label = label
		self.config = config
	}
	public let label: Label
	let config: FixableConfig
}

// MARK: Errors
enum FixaError: Error {
	case serializationError(String)
	case typeError(String)
	
	var errorDescription: String {
		switch self {
			case .serializationError(let explanation):
				return explanation
			case .typeError(let explanation):
				return explanation
		}
	}
}

// MARK: Network packet serialisation
public enum FixableConfig: Codable {
	enum CodingKeys: CodingKey {
		case order
		case bool, boolValue
		case float, floatValue, floatMin, floatMax
		case divider
	}
	case bool(value: Bool, order: Int = Int.max)
	case float(value: Float, min: Float, max: Float, order: Int = Int.max)
	case divider(order: Int = Int.max)
	
	public var order: Int {
		get {
			switch self {
				case .bool(_, let order): return order
				case .float(_, _, _, let order): return order
				case .divider(let order): return order
				default: return Int.max
			}
		}
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
			case let .bool(value, order):
				var boolContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
				try boolContainer.encode(value, forKey: .boolValue)
				try boolContainer.encode(order, forKey: .order)
			case let .float(value, min, max, order):
				var floatContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				try floatContainer.encode(value, forKey: .floatValue)
				try floatContainer.encode(min, forKey: .floatMin)
				try floatContainer.encode(max, forKey: .floatMax)
				try floatContainer.encode(order, forKey: .order)
			case let .divider(order):
				var dividerContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .divider)
				try dividerContainer.encode(order, forKey: .order)
		}
	}
	
	public init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		guard let key = container.allKeys.first else {
			throw FixaError.serializationError("FixableConfig could not be decoded")
		}
		switch key {
			case .bool:
				let boolContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
				let value = try boolContainer.decode(Bool.self, forKey: .boolValue)
				let order = try boolContainer.decode(Int.self, forKey: .order)
				self = .bool(value: value, order: order)
			case .float:
				let floatContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				let value = try floatContainer.decode(Float.self, forKey: .floatValue)
				let min = try floatContainer.decode(Float.self, forKey: .floatMin)
				let max = try floatContainer.decode(Float.self, forKey: .floatMax)
				let order = try floatContainer.decode(Int.self, forKey: .order)
				self = .float(value: value, min: min, max: max, order: order)
			case .divider:
				let dividerContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .divider)
				let order = try dividerContainer.decode(Int.self, forKey: .order)
				self = .divider(order: order)
			default:
				throw FixaError.serializationError("Unexpected \(key) in fixable config packet")
		}
	}
}

public typealias NamedFixables = [FixableSetup.Label : FixableConfig]

// MARK: Protocol framing
class FixaProtocol: NWProtocolFramerImplementation {
	enum MessageType: UInt32 {
		case invalid = 0
		case registerFixables = 1
		case updateFixables = 2
		case hangUp = 3
	}
	
	static let bonjourType = "_fixa._tcp"
	static let definition = NWProtocolFramer.Definition(implementation: FixaProtocol.self)
	static var label = "Fixa Protocol"
	
	required init(framer: NWProtocolFramer.Instance) { }
	
	func start(framer: NWProtocolFramer.Instance) -> NWProtocolFramer.StartResult {	.ready }
	func wakeup(framer: NWProtocolFramer.Instance) { }
	func stop(framer: NWProtocolFramer.Instance) -> Bool { true }
	func cleanup(framer: NWProtocolFramer.Instance) { }
	
	func handleInput(framer: NWProtocolFramer.Instance) -> Int {
		while true {
			var tempHeader: FixaProtocolHeader? = nil
			let headerSize = FixaProtocolHeader.encodedSize
			let parsed = framer.parseInput(minimumIncompleteLength: headerSize, maximumLength: headerSize) { (buffer, isComplete) -> Int in
				guard let buffer = buffer else { return 0 }
				guard buffer.count >= headerSize else { return 0 }
				tempHeader = FixaProtocolHeader(buffer)
				return headerSize
			}
			
			guard parsed, let header = tempHeader else { return headerSize }
			
			var messageType = FixaProtocol.MessageType.invalid
			if let parsedMessageType = FixaProtocol.MessageType(rawValue: header.type) {
				messageType = parsedMessageType
			}
			
			let message = NWProtocolFramer.Message(fixaMessageType: messageType)
			
			if !framer.deliverInputNoCopy(length: Int(header.length), message: message, isComplete: true) {
				return 0
			}
		}
	}
	
	func handleOutput(framer: NWProtocolFramer.Instance, message: NWProtocolFramer.Message, messageLength: Int, isComplete: Bool) {
		let type = message.fixaMessageType
		let header = FixaProtocolHeader(type: type.rawValue, length: UInt32(messageLength))
		framer.writeOutput(data: header.encodedData)
		
		do {
			try framer.writeOutputNoCopy(length: messageLength)
		} catch let error {
			print("Could not write Fixa message: \(error)")
		}
	}
}

public protocol FixaProtocolDelegate {
	func sessionDidStart(withFixables: NamedFixables)
	func sessionDidEnd()
}
fileprivate var sharedProtocolDelegate: FixaProtocolDelegate? = nil

public func fixaInitProtocol(withDelegate delegate: FixaProtocolDelegate) {
	sharedProtocolDelegate = delegate
	let parameters = NWParameters.tcp
	let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
	parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
}

public func fixaMakeConnection(to endpoint: NWEndpoint) -> NWConnection {
	let parameters = NWParameters.tcp
	parameters.prohibitedInterfaceTypes = [.loopback, .wiredEthernet]
	let protocolOptions = NWProtocolFramer.Options(definition: FixaProtocol.definition)
	parameters.defaultProtocolStack.applicationProtocols.insert(protocolOptions, at: 0)
	return NWConnection(to: endpoint, using: parameters)
}

public func fixaSendUpdates(_ fixables: NamedFixables, over connection: NWConnection) {
	let message = NWProtocolFramer.Message(fixaMessageType: .updateFixables)
	let context = NWConnection.ContentContext(identifier: "FixaValues", metadata: [message])
	
	let setupData: Data
	do {
		setupData = try PropertyListEncoder().encode(fixables)
	} catch let error {
		print("Could not serialize fixables updates: \(error)")
		return
	}
	
	connection.send(content: setupData, contentContext: context, isComplete: true, completion: .contentProcessed { error in
		if let error = error {
			print("Could not update values: \(error)")
		}
	})
}

public func fixaReceiveMessage(data: Data?, context: NWConnection.ContentContext?, error: NWError?) {
	if let error = error {
		switch error {
			case .posix(let errorCode) where errorCode.rawValue == ECANCELED:
				print("Fixa controller: connection ended.")
			default:
				print("Fixa controller: failed to receive message: \(error)")
		}
	} else if let message = context?.protocolMetadata(definition: FixaProtocol.definition) as? NWProtocolFramer.Message {
		switch message.fixaMessageType {
			case .registerFixables:
				if let initialFixables = parseRegistration(registrationData: data) {
					print("Fixa controller: received registration from app: \(initialFixables.count) fixables registered: \(initialFixables.keys)")
					sharedProtocolDelegate?.sessionDidStart(withFixables: initialFixables)
				} else {
					sharedProtocolDelegate?.sessionDidEnd()
				}
			case .hangUp:
				print("Fixa controller: app hung up.")
				sharedProtocolDelegate?.sessionDidEnd()
			case .updateFixables: fallthrough
			case .invalid:
				print("Fixa controller: received unknown message type (\(message.fixaMessageType)). Ignoring.")
		}
	}
}

public func fixaEndConnection(_ connection: NWConnection) {
	let message = NWProtocolFramer.Message(fixaMessageType: .hangUp)
	let context = NWConnection.ContentContext(identifier: "FixaHangup", metadata: [message])
	
	connection.send(content: nil, contentContext: context, isComplete: true, completion: .contentProcessed { error in
		connection.cancel()
	})
}

func parseRegistration(registrationData: Data?) -> NamedFixables? {
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

extension NWProtocolFramer.Message {
	convenience init(fixaMessageType: FixaProtocol.MessageType) {
		self.init(definition: FixaProtocol.definition)
		self["FixaMessageType"] = fixaMessageType
	}
	
	var fixaMessageType: FixaProtocol.MessageType {
		return (self["FixaMessageType"] as? FixaProtocol.MessageType) ?? .invalid
	}
}

struct FixaProtocolHeader: Codable {
	let type: UInt32
	let length: UInt32
	
	init(type: UInt32, length: UInt32) {
		self.type = type
		self.length = length
	}
	
	init(_ buffer: UnsafeMutableRawBufferPointer) {
		var tempType: UInt32 = 0
		var tempLength: UInt32 = 0
		withUnsafeMutableBytes(of: &tempType) { (typePtr) in
			typePtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: 0),
																			 							  count: MemoryLayout<UInt32>.size))
		}
		withUnsafeMutableBytes(of: &tempLength) { (lengthPtr) in
			lengthPtr.copyMemory(from: UnsafeRawBufferPointer(start: buffer.baseAddress!.advanced(by: MemoryLayout<UInt32>.size),
																			 							  count: MemoryLayout<UInt32>.size))
		}
		type = tempType
		length = tempLength
	}
	
	var encodedData: Data {
		var tempType = type
		var tempLength = length
		var data = Data(bytes: &tempType, count: MemoryLayout<UInt32>.size)
		data.append(Data(bytes: &tempLength, count: MemoryLayout<UInt32>.size))
		return data
	}
	
	static var encodedSize: Int {
		return MemoryLayout<UInt32>.size * 2
	}
}
