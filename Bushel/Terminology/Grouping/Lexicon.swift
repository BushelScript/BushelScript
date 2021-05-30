import Foundation

/// A stack of dictionaries.
/// Effectively creates a scoping system for terms.
public struct Lexicon: ByNameTermLookup, CustomDebugStringConvertible {
    
    /// Default ID of the root term.
    public static let defaultRootTermID = Term.ID(Variables.Script)
    
    private(set) public var stack: [Term] = []
    private var exporting: [Term] {
        stack.flatMap { $0.dictionary.exportingTerms.sorted() }
    }
    
    public init() {
        stack.append(Term(Lexicon.defaultRootTermID, exports: false))
    }
    
    public var rootTerm: Term {
        get {
            stack[0]
        }
        set {
            stack[0] = newValue
        }
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
            if let term = extractTerm(term.dictionary) {
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
        var components: [String] = []
        let lastStackTermURI = stack.last!.uri
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
        makeURI(forName: Term.Name(UUID().uuidString))
    }
    
    public mutating func push(_ term: Term) {
        stack.append(term)
    }
    
    public mutating func addPush(_ term: Term) {
        add(term)
        push(term)
    }
    
    public mutating func pushUnnamedDictionary(exports: Bool = false) {
        addPush(Term(.dictionary, makeUniqueURI(), exports: exports))
    }
    
    public mutating func pushDictionaryTerm(uri: Term.SemanticURI, exports: Bool = false) {
        let id = Term.ID(.dictionary, uri)
        let dictionaryTerm = term(id: id) ?? add(Term(id, exports: exports))
        addPush(dictionaryTerm)
    }
    
    public mutating func pop() {
        if stack.count > 1 {
            stack.removeLast()
        }
    }
    
    @discardableResult
    public mutating func add(_ term: Term) -> Term {
        stack.last!.dictionary.add(term)
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
        stack
            .reversed()
            .enumerated()
            .map { "\($0.offset + 1): \($0.element.debugDescription)" }
            .joined(separator: "\n")
    }
    
}
