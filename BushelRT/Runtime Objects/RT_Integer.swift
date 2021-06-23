import Bushel
import AEthereal

/// A 64-bit integer.
public class RT_Integer: RT_Object {
    
    public var value: Int64 = 0
    
    public init(_ rt: Runtime, value: Int64) {
        self.value = value
        super.init(rt)
    }
    
    public convenience init(_ rt: Runtime, value: Int) {
        self.init(rt, value: Int64(value))
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    public override class var staticType: Types {
        .integer
    }
    
    public override var truthy: Bool {
        value != 0
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        if let other = other as? RT_Integer {
            return self.value <=> other.value
        } else if let other = other.coerce(to: RT_Real.self) {
            return Double(self.value) <=> other.value
        }
        return nil
    }
    
    public override func adding(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(rt, value: self.value + other.value)
        } else if let other = other.coerce(to: RT_Real.self) {
            return RT_Real(rt, value: Double(self.value) + other.value)
        }
        return nil
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(rt, value: self.value - other.value)
        } else if let other = other.coerce(to: RT_Real.self) {
            return RT_Real(rt, value: Double(self.value) - other.value)
        }
        return nil
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(rt, value: self.value * other.value)
        } else if let other = other.coerce(to: RT_Real.self) {
            return RT_Real(rt, value: Double(self.value) * other.value)
        }
        return nil
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        if let other = other.coerce(to: RT_Real.self) {
            return RT_Real(rt, value: Double(self.value) / other.value)
        }
        return nil
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        if type.isA(rt.reflection.types[.real]) {
            return RT_Real(rt, value: Double(value))
        } else {
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        withUnsafePointer(to: value) { valuePointer in
            NSAppleEventDescriptor(descriptorType: typeSInt64, data: Data(buffer: UnsafeBufferPointer(start: valuePointer, count: 1)))!
        }
    }
    
}

extension RT_Integer {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
