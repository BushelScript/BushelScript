import Bushel
import AEthereal

public final class RT_Null: RT_Object, Codable {
    
    internal override init(_ rt: Runtime) {
        super.init(rt)
    }
    
    public override class var staticType: Types {
        .null
    }
    
    public override var truthy: Bool {
        false
    }
    
    public override var description: String {
        "null"
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
        switch Types(type.uri) {
        case .string:
            return RT_String(rt, value: "null")
        case .type:
            return RT_Type(rt, value: rt.reflection.types[.null])
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(AEDescriptor.missingValue)
    }
    
    public convenience init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard container.decodeNil() else {
            throw DecodingError.typeMismatch(Self.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Couldn't decode nil"))
        }
        self.init(decoder.userInfo[.rt] as! Runtime)
    }
    
}
