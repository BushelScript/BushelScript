import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: TerminologySource {
    
    public typealias Term = Bushel.Term
    
    private(set) public var stack: [Term] = []
    private var exporting: [Term] {
        stack.flatMap { term in
            term.dictionary?.exportingTerms.compactMap { $0 } ?? []
        }
    }
    
    private(set) public var pool = TermPool()
    
    public init() {
        stack.append(Term(Term.ID(Dictionaries.root), exports: false))
    }
    
    public func term(id: Term.ID) -> Term? {
        findTerm { dictionary in dictionary.term(id: id) }
    }
    
    public func term(named name: Term.Name) -> Term? {
        findTerm { dictionary in dictionary.term(named: name) }
    }
    
    private func findTerm(_ extractTerm: (TermDictionary) -> Term?) -> Term? {
        find(in: stack.reversed(), extractTerm) ?? find(in: exporting.reversed(), extractTerm)
    }
    
    private func find<Terms: Collection>(in terms: Terms, _ extractTerm: (TermDictionary) -> Term?) -> Term? where Terms.Element == Term {
        for term in terms {
            if
                let dictionary = term.dictionary,
                let term = extractTerm(dictionary)
            {
                return term
            }
        }
        return nil
    }
    
    /// Constructs a `SemanticURI` with the `id` scheme that uniquely represents
    /// a term defined in the current dictionary with the provided name.
    /// - Parameter name: The name of the term residing in the current
    ///                   dictionary.
    public func makeURI(forName name: Term.Name) -> Term.SemanticURI {
        .id(Term.SemanticURI.Pathname(rawValue: "\(stack.compactMap { $0.name?.normalized }.joined(separator: String(Term.SemanticURI.Pathname.separator)))\(Term.SemanticURI.Pathname.separator)\(name)"))
    }
    /// Constructs a universally unique `SemanticURI` with the `id` scheme.
    public func makeUniqueURI() -> Term.SemanticURI {
        makeURI(forName: Term.Name(UUID().uuidString))
    }
    
    public mutating func push(_ term: Term) {
        add(term)
        stack.append(term)
    }
    
    public mutating func pushUnnamedDictionary(exports: Bool = false) {
        push(Term(.dictionary, makeUniqueURI(), exports: false))
    }
    
    public mutating func pushDictionaryTerm(uri: Term.SemanticURI, exports: Bool = false) {
        let id = Term.ID(.dictionary, uri)
        let dictionaryTerm = term(id: id) ?? add(Term(id, exports: exports))
        push(dictionaryTerm)
    }
    
    public mutating func pop() {
        if stack.count > 1 {
            stack.removeLast()
        }
    }
    
    @discardableResult
    public mutating func add(_ term: Term) -> Term {
        stack.last!.makeDictionary(under: pool).add(term)
        return term
    }
    
    @discardableResult
    public mutating func add(_ terms: Set<Term>) -> Set<Term> {
        for term in terms {
            add(term)
        }
        return terms
    }
    
}
