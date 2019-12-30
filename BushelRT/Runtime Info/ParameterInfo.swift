import Bushel

public class ParameterInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The parameter's user-facing name.
        case name(TermName)
        
    }
    
    public var uid: TermUID
    public var tags: Set<Tag> = []
    
    public var kind: TypedTermUID.Kind {
        .parameter
    }
    
    public var name: TermName? {
        for case .name(let name) in tags {
            return name
        }
        return nil
    }
    
    public static func == (lhs: ParameterInfo, rhs: ParameterInfo) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    public convenience init(_ predefined: ParameterUID, _ tags: Set<Tag> = []) {
        self.init(TermUID(predefined), tags)
    }
    
    public init(_ uid: TermUID, _ tags: Set<Tag> = []) {
        self.uid = uid
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
