import Foundation

// MARK: Definition
extension Term {
    
    /// URI identifying a term's semantics.
    /// The case is the scheme, and the associated value is the name.
    /// See [Terms](https://bushelscript.github.io/help/docs/ref/terms).
    public enum SemanticURI: Hashable {
        /// Identifies AE constants with a 4-byte code.
        case ae4(code: OSType)
        /// Identifies AE commands with two 4-byte codes.
        case ae8(class: AEEventClass, id: AEEventID)
        /// Identifies AE parameters, with two 4-byte codes for a command
        /// and one for a parameter for that command.
        case ae12(class: AEEventClass, id: AEEventID, code: AEKeyword)
        /// Identifies a locally defined term with a pathname.
        case id(_ name: Pathname)
        /// Identifies an imported resource with a resource name.
        case res(_ name: String)
        /// Identifies an AppleScript user identifier (i.e., variable name).
        case asid(_ name: String)
    }
    
}

// MARK: URI name accessors
extension Term.SemanticURI {
    
    /// If the scheme uses a 4-byte code, the 4-byte code.
    /// Otherwise, if the URI identifies a direct parameter, the 4-byte code
    /// with MacOSRoman representation `----`.
    /// Otherwise, nil.
    public var ae4Code: OSType? {
        switch self {
        case .ae4(let code),
             .ae12(_, _, let code):
            return code
        case .id(_):
            // Special-case direct parameter
            return isDirectParameter ? keyDirectObject : nil
        default:
            return nil
        }
    }
    
    /// If the scheme uses two 4-bytes codes, the two 4-byte codes.
    /// Otherwise, nil.
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        switch self {
        case .ae8(let `class`, let id):
            return (class: `class`, id: id)
        default:
            return nil
        }
    }
    
    /// If the scheme uses three 4-byte codes, the three 4-byte codes.
    /// Otherwise, nil.
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        switch self {
        case .ae12(let `class`, let id, let code):
            return (class: `class`, id: id, code: code)
        default:
            return nil
        }
    }
    
    /// If the scheme uses a pathname, the pathname.
    /// Otherwise, nil.
    public var pathname: Pathname? {
        switch self {
        case .id(_):
            // Special-case target parameter
            return isTargetParameter ? Pathname([Parameters.target.rawValue]) : nil
        default:
            return nil
        }
    }
    
    /// If the scheme uses a resource name, the resource name.
    /// Otherwise, nil.
    public var resName: String? {
        switch self {
        case .res(let name):
            return name
        default:
            return nil
        }
    }
    
    /// If the scheme uses an AppleScript user identifier,
    /// the AppleScript user identifier.
    /// Otherwise, nil.
    public var asidName: String? {
        switch self {
        case .asid(let name):
            return name
        default:
            return nil
        }
    }
    
}

// MARK: URI command derivations
extension Term.SemanticURI {
    
    /// If this URI could identify a parameter, the derived command URI.
    /// Otherwise, `nil`.
    public var commandURI: Term.SemanticURI? {
        switch self {
        case .ae12(let `class`, let id, _):
            return .ae8(class: `class`, id: id)
        case .id(let pathname):
            guard pathname.components.count > 1 else {
                return nil
            }
            return .id(Pathname(pathname.components.dropLast()))
        default:
            return nil
        }
    }
    
    /// Whether this URI could identify a direct parameter.
    public var isDirectParameter: Bool {
        switch self {
        case .ae4(let code),
             .ae12(_, _, let code):
            return code == keyDirectObject
        case .id(let pathname):
            return pathname.components.last == ".direct"
        default:
            return false
        }
    }
    
    /// Whether this URI could identify a target parameter.
    public var isTargetParameter: Bool {
        switch self {
        case .id(let pathname):
            return pathname.components.last == ".target"
        default:
            return false
        }
    }
    
}

// MARK: URIs as strings
extension Term.SemanticURI: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    public static let schemeTerminator: Character = ":"
    
    /// Normalized string representation of the URI.
    /// The structure can be reconstructed from the returned string using
    /// `init?(normalized:)`.
    public var normalized: String {
        "\(scheme)\(Term.SemanticURI.schemeTerminator)\(name)"
    }
    
    /// String representation of the scheme of the URI.
    public var scheme: String {
        switch self {
        case .ae4:
            return "ae4"
        case .ae8:
            return "ae8"
        case .ae12:
            return "ae12"
        case .id:
            return "id"
        case .res:
            return "res"
        case .asid:
            return "asid"
        }
    }
    
    /// String representation of the URI's name in its scheme's namespace.
    public var name: String {
        switch self {
        case .ae4(let code):
            return String(fourCharCode: code)
        case .ae8(let `class`, let id):
            return String(fourCharCode: `class`) + String(fourCharCode: id)
        case .ae12(let `class`, let id, let code):
            return String(fourCharCode: `class`) + String(fourCharCode: id) + String(fourCharCode: code)
        case .id(let pathname):
            return pathname.rawValue
        case .res(let name):
            return name
        case .asid(let name):
            return name
        }
    }
    
    /// Constructs a semantic URI structure from its normalized string
    /// representation.
    ///
    /// Valid inputs take the form `"scheme:name"`, where `scheme` identifies
    /// a namespace and `name` is a name in that namespace.
    /// The set of allowable values for `name` is determined by the `scheme`.
    /// e.g., for `scheme` `"ae4"`, `name` must be a valid four-byte AE code.
    public init?(normalized: String) {
        let components = normalized.split(separator: Term.SemanticURI.schemeTerminator, maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }
        self.init(scheme: String(components[0]), name: String(components[1]))
    }
    
    public init?(scheme: String, name: String) {
        switch scheme {
        case "ae4":
            guard let code = try? OSType(fourByteString: name) else {
                return nil
            }
            self = .ae4(code: code)
        case "ae8":
            guard
                name.count == 8,
                let `class` = try? OSType(fourByteString: String(name[..<name.index(name.startIndex, offsetBy: 4)])),
                let id = try? OSType(fourByteString: String(name[name.index(name.startIndex, offsetBy: 4)...]))
            else {
                return nil
            }
            self = .ae8(class: `class`, id: id)
        case "ae12":
            guard
                name.count == 12,
                let `class` = try? OSType(fourByteString: String(name[..<name.index(name.startIndex, offsetBy: 4)])),
                let id = try? OSType(fourByteString: String(name[name.index(name.startIndex, offsetBy: 4)..<name.index(name.startIndex, offsetBy: 8)])),
                let code = try? OSType(fourByteString: String(name[name.index(name.startIndex, offsetBy: 8)...]))
            else {
                return nil
            }
            self = .ae12(class: `class`, id: id, code: code)
        case "id":
            self = .id(Pathname(rawValue: name))
        case "res":
            self = .res(name)
        case "asid":
            self = .asid(name)
        default:
            return nil
        }
    }
    
}
