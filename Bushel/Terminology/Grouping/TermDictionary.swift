import Foundation
import SDEFinitely

// MARK: Definition

/// A collection of terms.
public class TermDictionary: ByNameTermLookup, CustomDebugStringConvertible {
    
    private var byID: [Term.ID : Term] = [:]
    private var byName: [Term.Name : Term] = [:]
    
    /// Constituent terms that export their dictionary contents.
    private(set) public var exportingTerms: Set<Term> = []
    
    /// Initializes with no contents.
    public init() {
    }
    
    /// Initializes with the terms in `contents`.
    public init<Contents: TermCollection>(contents: Contents) {
        self.byID = Dictionary(contents.map { (key: $0.id, value: $0) }, uniquingKeysWith: TermDictionary.resolveTermConflict)
        self.byName = Dictionary(
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: TermDictionary.resolveTermConflict)
        findExportingTerms(in: contents)
    }
    
    /// Initializes from the terms in `old` and then merges all terms in `new`
    /// into the new dictionary, resolving conflicts in a way that preserves
    /// AppleScript compatibility.
    public init(merging new: TermDictionary, into old: TermDictionary) {
        self.byID = new.byID.merging(old.byID, uniquingKeysWith: TermDictionary.resolveTermConflict)
        self.byName = new.byName.merging(old.byName, uniquingKeysWith: TermDictionary.resolveTermConflict)
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
    
    /// The term named `name`, or nil if such a term is not in the dictionary.
    public func term(named name: Term.Name) -> Term? {
        byName[name]
    }
    
    /// The term named `name` with `role`, or nil if such a term is not in the
    /// dictionary.
    public func term(named name: Term.Name, role: Term.SyntacticRole) -> Term? {
        let term = byName[name]
        return term?.role == role ? term : nil
    }
    
    /// Adds `term` to the dictionary.
    public func add(_ term: Term) {
        add([term])
    }
    
    /// Adds all terms in `terms` to the dictionary.
    public func add(_ terms: [Term]) {
        byID.merge(terms.map { (key: $0.id, value: $0) }, uniquingKeysWith: TermDictionary.resolveTermConflict)
        byName.merge(
            terms.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: TermDictionary.resolveTermConflict
        )
        findExportingTerms(in: terms)
    }
    
    /// Adds all terms in `dictionary` to this dictionary, resolving conflicts
    /// in a way that preserves AppleScript compatibility.
    public func merge(_ dictionary: TermDictionary) {
        byID.merge(dictionary.byID, uniquingKeysWith: TermDictionary.resolveTermConflict)
        byName.merge(dictionary.byName, uniquingKeysWith: TermDictionary.resolveTermConflict)
        findExportingTerms(in: dictionary.byID.values)
    }
    
    private func findExportingTerms<Terms: Collection>(in terms: Terms) where Terms.Element == Term {
        for term in terms {
            if term.exports {
                exportingTerms.insert(term)
            }
        }
    }
    
    private static func resolveTermConflict(_ old: Term, _ new: Term) -> Term {
        // Merge the dictionaries of conflicting terms.
        old.dictionary.merge(new.dictionary)
        new.dictionary = old.dictionary
        
        // For AppleScript compatibility, types take precedence over properties
        // and constants.
        // This makes sense because types can be used as if they were
        // properties or constants anyway.
        // Also, properties take precedence over constants, for similar reasons.
        if case .type = old.role {
            // e.g., AppleScript sees Xcode -> project as a class,
            // ignoring the identically named property term.
            if case .property = new.role {
                return old
            }
            // e.g., AppleScript sees Microsoft Word -> document as a class,
            // ignoring the identically named constant term.
            if case .constant = new.role {
                return old
            }
        } else if case .property = old.role {
            // e.g., AppleScript sees Finder -> name as a property,
            // ignoring the identically named constant term.
            if case .constant = new.role {
                return old
            }
        }
        
        return new
    }
    
    public var debugDescription: String {
        "\(byID)"
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
