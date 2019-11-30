import Foundation

/// A collection of all the terms encountered in an entire program.
/// Suitable for error message formatting.
public class TermPool: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    // TODO: Keep track of where terms came from.
    //       To enabled messages like, e.g.,
    //           undefined term "outgoing mssage"
    //               - fix: did you mean “outgoing message” (from dictionary “Mail”)?
    public var containerTerms: [TermName? : TermDictionaryContainer] = [:]
    public var byName: [TermName : Term] = [:]
    public var byCode: [OSType : ConstantTerm] = [:]
    public var byID: [String : Term] = [:]
    
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
        if let container = term as? TermDictionaryContainer {
            containerTerms[term.name] = container
        }
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
    
    public func dictionary(named name: TermName?, exports: Bool = false) -> TermDictionary {
        if let dictionary = containerTerms[name]?.terminology {
            return dictionary
        } else {
            return makeDictionary(named: name, exports: exports)
        }
    }
    
    private func makeDictionary(named name: TermName?, exports: Bool = false) -> TermDictionary {
        let container: TermDictionaryContainer
        let dictionary = TermDictionary(pool: self, name: name, exports: exports)
        if let name = name {
            container = DictionaryTerm(name.normalized, name: name, terminology: dictionary)
        } else {
            container = UnnamedDictionaryContainer(terminology: dictionary)
        }
        containerTerms[name] = container
        return dictionary
    }
    
    public var pool: TermPool {
        return self
    }
    
}

private class UnnamedDictionaryContainer: TermDictionaryContainer {
    
    var terminology: TermDictionary?
    
    init(terminology: TermDictionary?) {
        self.terminology = terminology
    }
    
}
