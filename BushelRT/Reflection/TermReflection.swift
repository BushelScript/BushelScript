import Bushel

public protocol TermReflection: Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    
    init(_ uri: Term.SemanticURI, name: Term.Name?)
    
    var role: Term.SyntacticRole { get }
    var uri: Term.SemanticURI { get }
    var name: Term.Name? { get set }
    
}

extension TermReflection {
    
    public var id: Term.ID {
        Term.ID(role, uri)
    }
    
    public init(_ term: Term) {
        self.init(term.uri, name: term.name)
    }
    
    public init(_ uri: Term.SemanticURI) {
        self.init(uri, name: nil)
    }
    
    
}

// MARK: Custom(Debug)StringConvertible
extension TermReflection {
    
    public var description: String {
        if let name = name {
            return "\(name)"
        } else {
            return "#\(id.role) [\(uri)]"
        }
    }
    
    public var debugDescription: String {
        "[\(type(of: self)) \(id)\(name.map { " / ”\($0)“" } ?? "")]"
    }
    
}

// MARK: Hashable
extension TermReflection {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.uri == rhs.uri
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
}
