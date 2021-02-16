import Foundation

/// A collection of all the terms encountered in an entire program.
/// Suitable for error message formatting.
public class TermPool: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var byID: [Term.ID : Term] = [:]
    private(set) public var byName: [Term.Name : Term] = [:]
    
    public init(contents: Set<Term> = []) {
        for term in contents {
            add(term)
        }
    }
    
    public func term(id: Term.ID) -> Term? {
        byID[id]
    }
    
    public func term(named name: Term.Name) -> Term? {
        byName[name]
    }
    
    public func add(_ term: Term) {
        byID[term.id] = term
        if let name = term.name {
            byName[name] = term
        }
    }
    
    public func add(_ terms: [Term]) {
        for term in terms {
            add(term)
        }
    }
    
    public func add(_ pool: TermPool) {
        byID.merge(pool.byID, uniquingKeysWith: { $1 })
        byName.merge(pool.byName, uniquingKeysWith: { $1 })
    }
    
}
