import Bushel
import os
import Yams

private let log = OSLog(subsystem: logSubsystem, category: "Translations")

/// A collection of name mappings for term UIDs.
///
/// Can be constructed from the contents of a YAML-based translation file.
public struct Translation {
    
    public static let currentFormat = 0.3
    
    public enum ParseError: Error {
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
    
    public var format: String
    public var language: String
    public var mappings: [Term.ID : Set<Term.Name>] = [:]
    
    public init(source: String) throws {
        guard let yaml = try Yams.compose(yaml: source) else {
            throw ParseError.invalidSyntax
        }
        guard
            case .mapping(let outerMapping) = yaml,
            case .mapping(let translation) = outerMapping["translation"]
        else {
            throw ParseError.noOuterMapping
        }
        guard case .scalar(let format) = translation["format"] else {
            throw ParseError.missingFormat
        }
        self.format = format.string
        guard case .scalar(let language) = translation["language"] else {
            throw ParseError.missingLanguage
        }
        self.language = language.string
        
        if self.format.hasPrefix("v") {
            self.format.removeFirst()
        }
        guard Double(self.format) == Translation.currentFormat else {
            throw ParseError.invalidFormat
        }
        
        guard case .mapping(let mappings) = translation["mappings"] else {
            return
        }
        for (termKind, uidDomainMapping) in mappings {
            guard
                case .scalar(let termKindScalar) = termKind,
                let termKind = Term.SyntacticRole(rawValue: termKindScalar.string)
            else {
                throw ParseError.invalidTermRole
            }
            guard case .mapping(let uidDomainMapping) = uidDomainMapping else {
                throw ParseError.invalidURISchemeMapping
            }
            for (uidDomain, uidDataMapping) in uidDomainMapping {
                guard
                    case .scalar(let uidDomainScalar) = uidDomain,
                    let uriScheme = TermURIScheme(rawValue: uidDomainScalar.string)
                else {
                    throw ParseError.invalidURIScheme
                }
                guard case .mapping(let uidDataMapping) = uidDataMapping else {
                    throw ParseError.invalidURINameMapping
                }
                for (uidData, valueNode) in uidDataMapping {
                    guard case .scalar(let uidDataScalar) = uidData else {
                        throw ParseError.invalidURIName
                    }
                    let uidsAndValueNodes: [(Term.SemanticURI, Yams.Node)] = try {
                        var isRes: Bool = false
                        switch uriScheme {
                        case .res:
                            isRes = true
                            fallthrough
                        case .id:
                            // Requires special handling to support nesting
                            enum ScopeNode {
                                case leaf(name: Term.Name, node: Yams.Node)
                                case branch([(name: Term.Name, node: ScopeNode)])
                            }
                            func process(uidDataName: Term.Name, valueNode: Yams.Node) throws -> ScopeNode {
                                switch valueNode {
                                case .scalar, .sequence:
                                    return .leaf(name: uidDataName, node: valueNode)
                                case .mapping(let valueMapping):
                                    if valueMapping.values.contains(where: { value in
                                            switch value {
                                            case .sequence, .mapping:
                                                return false
                                            case .scalar(let valueScalar):
                                                return valueScalar.string.hasPrefix("/")
                                            }
                                        })
                                    {
                                        return .leaf(name: uidDataName, node: valueNode)
                                    }
                                    return .branch(
                                        try valueMapping.map { kv in
                                            let (nestedUIDDataNode, nestedDataNode) = kv
                                            guard case .scalar(let uidDataNodeScalar) = nestedUIDDataNode else {
                                                throw ParseError.invalidURIName
                                            }
                                            let nestedUIDDataName = Term.Name(uidDataNodeScalar.string)
                                            return (
                                                name: uidDataName,
                                                node: try process(uidDataName: nestedUIDDataName, valueNode: nestedDataNode)
                                            )
                                        }
                                    )
                                }
                            }
                            let scopeNode = try process(uidDataName: Term.Name(uidDataScalar.string), valueNode: valueNode)
                            var namesAndNodes: [(name: Term.SemanticURI.Pathname, node: Yams.Node)] = []
                            func traverse(scopeNode: ScopeNode, under currentScopeNames: [Term.Name]) {
                                switch scopeNode {
                                case .leaf(let name, let node):
                                    namesAndNodes.append((
                                        name: Term.SemanticURI.Pathname((currentScopeNames + [name]).map { $0.normalized }),
                                        node: node
                                    ))
                                case .branch(let namesAndNodes):
                                    for (name, node) in namesAndNodes {
                                        traverse(scopeNode: node, under: currentScopeNames + [name])
                                    }
                                }
                            }
                            traverse(scopeNode: scopeNode, under: [])
                            return namesAndNodes.map { (isRes ? Term.SemanticURI.res($0.name.rawValue) : Term.SemanticURI.id($0.name), $0.node) }
                        default:
                            guard let uid = Term.SemanticURI(scheme: uriScheme.rawValue, name: uidDataScalar.string) else {
                                throw ParseError.invalidURIName
                            }
                            return [(uid, valueNode)]
                        }
                    }()
                    for (uid, valueNode) in uidsAndValueNodes {
                        func process(valueNode: Yams.Node, id: Term.ID) throws {
                            switch valueNode {
                            case .scalar(let termNameScalar):
                                addMapping(id: id, termName: Term.Name(termNameScalar.string))
                            case .sequence(let synonymsSequence):
                                for synonym in synonymsSequence {
                                    try process(valueNode: synonym, id: id)
                                }
                            default:
                                throw ParseError.invalidTermName
                            }
                        }
                        
                        let typedUID = Term.ID(termKind, uid)
                        try process(valueNode: valueNode, id: typedUID)
                    }
                }
            }
        }
    }
    
