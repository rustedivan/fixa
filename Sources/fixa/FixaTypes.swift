//
//  File.swift
//  
//
//  Created by Ivan Milles on 2020-09-16.
//

import Foundation
import Combine
import CoreGraphics.CGColor
#if canImport(UIKit)
import UIKit.UIColor
#endif

public typealias FixableId = UUID

public struct FixableDisplay: Codable {
	public let label: String
	public let order: Int
	public init(_ label: String, order: Int = Int.max) {
		self.label = label
		self.order = order
	}
}

public enum FixableConfig {
	case bool(value: Bool, display: FixableDisplay)
	case float(value: Float, min: Float, max: Float, display: FixableDisplay)
	case color(value: CGColor, display: FixableDisplay)
	case divider(display: FixableDisplay)
	
	public var order: Int {
		get {
			switch self {
				case .bool(_, let display): return display.order
				case .float(_, _, _, let display): return display.order
				case .color(_, let display): return display.order
				case .divider(let display): return display.order
			}
		}
	}
}

public typealias NamedFixables = [FixableId : FixableConfig]

public class Fixable<T> {
	public var value: T { didSet {
			newValues.send(value)
		}
	}
	
	public var newValues: PassthroughSubject<T, Never>
	
	public init(_ key: FixableId, initial: T) {
		self.newValues = PassthroughSubject<T, Never>()
		self.value = initial
		FixaRepository.shared.registerInstance(key, instance: self)
	}
}

// Bool fixable
public typealias FixableBool = Fixable<Bool>
extension Bool {
	public init(_ fixable: FixableBool) {
		self = fixable.value
	}
}

// Float fixable
public typealias FixableFloat = Fixable<Float>
extension Float {
	public init(_ fixable: FixableFloat) {
		self = fixable.value
	}
}

// Color fixable
public typealias FixableColor = Fixable<CGColor>
extension FixableColor {
	#if canImport(UIKit)
	public var uiColorValue: UIColor {
		return UIColor(cgColor: value)
	}
	public var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
		let c = UIColor(cgColor: value)
		var r = CGFloat(0.0); var g = CGFloat(0.0); var b = CGFloat(0.0); var a = CGFloat(1.0)
		c.getRed(&r, green: &g, blue: &b, alpha: &a)
		return (r: r, g: g, b: b, a: a)
	}
	#endif
}

