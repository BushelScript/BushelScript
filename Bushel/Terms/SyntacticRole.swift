import Foundation

// MARK: Definition
extension Term {
    
    /// Syntactic role of a term.
    /// See [Terms](https://bushelscript.github.io/help/docs/ref/terms).
    public enum SyntacticRole: String, CaseIterable, Hashable {
        /// Type term.
        case type
        /// Property term.
        case property
        /// Constant term.
        case constant
        /// Command term.
        case command
        /// Parameter term.
        case parameter
        /// Variable term.
        case variable
        /// Resource term.
        case resource
    }
    
}

// MARK: Syntactic roles as strings
extension Term.SyntacticRole: CustomStringConvertible {
    
    public var description: String {
        rawValue
    }
    
}
