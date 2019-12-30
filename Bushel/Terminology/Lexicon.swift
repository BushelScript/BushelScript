import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var dictionaryStack: [TermDictionary] = []
    private var allExportingDictionaries: [TermDictionary] {
        dictionaryStack.flatMap { dictionary in
            dictionary.exportingDictionaryContainers.values.compactMap({ dictionaryContainer in
                dictionaryContainer.terminology
            })
        }
    }
    
    private(set) public var pool = TermPool()
    
    public init() {
        push()
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
    
    public func makeUID(_ kind: String, _ names: TermName...) -> String {
        "\(dictionaryStack.compactMap { $0.name?.normalized }.joined(separator: ".")).\(kind).\(names.map { $0.normalized }.joined(separator: "."))"
    }
    
    @discardableResult
    public mutating func push(name: TermName? = nil) -> TermDictionary {
        let dictionary =
            name.flatMap { self.dictionary(named: $0) } ??
            TermDictionary(pool: pool, name: name, exports: false)
        dictionaryStack.append(dictionary)
        return dictionary
    }
    
    @discardableResult
    public mutating func push(uid: TypedTermUID, name: TermName? = nil) -> TermDictionary {
        let dictionary = self.dictionary(forUID: uid) ?? TermDictionary(pool: pool, name: name, exports: false)
        dictionaryStack.append(dictionary)
        return dictionary
    }
    
    public mutating func pop() {
        if !dictionaryStack.isEmpty {
            dictionaryStack.removeLast()
        }
    }
    
    public mutating func add(_ term: Term) {
        if dictionaryStack.isEmpty {
            push()
        }
        let dictionary = dictionaryStack[dictionaryStack.index(before: dictionaryStack.endIndex)]
        dictionary.add(term)
        pool.add(term)
    }
    
    public mutating func add(_ terms: Set<Term>) {
        signpostBegin()
        defer {
            signpostEnd()
        }
        
        for term in terms {
            add(term)
        }
    }
    
}
