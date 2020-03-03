import Foundation

public protocol LocatedTerm: NamedTerm, PrettyPrintable {
    
    var wrappedTerm: Term { get }
    var location: SourceLocation { get }
    
}

// Dear Swift team,
//
// PLEASE ADD GENERIC COVARIANCE TO SWIFT.
//
// Thank you,
// - Ian
public struct Located<Term: Bushel.Term>: LocatedTerm, Hashable {
    
    public let term: Term
    public let location: SourceLocation
    
    public init(_ term: Term, at location: SourceLocation) {
        self.term = term
        self.location = location
    }
    
    public var uid: TermUID {
        term.uid
    }
    
    public var name: TermName? {
        term.name
    }
    
    public var description: String {
        term.description
    }
    
    public var wrappedTerm: Bushel.Term {
        term
    }
    
}
