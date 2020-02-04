import Bushel

public class ConstantInfo: TermInfo, Hashable {
    
    public enum Tag {
        
        /// The constant's user-facing name.
        case name(TermName)
        
    }
    
    public var uid: TermUID
    public var tags: Set<Tag> = []
    
    public var kind: TypedTermUID.Kind {
        .constant
    }
    
    public var name: TermName? {
        for case .name(let name) in tags {
            return name
        }
        return nil
    }
    
    public static func == (lhs: ConstantInfo, rhs: ConstantInfo) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    public convenience init(_ predefined: ConstantUID, _ tags: Set<Tag> = []) {
        self.init(TermUID(predefined), tags)
    }
    
    public init(_ uid: TermUID, _ tags: Set<Tag> = []) {
        self.uid = uid
        self.tags = tags
    }
    
    public convenience init(property: PropertyInfo) {
        self.init(property.uid, Set(property.tags.map { propertyTag in
            switch propertyTag {
            case .name(let name):
                return .name(name)
            }
        }))
    }
    
    public convenience init(type: TypeInfo) {
        self.init(type.uid, Set(type.tags.compactMap { typeTag in
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