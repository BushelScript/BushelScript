import Bushel

public class ParameterInfo: Hashable {
    
    public struct ID: Hashable {
        
        public var uid: String
        public var aeCode: OSType?
        
        public init(_ uid: String, _ aeCode: OSType? = nil) {
            self.uid = uid
            self.aeCode = aeCode
        }
        
        public static func == (lhs: ID, rhs: ID) -> Bool {
            return lhs.uid == rhs.uid || (lhs.aeCode != nil && lhs.aeCode == rhs.aeCode)
        }
        
        public func hash(into hasher: inout Hasher) {
            hasher.combine(uid)
            hasher.combine(aeCode)
        }
        
    }
    
    public enum Tag {
        
        /// The parameter's user-facing name.
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
    public var code: OSType? {
        id.aeCode
    }
    
    public static func == (lhs: ParameterInfo, rhs: ParameterInfo) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public convenience init(_ predefined: ParameterUID, _ tags: Set<Tag> = []) {
        self.init(predefined.rawValue, predefined.aeCode, tags)
    }
    
    public convenience init(_ uid: String, _ tags: Set<Tag>) {
        self.init(id: ID(uid), tags)
    }
    
    public convenience init(_ uid: String, _ aeCode: OSType?, _ tags: Set<Tag>) {
        self.init(id: ID(uid, aeCode), tags)
    }
    
    public init(id: ID, _ tags: Set<Tag>) {
        self.id = id
        self.tags = tags
    }
    
}

public extension ParameterInfo {
    
    var displayName: String {
        if let name = name {
            return name.normalized
        } else if let code = code {
            return "«parameter \(String(fourCharCode: code))»"
        } else {
            return "«parameter»"
        }
    }
    
}

extension ParameterInfo: CustomDebugStringConvertible {
    
    public var debugDescription: String {
        "[ParameterInfo: \(uid)\(code.map { " / '\(String(fourCharCode: $0))'" } ?? "")\(name.map { " / ”\($0)“" } ?? "")]"
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
