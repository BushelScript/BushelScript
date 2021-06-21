import Bushel

extension Reflection {

    public final class Constant: TermReflection, Hashable {
        
        public var role: Term.SyntacticRole {
            .constant
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?) {
            self.uri = uri
            self.name = name
        }
        
        public convenience init(property: Reflection.Property) {
            self.init(property.uri, name: property.name)
        }
        
        public convenience init(type: Reflection.`Type`) {
            self.init(type.uri, name: type.name)
        }
        
    }
    
}
