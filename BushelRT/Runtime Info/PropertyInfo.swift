import Bushel

public class PropertyInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The property's user-facing name.
        case name(Term.Name)
        
    }
    
    public var uri: Term.SemanticURI
    public var tags: Set<Tag> = []
    
    public var role: Term.SyntacticRole {
        .property
    }
    
    public var name: Term.Name? {
        for case .name(let name) in tags {
            return name
        }
        return nil
    }
    
    public func addName(_ name: Term.Name) {
        if self.name == nil {
            tags.insert(.name(name))
        }
    }
    
    public static func == (lhs: PropertyInfo, rhs: PropertyInfo) -> Bool {
        return lhs.uri == rhs.uri
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
    public convenience init(_ predefined: Properties, _ tags: Set<Tag> = []) {
        self.init(Term.SemanticURI(predefined), tags)
    }
    
    public init(_ uid: Term.SemanticURI, _ tags: Set<Tag> = []) {
        self.uri = uid
        self.tags = tags
    }
    
}

extension PropertyInfo.Tag: Hashable {
    
    public static func == (lhs: PropertyInfo.Tag, rhs: PropertyInfo.Tag) -> Bool {
        switch (lhs, rhs) {
        case (.name(let lName), .name(let rName)):
            return lName == rName
        }
    }
    
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .name(let name):
            hasher.combine(1)
            hasher.combine(name)
        }
    }
    
}
