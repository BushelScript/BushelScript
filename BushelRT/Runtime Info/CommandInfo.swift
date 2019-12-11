import Bushel

public class CommandInfo: Hashable {
    
    public struct ID: Hashable {
        
        public var uid: String
        public var aeDoubleCode: (class: AEEventClass, id: AEEventID)?
        
        public init(_ uid: String, _ aeDoubleCode: (class: AEEventClass, id: AEEventID)? = nil) {
            self.uid = uid
            self.aeDoubleCode = aeDoubleCode
        }
        
        public static func == (lhs: ID, rhs: ID) -> Bool {
            return lhs.uid == rhs.uid || (lhs.aeDoubleCode != nil && lhs.aeDoubleCode?.class == rhs.aeDoubleCode?.class && lhs.aeDoubleCode?.id == rhs.aeDoubleCode?.id)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(uid)
            hasher.combine(aeDoubleCode?.class)
            hasher.combine(aeDoubleCode?.id)
        }
        
    }
    
    public enum Tag {
        
        /// The command's user-facing name.
        case name(TermName)
        
    }
    
    public var id: ID
    public var tags: Set<Tag> = []
    
    public var name: TermName? {
        for case .name(let name) in tags {
            return name
        }
        return nil
    }
    public var uid: String {
        id.uid
    }
    public var doubleCode: (class: AEEventClass, id: AEEventID)? {
        id.aeDoubleCode
    }
    
    public static func == (lhs: CommandInfo, rhs: CommandInfo) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public convenience init(_ predefined: CommandUID, _ tags: Set<Tag> = []) {
        self.init(predefined.rawValue, predefined.aeDoubleCode, tags)
    }
    
    public convenience init(_ uid: String, _ tags: Set<Tag>) {
        self.init(id: ID(uid), tags)
    }
    
    public convenience init(_ uid: String, _ aeDoubleCode: (class: AEEventClass, id: AEEventID)?, _ tags: Set<Tag>) {
        self.init(id: ID(uid, aeDoubleCode), tags)
    }
    
    public init(id: ID, _ tags: Set<Tag>) {
        self.id = id
        self.tags = tags
    }
    
}

public extension CommandInfo {
    
    var displayName: String {
        if let name = name {
            return name.normalized
        } else if let (classCode, idCode) = doubleCode {
            return "«command \(String(fourCharCode: classCode))\(String(fourCharCode: idCode))»"
        } else {
            return "«command»"
        }
    }
    
}

extension CommandInfo: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "[CommandInfo: \(uid)\(doubleCode.map { " / '\(String(fourCharCode: $0.class))\(String(fourCharCode: $0.id))'" } ?? "")\(name.map { " / ”\($0)“" } ?? "")]"
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
