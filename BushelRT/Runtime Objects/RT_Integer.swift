import Bushel
import SwiftAutomation

/// A 64-bit integer.
public class RT_Integer: RT_Object, AEEncodable {
    
    public var value: Int64 = 0
    
    public init(value: Int64) {
        self.value = value
    }
    
    public override var description: String {
        return String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.application.rawValue, TypeUID.integer.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("integer"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        return value != 0
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        if let other = other as? RT_Integer {
            return value <=> other.value
        } else {
            guard let other = other as? RT_Numeric else {
                return nil
            }
            return Double(value) <=> other.numericValue
        }
    }
    
    public override func adding(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: Double(self.value) + other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func subtracting(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: Double(self.value) - other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func multiplying(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: Double(self.value) * other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func dividing(by other: RT_Object) -> RT_Object? {
        if let other = other as? RT_Integer {
            return RT_Integer(value: self.value + other.value)
        } else if let other = other as? RT_Numeric {
            return RT_Real(value: Double(self.value) / other.numericValue)
        } else {
            return nil
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [Bushel.ConstantTerm : RT_Object]) -> RT_Object? {
        switch CommandUID(rawValue: command.uid) {
        case .math_abs:
            return RT_Integer(value: abs(self.value))
        default:
            return super.perform(command: command, arguments: arguments)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch TypeUID(rawValue: type.uid) {
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
        return Double(value)
    }
    
}

extension RT_Integer {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
