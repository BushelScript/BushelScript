import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var dictionaryStack: [TermDictionary] = []
    private var exportedDictionaries: [TermDictionary] = []
    
    private(set) public var pool = TermPool()
    
    public init() {
        push()
    }
    
    public func term(named name: TermName) -> Term? {
        for dictionary in dictionaryStack {
            if let term = dictionary.term(named: name) {
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
        let dictionary = pool.dictionary(named: name)
        dictionaryStack.append(dictionary)
        return dictionary
    }
    
    public mutating func pop() {
        dictionaryStack.removeLast()
    }
    
    public mutating func dictionary(named name: TermName, exports: Bool) -> TermDictionary {
        return pool.dictionary(named: name, exports: exports)
    }
    
    public mutating func dictionary(named name: TermName) -> TermDictionary {
        return pool.dictionary(named: name)
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
        for term in terms {
            add(term)
        }
    }
    
}
