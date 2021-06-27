import Bushel
import AEthereal

extension Reflection {

    public final class Constant: TermReflection, Codable, AETyped {
        
        public var role: Term.SyntacticRole {
            .constant
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?) {
            self.uri = uri
            self.name = name
        }
        
        public convenience init(constant: Reflection.Constant) {
            self.init(constant.uri, name: constant.name)
        }
        
        public convenience init(property: Reflection.Property) {
            self.init(property.uri, name: property.name)
        }
        
        public convenience init(type: Reflection.`Type`) {
            self.init(type.uri, name: type.name)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(uri)
        }
        
        public convenience init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let uri = try container.decode(Term.SemanticURI.self)
            let rt = decoder.userInfo[.rt] as! Runtime
            self.init(constant: rt.reflection.constants[uri])
        }
        
        public var aeType: AE4.AEType {
            .enumerated
        }
        
    }
    
}
