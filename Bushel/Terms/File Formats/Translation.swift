import os
import Yams

private let log = OSLog(subsystem: logSubsystem, category: "Translations")

/// A mapping from term IDs to localized names and documentation.
///
/// Can be constructed from the contents of a YAML-based translation file.
public struct Translation {
    
    public static let currentFormat = 0.6
    
    public struct ParseError: Error {
        
        public var error: Error
        public var path: String?
        
        fileprivate init(_ error: Error, path: String? = nil) {
            self.error = error
            self.path = path
        }
        
        public enum Error {
            case invalidSyntax
            case noOuterMapping
            case missingFormat
            case missingLanguage
            case invalidFormat
            case invalidTermRole
            case invalidURISchemeMapping
            case invalidURIScheme
            case invalidURINameMapping
            case invalidURIName
            case invalidTermName
        }
        
    }
    
    public var format: Double
    public var language: String
    public var termIDToNames: [Term.ID : Set<Term.Name>] = [:]
    public var termIDToDoc: [Term.ID : String] = [:]
    
    public init(from url: URL) throws {
        do {
            try self.init(source: try String(contentsOf: url))
        } catch let error as ParseError {
            throw ParseError(error.error, path: url.path)
        }
    }
    
    public init(source: String) throws {
        guard let yaml = try Yams.compose(yaml: source) else {
            throw ParseError(.invalidSyntax)
        }
        guard
            case .mapping(let outerMapping) = yaml,
            case .mapping(let translation) = outerMapping["translation"]
        else {
            throw ParseError(.noOuterMapping)
        }
        guard case .scalar(let format) = translation["format"] else {
            throw ParseError(.missingFormat)
        }
        guard case .scalar(let language) = translation["language"] else {
            throw ParseError(.missingLanguage)
        }
        self.language = language.string
        
        var formatString = format.string
        if formatString.hasPrefix("v") {
            formatString.removeFirst()
        }
        guard Double(formatString) == Translation.currentFormat else {
            throw ParseError(.invalidFormat)
        }
        self.format = Translation.currentFormat
        
        guard case .mapping(let mappings) = translation["mappings"] else {
            return
        }
        for (termKind, uidDomainMapping) in mappings {
            guard
                case .scalar(let termKindScalar) = termKind,
                let termKind = Term.SyntacticRole(rawValue: termKindScalar.string)
            else {
                throw ParseError(.invalidTermRole)
            }
            guard case .mapping(let uidDomainMapping) = uidDomainMapping else {
                throw ParseError(.invalidURISchemeMapping)
            }
            for (uidDomain, uidDataMapping) in uidDomainMapping {
                guard
                    case .scalar(let uidDomainScalar) = uidDomain,
                    let uriScheme = TermURIScheme(rawValue: uidDomainScalar.string)
                else {
                    throw ParseError(.invalidURIScheme)
                }
                guard case .mapping(let uidDataMapping) = uidDataMapping else {
                    throw ParseError(.invalidURINameMapping)
                }
                for (uidData, valueNode) in uidDataMapping {
                    guard case .scalar(let uidDataScalar) = uidData else {
                        throw ParseError(.invalidURIName)
                    }
                    let uidsAndValueNodes: [(Term.SemanticURI, Yams.Node)] = try {
                        guard let uid = Term.SemanticURI(scheme: uriScheme.rawValue, name: uidDataScalar.string) else {
                            throw ParseError(.invalidURIName)
                        }
                        return [(uid, valueNode)]
                    }()
                    for (uid, valueNode) in uidsAndValueNodes {
                        func process(valueNode: Yams.Node, id: Term.ID) throws {
                            switch valueNode {
                            case .scalar(let termNameScalar):
                                addTermName(id: id, termName: Term.Name(termNameScalar.string))
                            case .sequence(let synonymsSequence):
                                for synonym in synonymsSequence {
                                    try process(valueNode: synonym, id: id)
                                }
                            case .mapping(let mapping):
                                guard let name = mapping["name"] else {
                                    throw ParseError(.invalidTermName)
                                }
                                try process(valueNode: name, id: id)
                                if case .scalar(let doc) = mapping["doc"] {
                                    self.termIDToDoc[id] = doc.string
                                }
                            }
                        }
                        
                        let typedUID = Term.ID(termKind, uid)
                        try process(valueNode: valueNode, id: typedUID)
                    }
                }
            }
        }
    }
    
    private mutating func addTermName(id: Term.ID, termName: Term.Name) {
        if self.termIDToNames[id] == nil {
            self.termIDToNames[id] = []
        }
        self.termIDToNames[id]!.insert(termName)
    }
    
    public subscript(_ id: Term.ID) -> Set<Term.Name> {
        termIDToNames[id] ?? []
    }
    public subscript(_ id: Term.ID) -> Term.Name? {
        termIDToNames[id]?.first
    }
    
    public func doc(for id: Term.ID) -> String {
        termIDToDoc[id] ?? ""
    }
    
