import os

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

extension TermDictionary {
    
    /// Loads the scripting definition at `url` into the dictionary.
    ///
    /// `url` must have scheme `file` or `eppc`, and identify one of:
    ///   - A BushelScript file
    ///   - An SDEF file
    ///   - An application bundle that contains one or more of an SDEF,
    ///     a Cocoa Scripting plist pair, or a classic `aete` resource
    ///
    /// Maintains a cache, so external changes to previously read URLs may be
    /// ignored.
    ///
    /// - Throws:
    ///   - `ParseError` if `url` refers to an ill-formed BushelScript file.
    ///   - `SDEFError` if `url` refers to an ill-formed SDEF file or
    ///                 an app bundle with an ill-formed terminology definition.
    public func load(from url: URL, typeTree: TypeTree) throws {
        if let dictionary = try dictionaryCache.cached(for: url, orElse: {
            if url.pathExtension == "bushel" {
                return try parse(from: url).rootTerm.dictionary
            } else {
                guard let sdef = try readSDEF(from: url) else {
                    return nil
                }
                var terms = try parse(sdef: sdef, typeTree: typeTree)
                // Don't import terms that shadow "set" or "get":
                terms.removeAll { term in
                    [Commands.get, Commands.set]
                        .map { Term.ID($0) }
                        .contains(term.id)
                }
                return TermDictionary(contents: terms)
            }
        }) {
            merge(dictionary)
        }
    }
    
}

private var dictionaryCache = Cache<URL, TermDictionary>()
