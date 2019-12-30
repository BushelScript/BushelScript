import Foundation

/// A collection of all the terms encountered in an entire program.
/// Suitable for error message formatting.
public class TermPool: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var byUID: [TermUID : Term] = [:]
    private(set) public var byUIDName: [TermUID.Name : Term] = [:]
    private(set) public var byName: [TermName : Term] = [:]
    
    public init(contents: Set<Term> = []) {
        for term in contents {
            add(term)
        }
    }
    
    public func term(forUID uid: TermUID) -> Term? {
        return byUID[uid]
    }
    
    public func term(forCode code: OSType) -> Term? {
        return byUIDName[.ae4(code: code)]
    }
    
    public func term(named name: TermName) -> Term? {
        return byName[name]
    }
    
    public func add(_ term: Term) {
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
    
    public var pool: TermPool {
        return self
    }
    
}
