import Bushel
import AEthereal

/// Something that was received from an Apple Event but couldn't be unboxed
/// to a Bushel runtime type. Can still be introspected by type and
/// sent around in other Apple Events.
public class RT_AEObject: RT_Object, AEEncodable {
    
    public var descriptor: NSAppleEventDescriptor
    
    public init(_ rt: Runtime, descriptor: NSAppleEventDescriptor) {
        self.descriptor = descriptor
        super.init(rt)
    }
    
    public override var type: Reflection.`Type` {
        rt.reflection.types[.ae4(code: descriptor.descriptorType)]
    }
    
    public override var description: String {
        String(describing: descriptor)
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        guard
            let code = type.id.ae4Code,
            let coercedDescriptor = descriptor.coerce(toDescriptorType: code)
        else {
            return nil
        }
        return try? RT_Object.fromAEDescriptor(rt, App(), coercedDescriptor)
    }
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        descriptor
    }
    
}

extension RT_AEObject {
    
    public override var debugDescription: String {
        super.description + "[descriptor: \(descriptor)]"
    }
    
}
