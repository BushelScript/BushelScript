import Foundation

/// A collection of all the terms encountered in an entire program.
/// Suitable for error message formatting.
public class TermPool: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var byTypedUID: [TypedTermUID : Term] = [:]
    private(set) public var byUID: [TermUID : Term] = [:]
    private(set) public var byName: [TermName : Term] = [:]
    
    public init(contents: Set<Term> = []) {
        for term in contents {
            add(term)
        }
    }
    
    public func term(forUID uid: TypedTermUID) -> Term? {
        return byTypedUID[uid]
    }
    
    public func term(named name: TermName) -> Term? {
        return byName[name]
    }
    
    public func add(_ term: Term) {
        byTypedUID[term.typedUID] = term
        byUID[term.uid] = term
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
        byTypedUID.merge(pool.byTypedUID, uniquingKeysWith: { $1 })
        byUID.merge(pool.byUID, uniquingKeysWith: { $1 })
        byName.merge(pool.byName, uniquingKeysWith: { $1 })
    }
    
}
