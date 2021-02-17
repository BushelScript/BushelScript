import Bushel

public class CommandInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The command's user-facing name.
        case name(Term.Name)
        
    }
    
    public var uid: Term.SemanticURI
    public var tags: Set<Tag> = []
    
    public var kind: Term.SyntacticRole {
        .command
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
    
    public static func == (lhs: CommandInfo, rhs: CommandInfo) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    public convenience init(_ predefined: Commands, _ tags: Set<Tag> = []) {
        self.init(Term.SemanticURI(predefined), tags)
    }
    
    public init(_ uid: Term.SemanticURI, _ tags: Set<Tag> = []) {
        self.uid = uid
        self.tags = tags
    }
    
}

extension CommandInfo.Tag: Hashable {
    
    public static func == (lhs: CommandInfo.Tag, rhs: CommandInfo.Tag) -> Bool {
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
