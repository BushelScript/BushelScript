import Bushel
import AEthereal

/// A Unicode "character", stored as a Swift `Character`.
public class RT_Character: RT_Object {
    
    public var value: Character
    
    public init(_ rt: Runtime, value: Character) {
        self.value = value
        super.init(rt)
    }
    
    public override var description: String {
        "(\"\(value)\" as character)"
    }
    
    public override class var staticType: Types {
        .character
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_Character)
            .map { value <=> $0.value }
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        switch Types(type.uri) {
        case .string:
            return RT_String(rt, value: String(value))
        case .integer:
            return value.unicodeScalars.count == 1 ? RT_Integer(rt, value: Int64(value.unicodeScalars.first!.value)) : nil
        default:
            return super.coerce(to: type)
        }
    }
    
}

extension RT_Character {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
