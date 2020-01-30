import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var dictionaryStack: [TermDictionary] = []
    private var allExportingDictionaries: [TermDictionary] {
        dictionaryStack.flatMap { dictionary in
            dictionary.exportingDictionaryContainers.values.compactMap({ dictionaryContainer in
                dictionaryContainer.storedDictionary
            })
        }
    }
    
    private(set) public var pool = TermPool()
    
    public init() {
        pushRoot()
    }
    
    public func term(forUID uid: TypedTermUID) -> Term? {
        findTerm { dictionary in dictionary.term(forUID: uid) }
    }
    
    public func term(named name: TermName) -> Term? {
        findTerm { dictionary in dictionary.term(named: name) }
    }
    
    private func findTerm(_ extractTerm: (TermDictionary) -> Term?) -> Term? {
        find(in: dictionaryStack.reversed(), extractTerm) ?? find(in: allExportingDictionaries.reversed(), extractTerm)
    }
    
    private func find<Dictionaries: Collection>(in dictionaries: Dictionaries, _ extractTerm: (TermDictionary) -> Term?) -> Term? where Dictionaries.Element == TermDictionary {
        for dictionary in dictionaries {
            if let term = extractTerm(dictionary) {
                return term
            }
        }
        return nil
    }
    
    /// Constructs a `TermUID` in the `id` domain that uniquely represents
    /// a term defined in the current dictionary with the provided name.
    /// - Parameter name: The name of the term residing in the current
    ///                   dictionary.
    public func makeUID(forName name: TermName) -> TermUID {
        .id("\(dictionaryStack.compactMap { $0.name?.normalized }.joined(separator: ":")):\(name)")
    }
    /// Constructs a universally unique `TermUID` in the `id` domain.
    public func makeAnonymousUUID() -> TermUID {
        makeUID(forName: TermName(UUID().uuidString))
    }
    
    @discardableResult
    public mutating func push(dictionary: TermDictionary) -> TermDictionary {
        dictionaryStack.append(dictionary)
        return dictionary
    }
    
    @discardableResult
    public mutating func pushUnnamedDictionary(exports: Bool = false) -> TermDictionary {
        push(dictionary: TermDictionary(pool: pool, uid: makeAnonymousUUID(), name: nil, exports: false))
    }
    
    @discardableResult
    public mutating func push(for term: TermDictionaryContainer) -> TermDictionary {
        push(dictionary: term.makeDictionary(under: pool))
    }
    
    @discardableResult
    public mutating func pushDictionaryTerm(forUID uid: TermUID, exports: Bool = false) -> TermDictionary {
        let dictionaryTerm =
            term(forUID: TypedTermUID(.dictionary, uid)) as? DictionaryTerm ??
                add(DictionaryTerm(uid, name: nil, exports: exports))
        return push(for: dictionaryTerm)
    }
    
    private mutating func pushRoot() {
        let rootUID = TermUID(DictionaryUID.BushelScript)
        push(dictionary: TermDictionary(pool: pool, uid: rootUID, name: nil, exports: false))
    }
    
    public mutating func pop() {
        if !dictionaryStack.isEmpty {
            dictionaryStack.removeLast()
        }
    }
    
    @discardableResult
    public mutating func add<Term: Bushel.Term>(_ term: Term) -> Term {
        if dictionaryStack.isEmpty {
            pushRoot()
        }
        let dictionary = dictionaryStack[dictionaryStack.index(before: dictionaryStack.endIndex)]
        dictionary.add(term)
        pool.add(term)
        return term
    }
    
    @discardableResult
    public mutating func add<Term: Bushel.Term>(_ terms: Set<Term>) -> Set<Term> {
        for term in terms {
            add(term)
        }
        return terms
    }
    
}
