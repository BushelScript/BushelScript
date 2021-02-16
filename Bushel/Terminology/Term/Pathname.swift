import Foundation

// MARK: Definition
extension Term.SemanticURI {
    
    public struct Pathname {
        public static let separator: Character = "/"
        
        public var components: [String]
        
        public init(_ components: [String]) {
            self.components = components
        }
    }
    
}

// MARK: Pathnames as strings
extension Term.SemanticURI.Pathname: RawRepresentable, Hashable {
    
    public typealias RawValue = String

    public init(rawValue: String) {
        self.init(rawValue.split(separator: Term.SemanticURI.Pathname.separator).map(String.init))
    }

    public var rawValue: String {
        components.joined(separator: String(Term.SemanticURI.Pathname.separator))
    }
    
}
