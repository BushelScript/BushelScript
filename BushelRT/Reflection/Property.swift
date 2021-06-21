import Bushel

extension Reflection {

    public final class Property: TermReflection, Hashable {
        
        public var role: Term.SyntacticRole {
            .property
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?) {
            self.uri = uri
            self.name = name
        }
        
    }
    
}
