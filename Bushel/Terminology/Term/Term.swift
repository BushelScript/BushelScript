import Foundation

public class Term: Hashable {
    
    public let id: ID
    public let name: Name?
    
    public var role: SyntacticRole {
        id.role
    }
    public var uri: SemanticURI {
        id.uri
    }
    
    public var dictionary: TermDictionary?
    public let exports: Bool
    
    public var parameters: ParameterTermDictionary?
    
    public var resource: Resource?
    
    public init(_ id: ID, name: Name? = nil, dictionary: TermDictionary? = nil, exports: Bool = true, parameters: ParameterTermDictionary? = nil, resource: Resource? = nil) {
        self.id = id
        self.name = name
        self.dictionary = dictionary
        self.exports = exports
        self.parameters = parameters
        self.resource = resource
    }
    
    public convenience init(_ role: SyntacticRole, _ uri: SemanticURI, name: Name? = nil, dictionary: TermDictionary? = nil, exports: Bool = true, parameters: ParameterTermDictionary? = nil, resource: Resource? = nil) {
        self.init(ID(role, uri), name: name, dictionary: dictionary, exports: exports, parameters: parameters, resource: resource)
    }
    
    public static func == (lhs: Term, rhs: Term) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
    }
    
    public var description: String {
        if
            let name = name,
            !name.words.isEmpty
        {
            return "\(name)"
        } else {
            return "«\(role) \(uri)»"
        }
    }
    
}
