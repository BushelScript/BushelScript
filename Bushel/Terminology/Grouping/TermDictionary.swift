import Foundation
import SDEFinitely

// MARK: Definition

/// A collection of terms.
public class TermDictionary: TerminologySource, CustomDebugStringConvertible {
    
    private var byID: [Term.ID : Term] = [:]
    private var byName: [Term.Name : Term] = [:]
    
    /// Constituent terms that export their dictionary contents.
    private(set) public var exportingTerms: Set<Term> = []
    
    /// Initializes with no contents.
    public init() {
    }
    
    /// Initializes with the terms in `contents`.
    public init<Contents: TermCollection>(contents: Contents) {
        self.byID = Dictionary(uniqueKeysWithValues: contents.map { (key: $0.id, value: $0) })
        self.byName = Dictionary(uniqueKeysWithValues:
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            })
        findExportingTerms(in: contents)
    }
    
    /// Initializes from the terms in `old` and then merges all terms in `new`
    /// into the new dictionary, resolving conflicts in a way that preserves
    /// AppleScript compatibility.
    /// `new`'s term pool is used and `old`'s is ignored.
    public init(merging new: TermDictionary, into old: TermDictionary) {
        self.byID = new.byID.merging(old.byID, uniquingKeysWith: TermDictionary.whichTermWins)
        self.byName = new.byName.merging(old.byName, uniquingKeysWith: TermDictionary.whichTermWins)
        findExportingTerms(in: self.byID.values)
    }
    
    /// The terms in the dictionary.
    public var contents: some TermCollection {
        byID.values
    }
    
    /// The term with ID `id`, or nil if such a term is not in the dictionary.
    public func term(id: Term.ID) -> Term? {
        byID[id]
    }
    
    /// The term named `name`, if nil if such a term is not in the dictionary.
    public func term(named name: Term.Name) -> Term? {
        byName[name]
    }
    
    /// Adds `term` to the dictionary and the term pool.
    public func add(_ term: Term) {
        byID[term.id] = term
        if let name = term.name {
            byName[name] = term
        }
        findExportingTerms(in: [term])
    }
    
    /// Adds all terms in `terms` to the dictionary and the term pool.
    public func add(_ terms: [Term]) {
        byID.merge(terms.map { (key: $0.id, value: $0) }, uniquingKeysWith: TermDictionary.whichTermWins)
        byName.merge(
            terms.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: TermDictionary.whichTermWins
        )
        findExportingTerms(in: terms)
    }
    
    /// Adds all terms in `dictionary` to this dictionary, resolving conflicts
    /// in a way that preserves AppleScript compatibility.
    public func merge(_ dictionary: TermDictionary) {
        byID.merge(dictionary.byID, uniquingKeysWith: TermDictionary.whichTermWins)
        byName.merge(dictionary.byName, uniquingKeysWith: TermDictionary.whichTermWins)
        findExportingTerms(in: dictionary.byID.values)
    }
    
    private func findExportingTerms<Terms: Collection>(in terms: Terms) where Terms.Element == Term {
        for term in terms {
            if term.exports {
                exportingTerms.insert(term)
            }
        }
    }
    
    private static func whichTermWins(_ old: Term, _ new: Term) -> Term {
        // For compatibility.
        // e.g., AppleScript sees Xcode : project as a class whilst ignoring the identically named property term.
        if case .type = old.role, case .property = new.role {
            return old
        }
        return new
    }
    
    public var debugDescription: String {
        return "[TermDictionary:\n\t\(byID)\n]"
    }
    
}

public class ParameterTermDictionary: TerminologySource {
    
    private var contentsByID: [Term.ID : Term]
    private var contentsByName: [Term.Name : Term]
    
    public init(contents: [Term] = []) {
        self.contentsByID = Dictionary(contents.map { (key: $0.id, value: $0) }, uniquingKeysWith: { x, _ in x })
        self.contentsByName = Dictionary(
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: { x, _ in x }
        )
    }
    
    public func term(id: Term.ID) -> Term? {
        return contentsByID[id]
    }
    
    public func term(named name: Term.Name) -> Term? {
        return contentsByName[name]
    }
    
    public func add(_ term: Term) {
        contentsByID[term.id] = term
        if let name = term.name {
            contentsByName[name] = term
        }
    }
    
}

extension TermDictionary: Hashable {
    
    public static func == (lhs: TermDictionary, rhs: TermDictionary) -> Bool {
        return lhs.byID == rhs.byID
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(byID)
    }
    
}

// MARK: Generic term collection

public protocol TermCollection: Collection where Element == Term {}

extension Array: TermCollection where Element == Term {}
extension Set: TermCollection where Element == Term {}
extension Dictionary.Keys: TermCollection where Element == Term {}
extension Dictionary.Values: TermCollection where Element == Term {}
