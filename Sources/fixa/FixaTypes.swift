//
//  File.swift
//  
//
//  Created by Ivan Milles on 2020-09-16.
//

import Foundation
import Combine
import CoreGraphics.CGColor

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

public struct FixableSetup: Codable {
	public typealias Label = String
	public init(_ label: Label, config: FixableConfig) {
		self.label = label
		self.config = config
	}
	public let label: Label
	let config: FixableConfig
}

public typealias NamedFixables = [FixableSetup.Label : FixableConfig]

public class Fixable<T> {
	public var value: T { didSet {
			newValues.send(value)
		}
	}
	
	public var newValues: PassthroughSubject<T, Never>
	
	public init(_ setup: FixableSetup) {
		do {
			switch setup.config {
				case .bool(let value, _) where value is T:
					self.value = value as! T
				case .float(let value, _, _, _) where value is T:
					self.value = value as! T
				case .color(let value, _) where value is T:
					self.value = value as! T
				default:
					throw(FixaError.typeError("Fixable \"\(setup.label)\" is of type \(T.self) but was setup with \(setup.config)"))
			}
		} catch let error as FixaError {
			fatalError(error.errorDescription)
		} catch {
			fatalError(error.localizedDescription)
		}
		
		self.newValues = PassthroughSubject<T, Never>()
		self.register(as: setup.label)
	}
	
	func register(as name: FixableSetup.Label) {
		FixaRepository.shared.registerInstance(name, instance: self)
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
