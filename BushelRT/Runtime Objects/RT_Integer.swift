import Bushel
import SwiftAutomation

/// A 64-bit integer.
public class RT_Integer: RT_Object, AEEncodable {
    
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
            return RT_Integer(rt, value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(rt, value: self.numericValue + other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(rt, value: self.value - other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(rt, value: self.numericValue - other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(rt, value: self.value * other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(rt, value: self.numericValue * other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Numeric {
            return RT_Real(rt, value: self.numericValue / other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.id) {
        case .real:
            return RT_Real(rt, value: Double(value))
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
