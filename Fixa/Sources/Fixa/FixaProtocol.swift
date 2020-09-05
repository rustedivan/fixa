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
	case none
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
			case .none:
				break
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

typealias NamedFixables = [FixableSetup.Label : FixableConfig]

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