    public func makeTerms(cache: BushelCache) -> TermDictionary {
        var resourceTerms: [Term] = []
        
        let termPairs: [(Term.ID, [Term])] = termIDToNames.map { kv in
            let (termID, termNames) = kv
            return (termID, termNames.compactMap { termName in
                Term(termID, name: termName, resource: termID.role == .resource ? Resource(normalized: termName.normalized, cache: cache.resourceCache) : nil)
            })
        }
        let allTerms = [Term.ID : [Term]](uniqueKeysWithValues: termPairs)
        let allTermsByURI = [Term.SemanticURI : [Term]](allTerms.map { (key: $0.key.uri, value: $0.value) }, uniquingKeysWith: {
            (left: [Term], right: [Term]) -> [Term] in
            Term.SyntacticRole.allCases.firstIndex(of: left.first!.role)! < Term.SyntacticRole.allCases.firstIndex(of: right.first!.role)! ? right : left
        })
        
        // Convert flat allTerms to dictionary-nested resultTerms
        var resultTerms = allTerms
        for (termID, terms) in allTerms {
            if termID.role == .parameter {
                for parameterTerm in terms where parameterTerm.role == .parameter {
                    if
                        let commandURI = parameterTerm.uri.commandURI,
                        let commandTerms = allTerms[Term.ID(.command, commandURI)]
                    {
                        for commandTerm in commandTerms {
                            commandTerm.dictionary.add(parameterTerm)
                        }
                    }
                }
                resultTerms.removeValue(forKey: termID)
            } else if termID.role == .resource {
                for resourceTerm in terms where resourceTerm.role == .resource {
                    resourceTerms.append(resourceTerm)
                }
            } else {
                if
                    // For any other term with a pathname URI
                    // that has two or more components (e.g., real/pi),
                    let ancestorPath = termID.uri.pathname?.dropLast(),
                    !ancestorPath.isEmpty,
                    // For each of the terms identified by the ancestor path (e.g., real)
                    let ancestorTerms = allTermsByURI[.id(ancestorPath)]
                {
                    let ancestorDictionaries = ancestorTerms.map { $0.dictionary }
                    if !ancestorDictionaries.isEmpty {
                        // Add the nested terms to the appropriate dictionary.
                        for dictionary in ancestorDictionaries {
                            dictionary.add(terms)
                        }
                        // Remove from base dictionary. The term may still be
                        // accessible from the base through dictionary exporting,
                        // but it should not be redefined in it.
                        resultTerms.removeValue(forKey: termID)
                    }
                }
            }
        }
        
        for resourceTerm in resourceTerms {
            try? cache.dictionaryCache.loadResourceDictionary(for: resourceTerm)
        }
        
        return TermDictionary(contents: resultTerms.values.reduce(into: Set()) { set, terms in set.formUnion(terms) })
    }
    
    public func makeTermDocs(for rootDictionary: TermDictionary) -> [Term.ID : TermDoc] {
        var docs: [Term.ID : TermDoc] = [:]
        for term in rootDictionary.contents {
            docs[term.id] = TermDoc(term: term, doc: termIDToDoc[term.id] ?? "")
            docs.merge(makeTermDocs(for: term.dictionary), uniquingKeysWith: { old, new in new })
        }
        return docs
    }
    
}

/// List of term UID domains the translation file parser understands.
private enum TermURIScheme: String, CaseIterable {
    
    /// Uses simple key-value mappings.
    case ae4, ae8, ae12
    /// Allows nesting for easy and DRY scoping.
    case id, res
    
}

extension Translation.ParseError: LocalizedError {
    
    public var errorDescription: String? {
        "Failed to parse translation\(path.map { " at \($0)" } ?? ""): " + {
            switch error {
            case .invalidSyntax:
                return "The file contains ill-formed YAML."
            case .noOuterMapping:
                return "File does not start with a 'translation:' mapping."
            case .missingFormat:
                return "The 'translation' mapping has no 'format:' key. This required field is used to confirm that the file format is readable by this BushelScript version."
            case .missingLanguage:
                return "The 'translation' mapping has no 'language' key. This required field declares what language module the translation applies to."
            case .invalidFormat:
                return "The file's declared format is incompatible."
            case .invalidTermRole:
                return "An unrecognized term role was found. Valid values are: \(Term.SyntacticRole.allCases.map { $0.rawValue }.joined(separator: ", "))."
            case .invalidURISchemeMapping:
                return "Expected a mapping as the value for a term role, but found a scalar or sequence instead."
            case .invalidURIScheme:
                return "An unrecognized term URI scheme was found. Valid values are: \(TermURIScheme.allCases.map { $0.rawValue }.joined(separator: ", "))"
            case .invalidURINameMapping:
                return "Expected a mapping as the value for a term URI scheme, but found a scalar or sequence instead."
            case .invalidURIName:
                return "Encountered an invalid name for a term URI. For example, the 'ae4' scheme expects a four-character MacRoman string."
            case .invalidTermName:
                return "Expected a scalar or sequence for a term name but found a mapping instead."
            }
        }()
    }
    
}
