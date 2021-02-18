import Bushel

public class ConstantInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The constant's user-facing name.
        case name(Term.Name)
        
    }
    
    public var uri: Term.SemanticURI
    public var tags: Set<Tag> = []
    
    public var role: Term.SyntacticRole {
        .constant
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
    
    public static func == (lhs: ConstantInfo, rhs: ConstantInfo) -> Bool {
        return lhs.uri == rhs.uri
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uri)
    }
    
    public convenience init(_ predefined: Constants, _ tags: Set<Tag> = []) {
        self.init(Term.SemanticURI(predefined), tags)
    }
    
    public init(_ uid: Term.SemanticURI, _ tags: Set<Tag> = []) {
        self.uri = uid
        self.tags = tags
    }
    
    public convenience init(property: PropertyInfo) {
        self.init(property.uri, Set(property.tags.map { propertyTag in
            switch propertyTag {
            case .name(let name):
                return .name(name)
            }
        }))
    }
    
    public convenience init(type: TypeInfo) {
        self.init(type.uri, Set(type.tags.compactMap { typeTag in
            switch typeTag {
            case .name(let name):
                return .name(name)
            case .root, .supertype, .dynamic:
                return nil
            }
        }))
    }
    
}

extension ConstantInfo.Tag: Hashable {
    
    public static func == (lhs: ConstantInfo.Tag, rhs: ConstantInfo.Tag) -> Bool {
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
