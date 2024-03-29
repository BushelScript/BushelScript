import Regex

private var defaultLanguageID = "bushelscript_en"

public var globalTermDocs = Ref([Term.ID : TermDoc]())
public var globalTypeTree: TypeTree = {
    let tree = TypeTree(rootType: Term.SemanticURI(Types.item))
    tree.add(Term.SemanticURI(Types.integer), supertype: Term.SemanticURI(Types.number))
    tree.add(Term.SemanticURI(Types.real), supertype: Term.SemanticURI(Types.number))
    return tree
}()
public var globalCache = BushelCache(
    dictionaryCache: TermDictionaryCache(
        termDocs: globalTermDocs,
        typeTree: globalTypeTree
    ),
    resourceCache: ResourceCache()
)

public func parse(from url: URL, ignoringImports: Set<URL> = []) throws -> Program {
    try parse(source: String(contentsOf: url), ignoringImports: ignoringImports.union([url]))
}

public func parse(source: String, at url: URL) throws -> Program {
    try parse(source: source, ignoringImports: [url])
}

public func parse(source: String, languageID: String? = nil, ignoringImports: Set<URL> = []) throws -> Program {
    var source = source
    let languageID = LanguageModule.takeLanguageFromHashbang(&source) ?? languageID ?? defaultLanguageID
    return try LanguageModule(identifier: languageID).parser().parse(source: source, ignoringImports: ignoringImports)
}

extension LanguageModule {
    
    public static func takeLanguageFromHashbang(_ source: inout String) -> String? {
        var firstLine = source.prefix(while: { !$0.isNewline })
        firstLine.removeLeadingWhitespace()
        guard firstLine.hasPrefix("#!") else {
            return nil
        }
        
        let hashbang = String(firstLine)
        
        var languageID: String?
        if
            let match = Regex("-l\\s*(\\w+)").firstMatch(in: hashbang),
            let matchedLanguage = match.captures[0]
        {
            languageID = matchedLanguage
        }
        
        source = String(
            source[hashbang.endIndex...]
            .drop(while: { $0.isNewline })
        )
        return languageID
    }
    
}
