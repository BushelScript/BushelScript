import Bushel
import AEthereal

public final class RT_Unspecified: RT_Object, Codable {
    
    internal override init(_ rt: Runtime) {
        super.init(rt)
    }
    
    public override class var staticType: Types {
        .unspecified
    }
    
    public override var truthy: Bool {
        false
    }
    
    public override var description: String {
        "unspecified"
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
