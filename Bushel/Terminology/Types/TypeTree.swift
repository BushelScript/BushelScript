
public final class TypeTree {
    
    public var rootType: Term.SemanticURI
    
    public init(rootType: Term.SemanticURI) {
        self.rootType = rootType
    }
    
    public func supertype(of type: Term.SemanticURI) -> Term.SemanticURI {
        typeToSupertype[type] ?? rootType
    }
    private var typeToSupertype: [Term.SemanticURI : Term.SemanticURI] = [:]
    
    public func subtypes(of type: Term.SemanticURI) -> Set<Term.SemanticURI> {
        (type == rootType) ? Set(typeToSubtypes.keys) : (typeToSubtypes[type] ?? [])
    }
    private var typeToSubtypes: [Term.SemanticURI : Set<Term.SemanticURI>] = [:]
    
    public func add(_ type: Term.SemanticURI, supertype: Term.SemanticURI) {
        typeToSupertype[type] = supertype
        
        var supertype = supertype
        while supertype != rootType {
            var subtypes = typeToSubtypes[supertype] ?? []
            subtypes.insert(type)
            typeToSubtypes[supertype] = subtypes
            
            let newSupertype = self.supertype(of: supertype)
            if newSupertype == supertype {
                break
            }
            supertype = newSupertype
        }
        
    }
    
}
