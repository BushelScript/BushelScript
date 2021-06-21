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
    
    public override class var staticType: Types {
        .real
    }
    
    public override var truthy: Bool {
        !value.isZero
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other.coerce(to: Self.self) else {
            return nil
        }
        return value <=> other.value
    }
    
    public override func adding(_ other: RT_Object) -> RT_Object? {
        guard let other = other.coerce(to: Self.self) else {
            return nil
        }
        return RT_Real(rt, value: self.value + other.value)
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        guard let other = other.coerce(to: Self.self) else {
            return nil
        }
        return RT_Real(rt, value: self.value - other.value)
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        guard let other = other.coerce(to: Self.self) else {
            return nil
        }
        return RT_Real(rt, value: self.value * other.value)
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        guard let other = other.coerce(to: Self.self) else {
            return nil
        }
        return RT_Real(rt, value: self.value / other.value)
    }
    
    public override func property(_ property: Reflection.Property) throws -> RT_Object? {
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
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        if type.isA(rt.reflection.types[.integer]) {
            return RT_Integer(rt, value: Int64(floor(value)))
        } else {
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(double: value)
    }
    
}

extension RT_Real {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
