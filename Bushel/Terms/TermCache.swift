import os

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

/// An in-memory cache for dictionaries loaded from external sources.
public class TermDictionaryCache {
    
    public init(termDocs: Ref<Set<TermDoc>>, typeTree: TypeTree) {
        self.termDocs = termDocs
        self.typeTree = typeTree
    }
    
    private var termDocs: Ref<Set<TermDoc>>
    private var typeTree: TypeTree
    
    /// Loads the scripting definition at `url` into `dictionary`.
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
    public func load(from url: URL, into dictionary: TermDictionary) throws {
        if let loaded = try load(from: url) {
            dictionary.merge(loaded)
        }
    }
    
    /// If there is a cached dictionary for `url`, returns it.
    /// Otherwise, loads, caches and returns the scripting definition at `url`
    /// as a `TermDictionary`, if one exists.
    ///
    /// `url` must have scheme `file` or `eppc`, and identify one of:
    ///   - A BushelScript file
    ///   - An SDEF file
    ///   - An application bundle that contains one or more of an SDEF,
    ///     a Cocoa Scripting plist pair, or a classic `aete` resource
    ///
    /// - Throws:
    ///   - `ParseError` if `url` refers to an ill-formed BushelScript file.
    ///   - `SDEFError` if `url` refers to an ill-formed SDEF file or
    ///                 an app bundle with an ill-formed terminology definition.
    public func load(from url: URL) throws -> TermDictionary? {
        try cached(for: url) ?? loadIgnoringCache(from: url)
    }
    
    /// Loads, caches and returns the scripting definition at `url` as a
    /// `TermDictionary`.
    /// If there is no scripting definition at `url`, returns `nil`.
    ///
    /// This method always gets the data from the resource at `url`, regardless
    /// of whether it was already cached. The result is then added to the cache.
    ///
    /// `url` must have scheme `file` or `eppc`, and identify one of:
    ///   - A BushelScript file
    ///   - An SDEF file
    ///   - An application bundle that contains one or more of an SDEF,
    ///     a Cocoa Scripting plist pair, or a classic `aete` resource
    ///
    /// - Throws:
    ///   - `ParseError` if `url` refers to an ill-formed BushelScript file.
    ///   - `SDEFError` if `url` refers to an ill-formed SDEF file or
    ///                 an app bundle with an ill-formed terminology definition.
    public func loadIgnoringCache(from url: URL) throws -> TermDictionary? {
        if url.pathExtension == "bushel" {
            let program = try parse(from: url)
            let dictionary = program.rootTerm.dictionary
            dictionaryCache[url] = dictionary
            termDocs.value.formUnion(program.termDocs.value)
            return dictionary
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
            let dictionary = TermDictionary(contents: terms)
            dictionaryCache[url] = dictionary
            return dictionary
        }
    }
    
    /// The cached dictionary for `url`, if there is one.
    public func cached(for url: URL) -> TermDictionary? {
        dictionaryCache[url]
    }
    
    /// Deletes all cached dictionaries and docs.
    public func clearCache() {
        dictionaryCache.clear()
    }
    
    private var dictionaryCache = Cache<URL, TermDictionary>()
    
}
