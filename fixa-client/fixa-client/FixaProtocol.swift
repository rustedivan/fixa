//
//  FixaProtocol.swift
//  fixa-client
//
//  Created by Ivan Milles on 2020-07-28.
//  Copyright © 2020 Ivan Milles. All rights reserved.
//

import Foundation
import Network

// MARK: Errors
enum FixaError: Error {
	case serializationError(String)
}

// MARK: App values
class FixaValue {
	var value: Float = 0.0
	var key: String
	
	init(_ value: Float, key: String) {
		self.value = value
		self.key = key
		FixaValues.shared.register(self, as: key)
	}
}

class FixaValues {
	private static var _shared: FixaValues? = nil
	static var shared: FixaValues {
		get {
			if let shared = FixaValues._shared {
				return shared
			} else {
				FixaValues._shared = FixaValues()
				return FixaValues._shared!
			}
		}
	}
	
	var allTweakableValues: [String : FixaValue] = [:]
	
	func register(_ fixaValue: FixaValue, as key: String) {
		allTweakableValues[key] = fixaValue
	}
}

// MARK: Network packet serialisation
enum FixaTweakable: Codable {
	enum CodingKeys: CodingKey {
		case range, rangeValue, rangeMin, rangeMax
	}
	
	case none
	case range(value: Float, min: Float, max: Float)
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
			case .range(let value, let min, let max):
				var rangeContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .range)
				try rangeContainer.encode(value, forKey: .rangeValue)
				try rangeContainer.encode(min, forKey: .rangeMin)
				try rangeContainer.encode(max, forKey: .rangeMax)
			case .none:
				break
		}
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		guard let key = container.allKeys.first else {
			throw FixaError.serializationError("FixaTweakable could not be decoded")
		}
		switch key {
			case .range:
				let rangeContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .range)
				let value = try rangeContainer.decode(Float.self, forKey: .rangeValue)
				let min = try rangeContainer.decode(Float.self, forKey: .rangeMin)
				let max = try rangeContainer.decode(Float.self, forKey: .rangeMax)
				self = .range(value: value, min: min, max: max)
			default:
				throw FixaError.serializationError("Unexpected \(key) in tweak packet")
		}
	}
}

typealias FixaTweakables = [String : FixaTweakable]

// MARK: Protocol framing
class FixaProtocol: NWProtocolFramerImplementation {
	enum MessageType: UInt32 {
		case invalid = 0
		case handshake = 1
		case valueUpdates = 2
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
