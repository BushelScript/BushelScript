import Bushel
import SwiftAutomation

/// A 64-bit integer.
public class RT_Integer: RT_Object, AEEncodable {
    
    public var value: Int64 = 0
    
    public init(value: Int64) {
        self.value = value
    }
    
    public convenience init(value: Int) {
        let value = Int64(value)
        self.init(value: value)
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(.integer)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        value != 0
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        if let other = other as? RT_Integer {
            return value <=> other.value
        } else {
            guard let other = other as? RT_Numeric else {
                return nil
            }
            return self.numericValue <=> other.numericValue
        }
    }
    
    public override func adding(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: self.numericValue + other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value - other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: self.numericValue - other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value * other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: self.numericValue * other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Numeric {
            return RT_Real(value: self.numericValue / other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        switch CommandUID(command.typedUID) {
        case .Math_abs:
            return RT_Integer(value: abs(self.value))
        case .Math_sqrt:
            return RT_Real(value: sqrt(self.numericValue))
        case .Math_cbrt:
            return RT_Real(value: cbrt(self.numericValue))
        case .Math_square:
            let squared = self.value * self.value
            return RT_Integer(value: squared)
        case .Math_cube:
            // Swift likes taking an egregiously long time to typecheck a
            // three-way multiplication…
            // So we split it up to hopefully help matters a little.
            let squared = self.value * self.value
            let cubed = squared * self.value
            return RT_Integer(value: cubed)
        case .Math_pow:
            guard let exponentObj = arguments[ParameterInfo(.Math_pow_exponent)] else {
                throw MissingParameter(command: command, parameter: ParameterInfo(.Math_pow_exponent))
            }
            guard let exponent = exponentObj.coerce(to: RT_Real.self) else {
                throw WrongParameterType(command: command, parameter: ParameterInfo(.Math_pow_exponent), expected: TypeInfo(.number), actual: exponentObj.dynamicTypeInfo)
            }
            return RT_Integer(value: Int64(pow(Double(self.value), exponent.value)))
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch TypeUID(type.typedUID) {
        case .real:
            return RT_Real(value: Double(value))
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return withUnsafePointer(to: value) { valuePointer in
            return NSAppleEventDescriptor(descriptorType: typeSInt64, data: Data(buffer: UnsafeBufferPointer(start: valuePointer, count: 1)))!
        }
    }
    
}

extension RT_Integer: RT_Numeric {
    
    public var numericValue: Double {
        Double(value)
    }
    
}

extension RT_Integer {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
