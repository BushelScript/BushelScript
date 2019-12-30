import Foundation

/// The compiler-internal name of a term.
public enum TermUID {
    case ae4(code: OSType)
    case ae8(class: AEEventClass, id: AEEventID)
    case ae12(class: AEEventClass, id: AEEventID, code: AEKeyword)
    case id(_ name: String)
}

public struct TypedTermUID {
    
    public enum Kind: String {
        case enumerator
        case dictionary
        case type
        case property
        case command
        case parameter
        case variable
        case applicationName
        case applicationID
    }
    
    public var kind: Kind
    public var uid: TermUID
    
    /// Initializes from component `Kind` and `TermUID` parts.
    public init(_ kind: Kind, _ name: TermUID) {
        self.kind = kind
        self.uid = name
        
        if case let .id(name) = name {
            assert(!name.isEmpty, "Empty identifier string for TermUID.id!")
        }
    }
    
    public var ae4Code: OSType? {
        uid.ae4Code
    }
    
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        uid.ae8Code
    }
    
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        uid.ae12Code
    }
    
}

extension TypedTermUID: Hashable {
}

extension TypedTermUID: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    public var normalized: String {
        "\(kind)/\(uid)"
    }
    
    public init?<S: StringProtocol>(normalized: S) where S.SubSequence == Substring {
        let components = normalized.split(separator: "/", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }
        self.init(kind: components[0], name: components[1])
    }
    
    public init?<S: StringProtocol>(kind: S, name: S) where S.SubSequence == Substring {
        guard
            let kind = Kind(rawValue: String(kind)),
            let name = TermUID(normalized: String(name))
        else {
            return nil
        }
        self.kind = kind
        self.uid = name
    }
    
}

extension TypedTermUID.Kind: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
    
}

extension TermUID {
    
    public var ae4Code: OSType? {
        if case let .ae4(code) = self {
            return code
        } else if case let .ae12(_, _, code) = self {
            return code
        }
        return nil
    }
    
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        if case let .ae8(codes) = self {
            return codes
        }
        return nil
    }
    
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        if case let .ae12(codes) = self {
            return codes
        }
        return nil
    }
    
}

extension TermUID: Hashable {
}

extension TermUID: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    /// The normalized string representation of the UID name.
    /// An semantically identical `Name` structure can be reconstructed
    /// from the returned String, using `init?(normalized:)`.
    public var normalized: String {
        kind + ":" + data
    }
    
    /// The kind of UID name; the "addressing method"; the "namespace".
    ///
    /// e.g., in `ae4:bool`, `ae4` specifies that the name data, `bool`, is a
    /// four-byte AE code.
    public var kind: String {
        switch self {
        case .ae4:
            return "ae4"
        case .ae8:
            return "ae8"
        case .ae12:
            return "ae12"
        case .id:
            return "id"
        }
    }
    
    /// The piece of data that distinguishes the UID name within its `kind`.
    public var data: String {
        switch self {
        case .ae4(let code):
            return String(fourCharCode: code)
        case .ae8(let `class`, let id):
            return String(fourCharCode: `class`) + String(fourCharCode: id)
        case .ae12(let `class`, let id, let code):
            return String(fourCharCode: `class`) + String(fourCharCode: id) + String(fourCharCode: code)
        case .id(let name):
            return name
        }
    }
    
}

extension TermUID {
    
    /// Reconstructs a `TermUID` structure from its normalized string
    /// representation.
    ///
    /// Valid inputs take the form `"kind:data"`, where `kind` identifies one of
    /// a set of predefined "namespaces", while `data` creates a unique name
    /// within said namespace.
    /// The set of allowable values for `data` is determined by the `kind`.
    /// e.g., for `kind` `"ae4"`, `data` must be a valid four-byte AE code.
    public init?(normalized: String) {
        let components = normalized.split(separator: ":", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }
        self.init(kind: String(components[0]), data: String(components[1]))
    }
    
    public init?(kind: String, data: String) {
        switch kind {
        case "ae4":
            guard let code = try? OSType(fourByteString: data) else {
                return nil
            }
            self = .ae4(code: code)
        case "ae8":
            guard
                data.count == 8,
                let `class` = try? OSType(fourByteString: String(data[..<data.index(data.startIndex, offsetBy: 4)])),
                let id = try? OSType(fourByteString: String(data[data.index(data.startIndex, offsetBy: 4)...]))
            else {
                return nil
            }
            self = .ae8(class: `class`, id: id)
        case "ae12":
            guard
                data.count == 12,
                let `class` = try? OSType(fourByteString: String(data[..<data.index(data.startIndex, offsetBy: 4)])),
                let id = try? OSType(fourByteString: String(data[data.index(data.startIndex, offsetBy: 4)..<data.index(data.startIndex, offsetBy: 8)])),
                let code = try? OSType(fourByteString: String(data[data.index(data.startIndex, offsetBy: 8)...]))
            else {
                return nil
            }
            self = .ae12(class: `class`, id: id, code: code)
        case "id":
            self = .id(data)
        default:
            return nil
        }
    }
    
}
