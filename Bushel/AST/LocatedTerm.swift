import Foundation

public protocol LocatedTerm: NamedTerm {
    
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
    
    public var name: TermName? {
        term.name
    }
    
    public var displayName: String {
        term.displayName
    }
    
    public var wrappedTerm: Bushel.Term {
        term
    }
    
}