    private mutating func addMapping(id: Term.ID, termName: Term.Name) {
        if self.mappings[id] == nil {
            self.mappings[id] = []
        }
        self.mappings[id]!.insert(termName)
    }
    
    public subscript(_ typedUID: Term.ID) -> Set<Term.Name> {
        mappings[typedUID] ?? []
    }
    public subscript(_ typedUID: Term.ID) -> Term.Name? {
        mappings[typedUID]?.first
    }
    
    public func makeTerms(under pool: TermPool) -> Set<Term> {
        var resourceTerms: [Term] = []
        
        let termPairs: [(Term.ID, [Term])] = mappings.map { kv in
            let (termID, termNames) = kv
            return (termID, termNames.compactMap { termName in
                Term(termID, name: termName, resource: termID.role == .resource ? Resource(normalized: termName.normalized) : nil)
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
                            if commandTerm.parameters == nil {
                                commandTerm.parameters = ParameterTermDictionary()
                            }
                            commandTerm.parameters!.add(parameterTerm)
                        }
                    }
                }
                resultTerms.removeValue(forKey: termID)
            } else if termID.role == .resource {
                for resourceTerm in terms where resourceTerm.role == .resource {
                    resourceTerms.append(resourceTerm)
                }
            } else {
                // For any other term with a pathname URI
                if
                    let scopes = termID.uri.pathname?.components.dropLast(),
                    !scopes.isEmpty // That has two or more components (e.g., Math/pi)
                {
                    // For each of the terms identified by the ancestor path (e.g., Math)
                    let ancestorTerms = allTermsByURI[.id(Term.SemanticURI.Pathname(scopes.map { String($0) }))] ?? []
                    
                    let dictionaries: [TermDictionary] = ancestorTerms.map {
                        $0.makeDictionary(under: pool)
                    }
                    
                    // Add the nested terms to the appropriate dictionary.
                    for dictionary in dictionaries {
                        dictionary.add(terms)
                    }
                    if !dictionaries.isEmpty {
                        // Remove from base dictionary. The term may still be
                        // accessible from the base through dictionary exporting,
                        // but it should not be redefined in it.
                        resultTerms.removeValue(forKey: termID)
                    }
                }
            }
        }
        
        // Make defined terms available to imported resource terminology.
        for (_, terms) in allTerms {
            pool.add(terms)
        }
        
        for resourceTerm in resourceTerms {
            try? resourceTerm.loadResourceTerminology(under: pool)
        }
        
        return resultTerms.values.reduce(into: Set()) { set, terms in set.formUnion(terms) }
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
        switch self {
        case .invalidSyntax:
            return "The file contains malformed YAML syntax."
        case .noOuterMapping:
            return "File does not start with a 'translation:' mapping."
        case .missingFormat:
            return "The 'translation' mapping has no 'format:' key. This required field is used to confirm that the file format is readable by this BushelScript version."
        case .missingLanguage:
            return "The 'translation' mapping has no 'language' key. This required field declares what language module the translation applies to."
        case .invalidFormat:
            return "The file's declared format is unrecognized. The file is malformed or written for a later version of BushelScript."
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
    }
    
}
