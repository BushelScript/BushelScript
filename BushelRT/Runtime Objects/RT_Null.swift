import Bushel
import SwiftAutomation

public class RT_Null: RT_Object, AEEncodable {
    
    /// The singleton `null` instance.
    public static let null = RT_Null()
    
    private override init() {
    }
    
    
    private static let typeInfo_ = TypeInfo(.null)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        return false
    }
    
    public override var description: String {
        "null"
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.uid) {
        case .string:
            return RT_String(value: "null")
        case .class:
            return RT_Class(value: RT_Null.typeInfo)
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
