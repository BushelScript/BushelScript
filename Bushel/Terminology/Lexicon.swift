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
    
    public func term(named name: TermName) -> Term? {
        func find<Dictionaries: Collection>(in dictionaries: Dictionaries) -> Term? where Dictionaries.Element == TermDictionary {
            for dictionary in dictionaries {
                if let term = dictionary.term(named: name) {
                    return term
                }
            }
            return nil
        }
        return find(in: dictionaryStack.reversed()) ?? find(in: allExportingDictionaries.reversed())
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
