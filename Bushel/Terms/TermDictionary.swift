import Foundation
import SDEFinitely

// MARK: Definition

/// A collection of terms.
public final class TermDictionary: ByNameTermLookup, CustomDebugStringConvertible {
    
    /// The terms in the dictionary.
    public private(set) var contents: NSMutableOrderedSet/*<Term>*/ = []
    
    private var byID: [Term.ID : Term] = [:]
    private var byName: [Term.Name : Term] = [:]
    
    /// Constituent terms that export their dictionary contents.
    private(set) public var exportingTerms: [Term] = []
    
    /// Initializes with no contents.
    public init() {
    }
    
    /// Initializes with the terms in `contents`.
    public init<Contents: TermCollection>(contents: Contents) {
        self.contents = NSMutableOrderedSet(array: Array(contents))
        self.byID = Dictionary(contents.map { (key: $0.id, value: $0) }, uniquingKeysWith: TermDictionary.resolveTermConflict)
        self.byName = Dictionary(
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: TermDictionary.resolveTermConflict)
        findExportingTerms(in: contents)
    }
    
    /// Initializes a copy of `dictionary`.
    public init(_ dictionary: TermDictionary) {
        self.contents = dictionary.contents
        self.byID = dictionary.byID
        self.byName = dictionary.byName
        self.exportingTerms = dictionary.exportingTerms
    }
    
    /// Initializes from the terms in `old` and then merges all terms in `new`
    /// into the new dictionary, resolving conflicts in a way that preserves
    /// AppleScript compatibility.
    public convenience init(merging new: TermDictionary, into old: TermDictionary) {
        self.init(new)
        merge(old)
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
        contents.insert(terms as [Any], at: IndexSet(integersIn: contents.count..<(contents.count + terms.count)))
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
        if self === dictionary {
            return
        }
        let contents = dictionary.contents
        for i in 0..<contents.count {
            let term = contents.object(at: i) as! Term
            let index = self.contents.index(of: term)
            if index != NSNotFound {
                contents.setObject(TermDictionary.resolveTermConflict(self.contents.object(at: index) as! Term, term), at: i)
            }
        }
        for term in self.contents {
            contents.insert(term, at: contents.count)
        }
        self.contents = contents
        byID.merge(dictionary.byID, uniquingKeysWith: TermDictionary.resolveTermConflict)
        byName.merge(dictionary.byName, uniquingKeysWith: TermDictionary.resolveTermConflict)
        findExportingTerms(in: dictionary.byID.values)
    }
    
    private func findExportingTerms<Terms: Collection>(in terms: Terms) where Terms.Element == Term {
        nextTerm: for term in terms {
            if term.exports {
                guard !exportingTerms.isEmpty else {
                    exportingTerms.append(term)
                    continue nextTerm
                }
                // Insert in sorted position.
                var begin = 0
                var end = exportingTerms.count
                var middle = 0
                while begin < end {
                    middle = (begin + end) / 2
                    if term < exportingTerms[middle] {
                        end = middle
                    } else if term > exportingTerms[middle] {
                        begin = middle + 1
                    } else {
                        continue nextTerm
                    }
                }
                middle = (begin + end) / 2
                if middle == exportingTerms.count || term != exportingTerms[middle] {
                    exportingTerms.insert(term, at: middle)
                }
                assert(exportingTerms.sorted() == exportingTerms)
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
        return lhs.contents.set == rhs.contents.set
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(contents.set)
    }
    
}

// MARK: Generic term collection

public protocol TermCollection: Collection where Element == Term {}

extension Array: TermCollection where Element == Term {}
extension Set: TermCollection where Element == Term {}
extension Dictionary.Keys: TermCollection where Element == Term {}
extension Dictionary.Values: TermCollection where Element == Term {}
