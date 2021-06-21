import Bushel

public struct Reflection {
    
    public var typeTree: TypeTree? = nil
    
    public mutating func inject(from rootTerm: Term) {
        addAll(from: rootTerm)
        updateSupertypes()
    }
    
    private mutating func addAll(from rootTerm: Term) {
        for term in rootTerm.dictionary.contents {
            switch term.role {
            case .dictionary:
                break
            case .type:
                let type = types.add(term)
                typesWithoutSupertype.insert(type)
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
            addAll(from: term)
        }
    }
    
    /// Update supertype info for orphaned types according to the current state
    /// of the TypeTree.
    private mutating func updateSupertypes() {
        guard let typeTree = typeTree else {
            return
        }
        var newTypesWithoutSupertype = typesWithoutSupertype
        for type in typesWithoutSupertype {
            let supertype = typeTree.supertype(of: type.uri)
            if supertype != typeTree.rootType {
                type.supertype = types[supertype]
                newTypesWithoutSupertype.remove(type)
            }
        }
        typesWithoutSupertype = newTypesWithoutSupertype
    }
    
    private var terms: Set<Term> = []
    
    public var types = ReflectedTerms<`Type`, Types>()
    private var typesWithoutSupertype: Set<`Type`> = []
    
    public var properties = ReflectedTerms<Property, Properties>()
    
    public var constants = ReflectedTerms<Constant, Constants>()
    
    public var commands = ReflectedTerms<Command, Commands>()
    
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
