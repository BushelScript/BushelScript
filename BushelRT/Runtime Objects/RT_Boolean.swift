import Bushel
import SwiftAutomation

/// A boolean. Really just a special case of an `RT_Constant`,
/// but modelled as a separate class for convenience.
public class RT_Boolean: RT_Object, AEEncodable {
    
    public let value: Bool
    
    public static let `true` = RT_Boolean(value: true)
    public static let `false` = RT_Boolean(value: false)
    
    public static func withValue(_ value: Bool) -> RT_Boolean {
        return value ? `true` : `false`
    }
    
    private init(value: Bool) {
        self.value = value
    }
    
    public override var description: String {
        return String(describing: value)
    }
    
    public override var debugDescription: String {
        return super.debugDescription + "[value: \(value)]"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.boolean.rawValue, typeBoolean, [.supertype(RT_Object.typeInfo), .name(TermName("boolean"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        return value
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other as? RT_Boolean else {
            return nil
        }
        return value <=> other.value
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch type.code {
        case typeEnumerated:
            // A boolean "is-a" constant
            // This is how AppleScript handles this coercion
            return self
        case typeSInt64:
            return RT_Integer(value: value ? 1 : 0)
        case typeIEEE64BitFloatingPoint:
            return RT_Real(value: value ? 1 : 0)
        case typeUnicodeText:
            return RT_String(value: value ? "true" : "false")
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return NSAppleEventDescriptor(boolean: value)
    }
    
}
