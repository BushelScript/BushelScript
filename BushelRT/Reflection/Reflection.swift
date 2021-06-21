import Bushel

public struct Reflection {
    
    // MARK: Terminology runtime reflection
    
    public init() {
    }
    
    public mutating func inject(from rootTerm: Term) {
        for term in rootTerm.dictionary.contents {
            switch term.role {
            case .dictionary:
                break
            case .type:
                let type = types.add(term)
                // FIXME: Deal with supertypes
            case .property:
                properties.add(term)
            case .constant:
                constants.add(term)
            case .command:
                commands.add(term)
            case .parameter:
                break
            case .variable:
                break
            case .resource:
                break
            }
            inject(from: term)
        }
    }
    
    private var terms: Set<Term> = []
    
    public var types = ReflectedTerms<Reflection.`Type`, Types>()
    
    private var typesBySupertype: [Reflection.`Type` : [Reflection.`Type`]] = [:]
    public func subtypes(of type: Reflection.`Type`) -> [Reflection.`Type`] {
        typesBySupertype[type] ?? []
    }
    
    public var properties = ReflectedTerms<Reflection.Property, Properties>()
    
    public var constants = ReflectedTerms<Reflection.Constant, Constants>()
    
    public var commands = ReflectedTerms<Reflection.Command, Commands>()
    
    public struct ReflectedTerms<Reflected: TermReflection, Predefined: Term.PredefinedID> {
        
        public init() {
        }
        
        private var byURI: [Term.SemanticURI : Reflected] = [:]
        
        @discardableResult
        public mutating func add(_ term: Term) -> Reflected {
            if let reflected = byURI[term.uri] {
                return reflected
            }
            let reflected = Reflected(term)
            byURI[term.uri] = reflected
            return reflected
        }
        
        public subscript(_ uri: Term.SemanticURI) -> Reflected {
            byURI[uri] ?? Reflected(uri)
        }
        
        public subscript(_ predefined: Predefined) -> Reflected {
            self[Term.SemanticURI(predefined)]
        }
        
    }
    
}
