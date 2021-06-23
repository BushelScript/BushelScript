import Bushel
import AEthereal

/// A runtime type reflected as a dynamic object.
public class RT_Type: RT_Object, AEEncodable {
    
    public var value: Reflection.`Type`
    
    public init(_ rt: Runtime, value: Reflection.`Type`) {
        self.value = value
        super.init(rt)
    }
    
    public override class var staticType: Types {
        .type
    }
    
    public override var description: String {
        "\(value.name as Any? ?? "«type \(value.uri)»")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Type)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        guard let aeCode = value.uri.ae4Code else {
            throw Unencodable(object: self)
        }
        return NSAppleEventDescriptor(typeCode: aeCode)
    }
    
}

extension RT_Type {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}
