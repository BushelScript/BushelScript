import Bushel

extension Reflection {

    public final class Command: TermReflection, Hashable {
        
        public var role: Term.SyntacticRole {
            .command
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        /// The command's parameters.
        public var parameters = ReflectedTerms<Reflection.Parameter, Parameters>()
        
        public init(_ uid: Term.SemanticURI, name: Term.Name?) {
            self.uri = uid
            self.name = name
        }
        
    }
    
}
