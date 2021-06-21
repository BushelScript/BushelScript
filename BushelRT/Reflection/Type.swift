import Bushel

extension Reflection {

    public final class `Type`: TermReflection, Hashable {
        
        public var role: Term.SyntacticRole {
            .type
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public var supertype: Type?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?) {
            self.uri = uri
            self.name = name
        }
        
        public convenience init(property: Reflection.Property) {
            self.init(property.uri, name: property.name)
        }
        
    }
    
}

extension Reflection.`Type` {
    
    func isA(_ other: Reflection.`Type`) -> Bool {
        self == other || supertype?.isA(other) ?? (other.uri == Term.SemanticURI(Types.item))
    }
    
}
