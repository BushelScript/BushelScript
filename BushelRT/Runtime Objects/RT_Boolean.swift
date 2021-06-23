import Bushel
import AEthereal

/// A boolean. Really just a special case of an `RT_Constant`,
/// but modelled as a separate class for convenience.
public class RT_Boolean: RT_Object, AEEncodable {
    
    public let value: Bool
    
    public static func withValue(_ rt: Runtime, _ value: Bool) -> RT_Boolean {
        value ? rt.`true` : rt.`false`
    }
    
    internal init(_ rt: Runtime, value: Bool) {
        self.value = value
        super.init(rt)
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    public override class var staticType: Types {
        .boolean
    }
    
    public override var truthy: Bool {
        value
    }
    
    public static prefix func ! (boolean: RT_Boolean) -> RT_Boolean {
        RT_Boolean.withValue(boolean.rt, !boolean.value)
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_Boolean)
            .map { value <=> $0.value }
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        switch Types(type.id) {
        case .constant:
            // A boolean "is-a" constant
            // This is how AppleScript handles this coercion
            return self
        case .integer:
            return RT_Integer(rt, value: value ? 1 : 0)
        case .real:
            return RT_Real(rt, value: value ? 1 : 0)
        case .string:
            return RT_String(rt, value: value ? "true" : "false")
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(boolean: value)
    }
    
}

extension RT_Boolean {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
