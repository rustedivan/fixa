//
//  NetworkSerialization.swift
//  
//
//  Created by Ivan Milles on 2020-09-16.
//

extension FixableConfig: Codable {
	enum CodingKeys: CodingKey {
		case order
		case bool, boolValue
		case float, floatValue, floatMin, floatMax
		case divider
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
			// $ Possible to encode the enum directly?
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
