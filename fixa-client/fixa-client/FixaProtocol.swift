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
class Tweakable<T> {
	fileprivate var value: T { didSet {
			setCallback?(value)
		}
	}
	
	var setCallback: ((T) -> ())?
	
	init(_ value: T, name: Tweakables, _ callback: ((T) -> ())? = nil) {
		self.value = value
		self.setCallback = callback
		self.register(as: name)
	}
	
	func register(as name: Tweakables) {
		switch self {
			case is TweakableBool: TweakableValues.registerBoolInstance(name, instance: self as! TweakableBool)
			case is TweakableFloat: TweakableValues.registerFloatInstance(name, instance: self as! TweakableFloat)
			default: break
		}
	}
}

// Bool tweakable
typealias TweakableBool = Tweakable<Bool>
extension Bool {
	init(_ tweakable: TweakableBool) {
		self = tweakable.value
	}
}

// Float tweakable
typealias TweakableFloat = Tweakable<Float>
extension Float {
	init(_ tweakable: TweakableFloat) {
		self = tweakable.value
	}
}

class TweakableValues {
	private static var _shared: TweakableValues?
	static var shared: TweakableValues { get {	// $ This should be private
			if let shared = _shared {
				return shared
			} else {
				_shared = TweakableValues()
				return _shared!
			}
		}
	}
	
	fileprivate var bools: [Tweakables : (config: FixaTweakable, instances: NSHashTable<TweakableBool>)] = [:]
	fileprivate var floats: [Tweakables : (config: FixaTweakable, instances: NSHashTable<TweakableFloat>)] = [:]
	
	static func listenFor(tweak: FixaTweakable, named name: Tweakables) {
		let shared = TweakableValues.shared
		switch tweak {
			case .bool:
				shared.bools[name] = (tweak, NSHashTable<TweakableBool>(options: [.weakMemory, .objectPointerPersonality]))
			case .float:
				shared.floats[name] = (tweak, NSHashTable<TweakableFloat>(options: [.weakMemory, .objectPointerPersonality]))
			case .none:
				break
		}
	}
	
	static func registerBoolInstance(_ name: Tweakables, instance: TweakableBool) {
		TweakableValues.shared.bools[name]?.instances.add(instance)
		print("Registered bool: \(name)")
	}
	
	static func registerFloatInstance(_ name: Tweakables, instance: TweakableFloat) {
		TweakableValues.shared.floats[name]?.instances.add(instance)
	}
	
	func updateBool(_ name: Tweakables, to value: Bool) {
		guard let instances = TweakableValues.shared.bools[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
	
	func updateFloat(_ name: Tweakables, to value: Float) {
		guard let instances = TweakableValues.shared.floats[name]?.instances.allObjects else { return }
		for instance in instances {
			instance.value = value
		}
	}
}

// MARK: Network packet serialisation
enum FixaTweakable: Codable {
	enum CodingKeys: CodingKey {
		case bool, boolValue
		case float, floatValue, floatMin, floatMax
	}
	
	case none
	case bool(value: Bool)
	case float(value: Float, min: Float, max: Float)
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
			case .bool(let value):
				var boolContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
				try boolContainer.encode(value, forKey: .boolValue)
			case .float(let value, let min, let max):
				var floatContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				try floatContainer.encode(value, forKey: .floatValue)
				try floatContainer.encode(min, forKey: .floatMin)
				try floatContainer.encode(max, forKey: .floatMax)
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
			case .float:
				let floatContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				let value = try floatContainer.decode(Float.self, forKey: .floatValue)
				let min = try floatContainer.decode(Float.self, forKey: .floatMin)
				let max = try floatContainer.decode(Float.self, forKey: .floatMax)
				self = .float(value: value, min: min, max: max)
			case .bool:
				let boolContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
				let value = try boolContainer.decode(Bool.self, forKey: .boolValue)
				self = .bool(value: value)
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
