import Bushel
import AEthereal

/// A runtime type reflected as a dynamic object.
public class RT_Type: RT_Object, Encodable {
    
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let ae4Code = value.uri.ae4Code {
            try container.encode(AE4.AEType(rawValue: ae4Code))
        } else {
            try container.encode(value.uri.normalized)
        }
    }
    
}

extension RT_Type {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}
