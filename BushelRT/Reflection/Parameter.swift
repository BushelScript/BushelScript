import Bushel

extension Reflection {

    public final class Parameter: TermReflection, Hashable {
        
        public var role: Term.SyntacticRole {
            .parameter
        }
        
        public var uri: Term.SemanticURI
        public var name: Term.Name?
        
        public init(_ uri: Term.SemanticURI, name: Term.Name?) {
            // Normalize all "direct" and "target" parameters into one value
            // for the sake of runtime comparisons
            if uri.isDirectParameter {
                self.uri = Term.SemanticURI(Parameters.direct)
            } else if uri.isTargetParameter {
                self.uri = Term.SemanticURI(Parameters.target)
            } else {
                self.uri = uri
            }
            self.name = name
        }
        
        public convenience init(_ predefined: Parameters) {
            self.init(Term.SemanticURI(predefined), name: nil)
        }
        
    }
    
}
