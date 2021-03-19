import Bushel

public class ParameterInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The parameter's user-facing name.
        case name(Term.Name)
        
    }
    
    public var uri: Term.SemanticURI
    public var tags: Set<Tag> = []
    
    public var role: Term.SyntacticRole {
        .parameter
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
    
    public static func == (lhs: ParameterInfo, rhs: ParameterInfo) -> Bool {
        return lhs.uri == rhs.uri
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
    public convenience init(_ predefined: Parameters, _ tags: Set<Tag> = []) {
        self.init(Term.SemanticURI(predefined), tags)
    }
    
    public init(_ uid: Term.SemanticURI, _ tags: Set<Tag> = []) {
        // Normalize all "direct" and "target" parameters into one value
        // for the sake of runtime comparisons
        if uid.isDirectParameter {
            self.uri = Term.SemanticURI(Parameters.direct)
        } else if uid.isTargetParameter {
            self.uri = Term.SemanticURI(Parameters.target)
        } else {
            self.uri = uid
        }
        self.tags = tags
    }
    
}

extension ParameterInfo.Tag: Hashable {
    
    public static func == (lhs: ParameterInfo.Tag, rhs: ParameterInfo.Tag) -> Bool {
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
