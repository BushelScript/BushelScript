import Bushel
import os
import Yams

private let log = OSLog(subsystem: logSubsystem, category: "Translations")

/// A collection of name mappings for term UIDs.
///
/// Can be constructed from the contents of a YAML-based translation file.
public struct Translation {
    
    public enum ParseError: Error {
        case invalidSyntax
        case noOuterMapping
        case missingFormat
        case missingLanguage
        case invalidFormat
        case invalidTermKind
        case invalidUIDDomainMapping
        case invalidUIDDomain
        case invalidUIDDataMapping
        case invalidUIDData
    }
    
    public var format: String
    public var language: String
    public var mappings: [TypedTermUID : Set<TermName>] = [:]
    
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
        guard self.format == "0.1" else {
            throw ParseError.invalidFormat
        }
        
        guard case .mapping(let mappings) = translation["mappings"] else {
            return
        }
        for (termKind, uidDomainMapping) in mappings {
            guard
                case .scalar(let termKindScalar) = termKind,
                let termKind = TypedTermUID.Kind(rawValue: termKindScalar.string)
            else {
                throw ParseError.invalidTermKind
            }
            guard case .mapping(let uidDomainMapping) = uidDomainMapping else {
                throw ParseError.invalidUIDDomainMapping
            }
            for (uidDomain, uidDataMapping) in uidDomainMapping {
                guard
                    case .scalar(let uidDomainScalar) = uidDomain,
                    let uidDomain = TermUIDDomain(rawValue: uidDomainScalar.string)
                else {
                    throw ParseError.invalidUIDDomain
                }
                guard case .mapping(let uidDataMapping) = uidDataMapping else {
                    throw ParseError.invalidUIDDataMapping
                }
                for (uidData, valueNode) in uidDataMapping {
                    guard case .scalar(let uidDataScalar) = uidData else {
                        throw ParseError.invalidUIDData
                    }
                    let uidsAndValueNodes: [(TermUID, Yams.Node)] = try {
                        switch uidDomain {
                        case .id:
                            // Requires special handling to support nesting
                            enum ScopeNode {
                                case leaf(name: TermName, node: Yams.Node)
                                case branch([(name: TermName, node: ScopeNode)])
                            }
                            func process(uidDataName: TermName, valueNode: Yams.Node) throws -> ScopeNode {
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
                                                throw ParseError.invalidUIDData
                                            }
                                            let nestedUIDDataName = TermName(uidDataNodeScalar.string)
                                            return (
                                                name: uidDataName,
                                                node: try process(uidDataName: nestedUIDDataName, valueNode: nestedDataNode)
                                            )
                                        }
                                    )
                                }
                            }
                            let scopeNode = try process(uidDataName: TermName(uidDataScalar.string), valueNode: valueNode)
                            var namesAndNodes: [(name: String, node: Yams.Node)] = []
                            func traverse(scopeNode: ScopeNode, under currentScopeNames: [TermName]) {
                                switch scopeNode {
                                case .leaf(let name, let node):
                                    namesAndNodes.append((
                                        name:
                                            (currentScopeNames + [name])
                                                .map { $0.normalized }
                                                .joined(separator: ":"),
                                        node: node
                                    ))
                                case .branch(let namesAndNodes):
                                    for (name, node) in namesAndNodes {
                                        traverse(scopeNode: node, under: currentScopeNames + [name])
                                    }
                                }
                            }
                            traverse(scopeNode: scopeNode, under: [])
                            return namesAndNodes.map { (TermUID.id($0.name), $0.node) }
                        default:
                            guard let uid = TermUID(kind: uidDomain.rawValue, data: uidDataScalar.string) else {
                                throw ParseError.invalidUIDData
                            }
                            return [(uid, valueNode)]
                        }
                    }()
                    for (uid, valueNode) in uidsAndValueNodes {
                        func process(valueNode: Yams.Node, typedUID: TypedTermUID) {
                            switch valueNode {
                            case .scalar(let termNameScalar):
                                addMapping(typedUID: typedUID, termName: TermName(termNameScalar.string))
                            case .mapping(let variantsMapping):
                                for (variantName, termName) in variantsMapping {
                                    guard case .scalar(let variantNameScalar) = variantName else {
                                        // Ignore non-scalar variant names (allow for future extension)
                                        continue
                                    }
                                    guard let uid: TermUID = {
                                            switch variantNameScalar.string {
                                            case "/standard":
                                                return uid
                                            case "/plural":
                                                return .variant(.plural, uid)
                                            default:
                                                return nil
                                            }
                                        }()
                                    else {
                                        // Ignore unknown variant names (allow for future extension)
                                        continue
                                    }
                                    let typedUID = TypedTermUID(termKind, uid)
                                    process(valueNode: termName, typedUID: typedUID)
                                }
                            case .sequence(let synonymsSequence):
                                for synonym in synonymsSequence {
                                    process(valueNode: synonym, typedUID: typedUID)
                                }
                            }
                        }
                        
                        let typedUID = TypedTermUID(termKind, uid)
                        process(valueNode: valueNode, typedUID: typedUID)
                    }
                }
            }
        }
        
        // TODO: Move functionality to language modules to allow for custom
        //       (i.e., non-English) automatic pluralizations.
        func addPluralVariant(for typedUID: TypedTermUID, termNames: Set<TermName>) {
            if
                case .variant(let variant, _) = typedUID.uid,
                case .plural = variant
            {
                // Already an explicitly plural term
                return
            }
            let pluralVariantTypedUID = TypedTermUID(typedUID.kind, .variant(.plural, typedUID.uid))
            guard !self.mappings.keys.contains(pluralVariantTypedUID) else {
                // Already has pluralizations defined
                return
            }
            let pluralNames = Set(termNames.map { TermName($0.normalized + "s") })
            self.mappings[pluralVariantTypedUID] = pluralNames
        }
        for (typedUID, termNames) in self.mappings where typedUID.kind == .type {
            addPluralVariant(for: typedUID, termNames: termNames)
        }
    }
    
    private mutating func addMapping(typedUID: TypedTermUID, termName: TermName) {
        if self.mappings[typedUID] == nil {
            self.mappings[typedUID] = []
        }
        self.mappings[typedUID]!.insert(termName)
    }
    
    public subscript(_ typedUID: TypedTermUID) -> Set<TermName> {
        mappings[typedUID] ?? []
    }
    public subscript(_ typedUID: TypedTermUID) -> TermName? {
        mappings[typedUID]?.first
    }
    
    public func makeTerms(under pool: TermPool) -> Set<Term> {
        let termPairs: [(TypedTermUID, [Term])] = mappings.map { kv in
            let (typedTermUID, termNames) = kv
            return (typedTermUID, termNames.compactMap { termName in
                Term.make(for: typedTermUID, name: termName)
            })
        }
        let allTerms = [TypedTermUID : [Term]](uniqueKeysWithValues: termPairs)
        let allTermsByUntypedIndex = [TermUID : [Term]](allTerms.map { (key: $0.key.uid, value: $0.value) }, uniquingKeysWith: {
            (left: [Term], right: [Term]) -> [Term] in
            TypedTermUID.Kind.allCases.firstIndex(of: left.first!.typedUID.kind)! < TypedTermUID.Kind.allCases.firstIndex(of: right.first!.typedUID.kind)! ? right : left
        })
        var resultTerms = allTerms
        for (typedTermUID, terms) in allTerms {
            if typedTermUID.kind == .parameter {
                for case .parameter(let parameterTerm) in terms.map({ $0.enumerated }) {
                    if
                        let commandUID = parameterTerm.uid.commandUIDFromParameterUID,
                        let commandTerms = allTerms[TypedTermUID(.command, commandUID)] as? [CommandTerm]
                    {
                        for commandTerm in commandTerms {
                            commandTerm.parameters.add(parameterTerm)
                        }
                    }
                }
                resultTerms.removeValue(forKey: typedTermUID)
            } else /* For any non-parameter id term */ {
                if
                    let scopes = typedTermUID.uid.idNameScopes?.dropLast(),
                    !scopes.isEmpty // That has two or more scope components (e.g., Math:pi)
                {
                    // If the term type referred to by the scopes (e.g., Math) holds a dictionary
                    if let containerTerms = allTermsByUntypedIndex[.id(scopes.joined(separator: ":"))] as? [TermDictionaryContainer] {
                        let dictionaries: [TermDictionary] = containerTerms.compactMap({ containerTerm in
                            containerTerm.terminology ??
                                (containerTerm as? TermDictionaryDelayedInitContainer)?.makeDictionary(under: pool)
                        })
                        // Add the nested terms to the appropriate dictionary.
                        for dictionary in dictionaries {
                            dictionary.add(terms)
                        }
                        if !dictionaries.isEmpty {
                            // Remove from base dictionary. The term may still be
                            // accessible from the base through dictionary exporting,
                            // but it should not be redefined in it.
                            resultTerms.removeValue(forKey: typedTermUID)
                        }
                    }
                }
            }
        }
        return resultTerms.values.reduce(into: Set()) { set, terms in set.formUnion(terms) }
    }
    
}

/// List of term UID domains the translation file parser understands.
private enum TermUIDDomain: String, CaseIterable {
    
    /// Uses simple key-value mappings.
    case ae4, ae8, ae12
    /// Allows nesting for easy and DRY scoping.
    case id
    
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
        case .invalidTermKind:
            return "An unrecognized term kind was found. Valid values are: \(TypedTermUID.Kind.allCases.map { $0.rawValue }.joined(separator: ", "))."
        case .invalidUIDDomainMapping:
            return "Expected a mapping as the value for a term kind, but found a scalar or sequence instead."
        case .invalidUIDDomain:
            return "An unrecognized UID domain was found. Valid values are: \(TermUIDDomain.allCases.map { $0.rawValue }.joined(separator: ", "))"
        case .invalidUIDDataMapping:
            return "Expected a mapping as the value for a UID domain, but found a scalar or sequence instead."
        case .invalidUIDData:
            return "Encountered invalid data for a UID domain. For example, the 'ae4' domain expects a four-character ASCII string."
        }
    }
    
}
