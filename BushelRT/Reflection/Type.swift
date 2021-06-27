import Bushel
import AEthereal

extension Reflection {

    public final class `Type`: TermReflection, Codable, AETyped {
        
        public var role: Term.SyntacticRole {
            .type
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public var supertype: Type?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?, supertype: Type?) {
            self.uri = uri
            self.name = name
            self.supertype = supertype
        }
        
        public convenience init(_ uri: Term.SemanticURI, name: Term.Name?) {
            self.init(uri, name: name, supertype: nil)
        }
        
        public convenience init(type: Reflection.`Type`) {
            self.init(type.uri, name: type.name, supertype: type.supertype)
        }
        
        public convenience init(property: Reflection.Property) {
            self.init(property.uri, name: property.name)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(uri)
        }
        
        public convenience init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let uri = try container.decode(Term.SemanticURI.self)
            let rt = decoder.userInfo[.rt] as! Runtime
            self.init(type: rt.reflection.types[uri])
        }
        
        public var aeType: AE4.AEType {
            .type
        }
        
    }
    
}

extension Reflection.`Type` {
    
    func isA(_ other: Reflection.`Type`) -> Bool {
        self == other || supertype?.isA(other) ?? (other.uri == Term.SemanticURI(Types.item))
    }
    
}
