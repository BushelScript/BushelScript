import Bushel
import AEthereal

/// Something that was received from an Apple Event but couldn't be unboxed
/// to a Bushel runtime type. Can still be introspected by type and
/// sent around in other Apple Events.
public class RT_AEObject: RT_Object, Encodable {
    
    public var descriptor: AEDescriptor
    
    public init(_ rt: Runtime, descriptor: AEDescriptor) {
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
            let ae4Code = type.id.ae4Code,
            let coercedDescriptor = descriptor.coerce(to: AE4.AEType(rawValue: ae4Code))
        else {
            return nil
        }
        return try? RT_Object.decode(rt, app: App(), aeDescriptor: coercedDescriptor)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(descriptor)
    }
    
}

extension RT_AEObject {
    
    public override var debugDescription: String {
        super.description + "[descriptor: \(descriptor)]"
    }
    
}
