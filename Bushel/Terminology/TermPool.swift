import Foundation

/// A collection of all the terms encountered in an entire program.
/// Suitable for error message formatting.
public class TermPool: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var byName: [TermName : Term] = [:]
    private(set) public var byCode: [OSType : ConstantTerm] = [:]
    private(set) public var byID: [String : Term] = [:]
    
    public init(contents: Set<Term> = []) {
        for term in contents {
            add(term)
        }
    }
    
    public func term(named name: TermName) -> Term? {
        return byName[name]
    }
    
    public func term(forCode code: OSType) -> ConstantTerm? {
        return byCode[code]
    }
    
    public func term(forID id: String) -> Term? {
        return byID[id]
    }
    
    public func add(_ term: Term) {
        if let name = term.name {
            byName[name] = term
        }
        if let term = term as? ConstantTerm, let code = term.code {
            byCode[code] = term
        }
        byID[term.uid] = term
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
