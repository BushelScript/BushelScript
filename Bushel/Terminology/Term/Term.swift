import Foundation

public class Term: Hashable, CustomStringConvertible, CustomDebugStringConvertible {
    
    public let id: ID
    public let name: Name?
    
    public var role: SyntacticRole {
        id.role
    }
    public var uri: SemanticURI {
        id.uri
    }
    
    public var dictionary: TermDictionary
    public let exports: Bool
    
    public var resource: Resource?
    
    public init(_ id: ID, name: Name? = nil, dictionary: TermDictionary = TermDictionary(), exports: Bool = true, resource: Resource? = nil) {
        self.id = id
        self.name = name
        self.dictionary = dictionary
        // Commands should _never_ export (parameter terms are meaningless on their own).
        self.exports = (id.role == .command) ? false : exports
        self.resource = resource
    }
    
    public convenience init(_ role: SyntacticRole, _ uri: SemanticURI, name: Name? = nil, dictionary: TermDictionary = TermDictionary(), exports: Bool = true, resource: Resource? = nil) {
        self.init(ID(role, uri), name: name, dictionary: dictionary, exports: exports, resource: resource)
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
            return "#\(role) [\(uri)]"
        }
    }
    
    public var debugDescription: String {
        "\(name.map { "name: \($0)" } ?? "no name"), role/uri: \(id), exports: \(exports), \(resource.map { "resource: \($0)" } ?? "no resource"), dictionary: \(dictionary.contents.count) element(s)"
    }
    public var debugDescriptionLong: String {
        "\(name.map { "name: \($0)" } ?? "no name"), role/uri: \(id), exports: \(exports), \(resource.map { "resource: \($0)" } ?? "no resource"), dictionary: \(dictionary)"
    }
    
}

// MARK: Comparison
extension Term: Comparable {
    
    public static func < (lhs: Term, rhs: Term) -> Bool {
        lhs.id < rhs.id
    }
    
}

public protocol TermSemanticURIProvider {
    
    var uri: Term.SemanticURI  { get }
    
}

extension Term: TermSemanticURIProvider {}
extension Term.SemanticURI: TermSemanticURIProvider {
    
    public var uri: Term.SemanticURI {
        self
    }
    
}
