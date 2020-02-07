import Bushel
import SwiftAutomation

/// Something that was received from an Apple Event but couldn't be unboxed
/// to a Bushel runtime type. Can still be introspected by type and
/// sent around in other Apple Events.
public class RT_AEObject: RT_Object, AEEncodable {
    
    public let rt: RTInfo
    public var descriptor: NSAppleEventDescriptor
    
    public init(_ rt: RTInfo, descriptor: NSAppleEventDescriptor) {
        self.rt = rt
        self.descriptor = descriptor
    }
    
    private static let typeInfo_ = TypeInfo(.item, [.dynamic])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var dynamicTypeInfo: TypeInfo {
        TypeInfo(.ae4(code: descriptor.descriptorType))
    }
    
    public override var description: String {
        String(describing: descriptor)
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        guard
            let code = type.typedUID.ae4Code,
            let coercedDescriptor = descriptor.coerce(toDescriptorType: code)
        else {
            return nil
        }
        return try? RT_Object.fromAEDescriptor(rt, AppData(), coercedDescriptor)
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        descriptor
    }
    
}

extension RT_AEObject {
    
    public override var debugDescription: String {
        super.description + "[descriptor: \(descriptor)]"
    }
    
}
