//
//  NetworkSerialization.swift
//  
//
//  Created by Ivan Milles on 2020-09-16.
//

import CoreGraphics.CGColor

extension FixableConfig: Codable {
	enum CodingKeys: CodingKey {
		case display
		case bool, boolValue
		case float, floatValue, floatMin, floatMax
		case color, colorRed, colorGreen, colorBlue, colorAlpha
		case divider
	}
	
	public func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		switch self {
			case let .bool(value, display):
				var boolContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .bool)
				try boolContainer.encode(value, forKey: .boolValue)
				try boolContainer.encode(display, forKey: .display)
			case let .float(value, min, max, display):
				var floatContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				try floatContainer.encode(value, forKey: .floatValue)
				try floatContainer.encode(min, forKey: .floatMin)
				try floatContainer.encode(max, forKey: .floatMax)
				try floatContainer.encode(display, forKey: .display)
			case let .color(value, display):
				let rgbColor = value.converted(to: CGColorSpace(name: CGColorSpace.sRGB)!, intent: .defaultIntent, options: nil)
				let components = rgbColor!.components!
				var colorContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .color)
				try colorContainer.encode(components[0], forKey: .colorRed)
				try colorContainer.encode(components[1], forKey: .colorGreen)
				try colorContainer.encode(components[2], forKey: .colorBlue)
				try colorContainer.encode(components[3], forKey: .colorAlpha)
				try colorContainer.encode(display, forKey: .display)
			case let .divider(display):
				var dividerContainer = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .divider)
				try dividerContainer.encode(display, forKey: .display)
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
				let display = try boolContainer.decode(FixableDisplay.self, forKey: .display)
				self = .bool(value: value, display: display)
			case .float:
				let floatContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .float)
				let value = try floatContainer.decode(Float.self, forKey: .floatValue)
				let min = try floatContainer.decode(Float.self, forKey: .floatMin)
				let max = try floatContainer.decode(Float.self, forKey: .floatMax)
				let display = try floatContainer.decode(FixableDisplay.self, forKey: .display)
				self = .float(value: value, min: min, max: max, display: display)
			case .color:
				let colorContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .color)
				let red = try colorContainer.decode(CGFloat.self, forKey: .colorRed)
				let green = try colorContainer.decode(CGFloat.self, forKey: .colorGreen)
				let blue = try colorContainer.decode(CGFloat.self, forKey: .colorBlue)
				let alpha = try colorContainer.decode(CGFloat.self, forKey: .colorAlpha)
				let display = try colorContainer.decode(FixableDisplay.self, forKey: .display)
				let cgColor = CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
				self = .color(value: cgColor, display: display)
			case .divider:
				let dividerContainer = try container.nestedContainer(keyedBy: CodingKeys.self, forKey: .divider)
				let display = try dividerContainer.decode(FixableDisplay.self, forKey: .display)
				self = .divider(display: display)
			case .boolValue, .floatValue, .floatMin, .floatMax, .colorRed, .colorGreen, .colorBlue, .colorAlpha, .display:
				throw FixaError.serializationError("Unexpected \(key) in fixable config packet")
		}
	}
}
