import Foundation

// MARK: Definition
extension Term {
    
    /// Uniquely identifying combination of syntactic role and semantic URI.
    /// See [Terms](https://bushelscript.github.io/help/docs/ref/terms).
    public struct ID: Hashable {
        /// The term's syntactic role.
        public var role: SyntacticRole
        /// The term's semantic URI.
        public var uri: SemanticURI
        
        /// Initializes from syntactic role and semantic URI components.
        public init(_ role: SyntacticRole, _ uri: SemanticURI) {
            self.role = role
            self.uri = uri
        }
    }
    
}

// MARK: ID → URI name accessors
extension Term.ID {
    
    /// If the semantic URI's scheme uses a 4-byte code, the 4-byte code.
    /// Otherwise, if the semantic URI identifies a direct parameter,
    /// the 4-byte code with MacOSRoman representation `----`.
    /// Otherwise, nil.
    public var ae4Code: OSType? {
        uri.ae4Code
    }
    
    /// If the semantic URI's scheme uses two 4-byte codes, the two 4-byte
    /// codes.
    /// Otherwise, nil.
    public var ae8Code: (class: AEEventClass, id: AEEventID)? {
        uri.ae8Code
    }
    
    /// If the semantic URI's scheme uses three 4-byte codes, the three 4-byte
    /// codes.
    /// Otherwise, nil.
    public var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        uri.ae12Code
    }
    
}

// MARK: IDs as strings
extension Term.ID: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    public var normalized: String {
        "\(role) \(uri)"
    }
    
    public init?<S: StringProtocol>(normalized: S) where S.SubSequence == Substring {
        let components = normalized.split(separator: " ", maxSplits: 1)
        guard components.count == 2 else {
            return nil
        }
        self.init(role: components[0], uri: components[1])
    }
    
    public init?<S: StringProtocol>(role: S, uri: S) where S.SubSequence == Substring {
        guard
            let role = Term.SyntacticRole(rawValue: String(role)),
            let uri = Term.SemanticURI(normalized: String(uri))
        else {
            return nil
        }
        self.init(role, uri)
    }
    
}

// MARK: Comparison
extension Term.ID: Comparable {
    
    public static func < (lhs: Term.ID, rhs: Term.ID) -> Bool {
        lhs.normalized < rhs.normalized
    }
    
}
