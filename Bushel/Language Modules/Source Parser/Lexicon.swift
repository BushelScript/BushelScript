import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: ByNameTermLookup, CustomDebugStringConvertible {
    
    /// Default ID of the root term.
    public static let defaultRootTermID = Term.ID(Variables.Script)
    
    private(set) public var stack: Stack<Term>
    private var exporting: [Term] {
        stack.contents.flatMap { $0.dictionary.exportingTerms }
    }
    
    public init(_ stack: Stack<Term> = Stack<Term>(bottom: Term(Lexicon.defaultRootTermID, exports: false))) {
        self.stack = stack
    }
    
    public func term(id: Term.ID) -> Term? {
        findTerm { dictionary in dictionary.term(id: id) }
    }
    
    public func term(named name: Term.Name) -> Term? {
        findTerm { dictionary in dictionary.term(named: name) }
    }
    
    public func term(named name: Term.Name, role: Term.SyntacticRole) -> Term? {
        findTerm { dictionary in dictionary.term(named: name, role: role) }
    }
    
    private func findTerm(_ extractTerm: (TermDictionary) -> Term?) -> Term? {
        find(in: stack.contents.reversed(), extractTerm) ?? find(in: exporting.reversed(), extractTerm)
    }
    
    private func find<Terms: Collection>(in terms: Terms, _ extractTerm: (TermDictionary) -> Term?) -> Term? where Terms.Element == Term {
        for term in terms {
            if let term = extractTerm(term.dictionary) {
                return term
            }
        }
        return nil
    }
    
    public mutating func lookUpOrDefine(_ role: Term.SyntacticRole, name: Term.Name, dictionary: TermDictionary = TermDictionary()) -> Term {
        if let existing = term(named: name, role: role) {
            existing.dictionary.merge(dictionary)
            return existing
        }
        return add(Term(role, makeIDURI(forName: name), name: name, dictionary: dictionary))
    }
    
    /// Constructs a `SemanticURI` with the `id` scheme that uniquely represents
    /// a term defined in the current dictionary with the provided name.
    /// - Parameter name: The name of the term residing in the current
    ///                   dictionary.
    public func makeIDURI(forName name: Term.Name) -> Term.SemanticURI {
        var components: [String] = []
        let lastStackTermURI = stack.top.uri
        if let pathnameComponents = lastStackTermURI.pathname?.components {
            components.append(contentsOf: pathnameComponents)
        } else {
            components.append("\(lastStackTermURI)")
        }
        components.append(name.normalized)
        return .id(Term.SemanticURI.Pathname(components))
    }
    /// Constructs a universally unique `SemanticURI` with the `id` scheme.
    public func makeUniqueURI() -> Term.SemanticURI {
        makeIDURI(forName: Term.Name(UUID().uuidString))
    }
    
    public var bottom: Term {
        stack.bottom
    }
    
    public var top: Term {
        get {
            stack.top
        }
        set {
            stack.top = newValue
        }
    }
    
    public mutating func push(_ term: Term) {
        stack.push(term)
    }
    
    public mutating func addPush(_ term: Term) {
        add(term)
        push(term)
    }
    
    public mutating func pushUnnamedDictionary(exports: Bool = false) {
        addPush(Term(.constant, makeUniqueURI(), exports: exports))
    }
    
    public mutating func pushDictionaryTerm(uri: Term.SemanticURI, exports: Bool = false) {
        let id = Term.ID(.constant, uri)
        let dictionaryTerm = term(id: id) ?? add(Term(id, exports: exports))
        addPush(dictionaryTerm)
    }
    
    public mutating func pop() {
        stack.pop()
    }
    
    @discardableResult
    public mutating func add(_ term: Term) -> Term {
        stack.top.dictionary.add(term)
        return term
    }
    
    @discardableResult
    public mutating func add(_ terms: Set<Term>) -> Set<Term> {
        for term in terms {
            add(term)
        }
        return terms
    }
    
    public var debugDescription: String {
        stack.contents
            .reversed()
            .enumerated()
            .map { "\($0.offset + 1): \($0.element.debugDescription)" }
            .joined(separator: "\n")
    }
    
}
