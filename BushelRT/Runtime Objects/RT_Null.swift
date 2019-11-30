import Bushel
import SwiftAutomation

public class RT_Null: RT_Object, AEEncodable {
    
    /// The singleton `null` instance.
    public static let null = RT_Null()
    
    private override init() {
    }
    
    public override var description: String {
        return "null"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.null.rawValue, TypeUID.null.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("null"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        return false
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch type.code {
        case typeUnicodeText:
            return RT_String(value: "null")
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return try MissingValue.encodeAEDescriptor(appData)
    }
    
}

extension RT_Null {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
