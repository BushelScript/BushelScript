import Bushel
import SwiftAutomation

/// Something that was received from an Apple Event but couldn't be unboxed
/// to a Bushel runtime type. Can still be introspected by type and
/// sent around in other Apple Events.
public class RT_AEObject: RT_Object {
    
    public let rt: RTInfo
    public var descriptor: NSAppleEventDescriptor
    
    public init(_ rt: RTInfo, descriptor: NSAppleEventDescriptor) {
        self.rt = rt
        self.descriptor = descriptor
    }
    
    public override var description: String {
        return super.description + "[descriptor: \(descriptor)]"
    }
    
    // TODO: Have subclasses simply give code, and then search a passed
    //       dictionary in an extension method to get the class name
    private static let typeInfo_ = TypeInfo(TypeUID.item.rawValue, [.dynamic])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var dynamicTypeInfo: TypeInfo {
        TypeInfo(TypeUID.item.rawValue, descriptor.descriptorType, [])
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        guard
            let code = type.code,
            let coercedDescriptor = descriptor.coerce(toDescriptorType: code)
        else {
            return nil
        }
        return RT_Object.fromEventResult(rt, coercedDescriptor)
    }
    
}
