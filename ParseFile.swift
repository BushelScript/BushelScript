import Regex

private var defaultLanguageID = "bushelscript_en"

func parse(from url: URL) throws -> Program {
    try parse(source: String(contentsOf: url), at: url)
}

func parse(source: String, at url: URL?) throws -> Program {
    var source = source
    let languageID = eatHashbang(from: &source) ?? defaultLanguageID
    
    guard let languageModule = LanguageModule(identifier: languageID) else {
        throw NoSuchLanguageModule(languageID: languageID)
    }
    return try languageModule.parser().parse(source: source, at: url)
}

private func eatHashbang(from source: inout String) -> String? {
    var firstLine = source.prefix(while: { !$0.isNewline })
    firstLine.removeLeadingWhitespace()
    guard firstLine.hasPrefix("#!") else {
        return nil
    }
    
    let hashbang = String(firstLine)
    
    var languageID = defaultLanguageID
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

public struct NoSuchLanguageModule: LocalizedError {
    
    public var languageID: String
    
    public var errorDescription: String? {
        "No valid language module with ID \(languageID) found"
    }
    
}
