import Foundation
import Regex

/// The compiler-internal name of a term.
public indirect enum TermUID {
    
    case ae4(code: OSType)
    case ae8(class: AEEventClass, id: AEEventID)
    case ae12(class: AEEventClass, id: AEEventID, code: AEKeyword)
    case id(_ name: String)
    case variant(Variant, TermUID)
    
    public enum Variant {
        case plural
    }
    
}

public struct TypedTermUID {
    
    public enum Kind: String, CaseIterable {
        case dictionary
        case type
        case property
        case constant
        case command
        case parameter
        case variable
        case resource
    }
    
    public var kind: Kind
    public var uid: TermUID
    
    /// Initializes from component `Kind` and `TermUID` parts.
    public init(_ kind: Kind, _ uid: TermUID) {
        self.kind = kind
        self.uid = uid
        
        if case let .id(name) = uid {
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
        self.init(kind: components[0], uid: components[1])
    }
    
    public init?<S: StringProtocol>(kind: S, uid: S) where S.SubSequence == Substring {
        guard
            let kind = Kind(rawValue: String(kind)),
            let uid = TermUID(normalized: String(uid))
        else {
            return nil
        }
        self.init(kind, uid)
    }
    
}

extension TypedTermUID.Kind: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
    
}

extension TermUID {
    
    public var ae4Code: OSType? {
        switch self {
        case .ae4(let code),
             .ae12(_, _, let code):
            return code
        case .id(_):
            // Special-case direct parameter
            return isDirectParameter ? keyDirectObject : nil
        case .variant(_, let uid):
            return uid.ae4Code
        default:
            return nil
        }
    }
    
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        switch self {
        case .ae8(let codes):
            return codes
        case .variant(_, let uid):
            return uid.ae8Code
        default:
            return nil
        }
    }
    
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        switch self {
        case .ae12(let codes):
            return codes
        case .variant(_, let uid):
            return uid.ae12Code
        default:
            return nil
        }
    }
    
    public var idName: String? {
        switch self {
        case .id(let name):
            return name
        case .variant(_, let uid):
            return uid.idName
        default:
            return nil
        }
    }
    
    public var idNameScopes: [String]? {
        idName.map { scopes(from: $0) }
    }
    
    private func scopes(from idName: String) -> [String] {
        idName.split(separator: ":").map { String($0) }
    }
    
}

extension TermUID {
    
    /// The UID for the corresponding command if this UID were to refer to
    /// a parameter. `nil` if unavailable.
    public var commandUIDFromParameterUID: TermUID? {
        switch self {
        case .ae12(let `class`, let id, _):
            return .ae8(class: `class`, id: id)
        case .id(let name):
            let scopes = self.scopes(from: name)
            guard scopes.count > 1 else {
                return nil
            }
            return .id(scopes.dropLast().joined(separator: ":"))
        default:
            return nil
        }
    }
    
    public var isDirectParameter: Bool {
        switch self {
        case .ae4(let code),
             .ae12(_, _, let code):
            return code == keyDirectObject
        case .id(let name):
            return scopes(from: name).last == "/direct"
        default:
            return false
        }
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
    
    /// The kind of UID name; the domain or "namespace".
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
        case .variant(let variant, _):
            return "var(\(variant))"
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
        case .variant(_, let uid):
            return uid.normalized
        }
    }
    
}

extension TermUID.Variant: CustomStringConvertible {
    
    public var description: String {
        kind
    }
    
    public var kind: String {
        switch self {
        case .plural:
            return "plural"
        }
    }
    
}

extension TermUID {
    
    /// Reconstructs a `TermUID` structure from its normalized string
    /// representation.
    ///
    /// Valid inputs take the form `"domain:data"`, where `domain` identifies
    /// one of a set of predefined domain "namespaces", while `data` creates a
    /// unique name within said namespace.
    /// The set of allowable values for `data` is determined by the `domain`.
    /// e.g., for `domain` `"ae4"`, `data` must be a valid four-byte AE code.
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
        case Regex("var\\((\\w+)\\)"):
            let variantKind = Regex.lastMatch!.captures[0]!
            guard
                let variant = Variant(kind: variantKind),
                let uid = TermUID(normalized: data)
            else {
                return nil
            }
            self = .variant(variant, uid)
        default:
            return nil
        }
    }
    
}

extension TermUID.Variant {
    
    public init?(kind: String) {
        switch kind {
        case "plural":
            self = .plural
        default:
            return nil
        }
    }
    
}
