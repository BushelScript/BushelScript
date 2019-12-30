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
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object]) -> RT_Object? {
        switch CommandUID(command.uid) {
        case .Math_abs:
            return RT_Real(value: abs(self.value))
        case .Math_sqrt:
            return RT_Real(value: sqrt(self.value))
        case .Math_cbrt:
            return RT_Real(value: cbrt(self.value))
        case .Math_square:
            return RT_Real(value: self.value * self.value)
        case .Math_cube:
            return RT_Real(value: self.value * self.value * self.value)
        case .Math_pow:
            guard let exponent = arguments[ParameterInfo(.Math_pow_exponent)] as? RT_Numeric else {
                // FIXME: Throw error
                return RT_Null.null
            }
            return RT_Real(value: pow(self.value, exponent.numericValue))
        default:
            return super.perform(command: command, arguments: arguments)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch TypeUID(type.uid) {
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
