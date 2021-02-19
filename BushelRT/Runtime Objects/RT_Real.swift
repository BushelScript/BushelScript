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
        case .Math_ln:
            return RT_Real(value: log(value))
        case .Math_log10:
            return RT_Real(value: log10(value))
        case .Math_log2:
            return RT_Real(value: log2(value))
        case .Math_sin:
            return RT_Real(value: sin(value))
        case .Math_cos:
            return RT_Real(value: cos(value))
        case .Math_tan:
            return RT_Real(value: tan(value))
        case .Math_asin:
            return RT_Real(value: asin(value))
        case .Math_acos:
            return RT_Real(value: acos(value))
        case .Math_atan:
            return RT_Real(value: atan(value))
        case .Math_atan2:
            guard let xObj = arguments[ParameterInfo(.Math_atan2_x)] else {
                throw MissingParameter(command: command, parameter: ParameterInfo(.Math_atan2_x))
            }
            guard let xReal = xObj.coerce(to: RT_Real.self) else {
                throw WrongParameterType(command: command, parameter: ParameterInfo(.Math_atan2_x), expected: TypeInfo(.number), actual: xObj.dynamicTypeInfo)
            }
            return RT_Real(value: atan2(value, xReal.value))
        case .Math_round:
            return RT_Real(value: round(value))
        case .Math_ceil:
            return RT_Real(value: ceil(value))
        case .Math_floor:
            return RT_Real(value: floor(value))
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch Properties(property.id) {
        case .Math_NaN_Q:
            return RT_Boolean.withValue(value.isNaN)
        case .Math_inf_Q:
            return RT_Boolean.withValue(value.isInfinite)
        case .Math_finite_Q:
            return RT_Boolean.withValue(value.isFinite)
        case .Math_normal_Q:
            return RT_Boolean.withValue(value.isNormal)
        case .Math_zero_Q:
            return RT_Boolean.withValue(value.isZero)
        default:
            throw NoPropertyExists(type: dynamicTypeInfo, property: property)
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
