import Bushel
import SwiftAutomation

/// A real number, stored as a `Double`.
public class RT_Real: RT_Object, AEEncodable {
    
    public var value: Double = 0.0
    
    public init(_ rt: Runtime, value: Double) {
        self.value = value
        super.init(rt)
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
        return RT_Real(rt, value: self.value + other.numericValue)
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(rt, value: self.value - other.numericValue)
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(rt, value: self.value * other.numericValue)
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        guard let other = other as? RT_Numeric else {
            return nil
        }
        return RT_Real(rt, value: self.value / other.numericValue)
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object? {
        switch Properties(property.id) {
        case .Math_NaN_Q:
            return RT_Boolean.withValue(rt, value.isNaN)
        case .Math_inf_Q:
            return RT_Boolean.withValue(rt, value.isInfinite)
        case .Math_finite_Q:
            return RT_Boolean.withValue(rt, value.isFinite)
        case .Math_normal_Q:
            return RT_Boolean.withValue(rt, value.isNormal)
        case .Math_zero_Q:
            return RT_Boolean.withValue(rt, value.isZero)
        default:
            return try super.property(property)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.id) {
        case .integer:
            return RT_Integer(rt, value: Int64(value.rounded()))
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
