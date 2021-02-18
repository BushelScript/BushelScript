import Bushel
import SwiftAutomation

/// A real number, stored as a `Double`.
public class RT_Real: RT_Object, AEEncodable {
    
    public var value: Double = 0.0
    
    public init(value: Double) {
        self.value = value
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(.real)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        !value.isZero
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return value <=> other.numericValue
    }
    
    public override func adding(_ other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(value: self.value + other.numericValue)
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(value: self.value - other.numericValue)
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(value: self.value * other.numericValue)
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(value: self.value / other.numericValue)
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        switch Commands(command.id) {
        case .Math_abs:
            return RT_Real(value: abs(self.value))
        case .Math_sqrt:
            return RT_Real(value: sqrt(self.value))
        case .Math_cbrt:
            return RT_Real(value: cbrt(self.value))
        case .Math_square:
            let squared = self.value * self.value
            return RT_Real(value: squared)
        case .Math_cube:
            // Swift likes taking an egregiously long time to typecheck a
            // three-way multiplication…
            // So we split it up to hopefully help matters a little.
            let squared = self.value * self.value
            let cubed = squared * self.value
            return RT_Real(value: cubed)
        case .Math_pow:
            guard let exponentObj = arguments[ParameterInfo(.Math_pow_exponent)] else {
                throw MissingParameter(command: command, parameter: ParameterInfo(.Math_pow_exponent))
            }
            guard let exponent = exponentObj.coerce(to: RT_Real.self) else {
                throw WrongParameterType(command: command, parameter: ParameterInfo(.Math_pow_exponent), expected: TypeInfo(.number), actual: exponentObj.dynamicTypeInfo)
            }
            return RT_Real(value: pow(self.value, exponent.value))
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.id) {
        case .integer:
            return RT_Integer(value: Int64(value.rounded()))
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return NSAppleEventDescriptor(double: value)
    }
    
}

extension RT_Real: RT_Numeric {
    
    public var numericValue: Double {
        value
    }
    
}

extension RT_Real {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
