import SDEFinitely
import os

private let log = OSLog(subsystem: logSubsystem, category: #fileID)

/// SDEF data containing the contents of the scripting definition at `url`,
/// or `nil` if there is no scripting definition at `url`.
///
/// `url` must have scheme `file` or `eppc`, and identify one of:
///   - An SDEF file
///   - An application bundle that contains one or more of an SDEF,
///     a Cocoa Scripting plist pair, or a classic `aete` resource
///
/// Maintains a cache, so external changes to previously read URLs may be
/// ignored.
///
/// - Throws: `SDEFError` if the data cannot be read for any reason.
public func readSDEF(from url: URL) throws -> Data? {
    do {
        return try sdefCache.cached(for: url, orElse: {
            try SDEFinitely.readSDEF(from: url)
        }) as Data
    } catch is NoSDEF {
        return nil
    }
}

private var sdefCache = Cache<URL, Data>()

class Cache<Key, Value> where Key: Hashable {
    
    private let accessQueue = DispatchQueue(label: "Cache access")
    private var cache: [Key : Value] = [:]
    
    func cached(for key: Key, orElse action: () throws -> Value) rethrows -> Value {
        try accessQueue.sync {
            cache[key]
        } ?? {
            let value = try action()
            accessQueue.sync {
                cache[key] = value
            }
            return value
        }()
    }
    func cached(for key: Key, orElse action: () throws -> Value?) rethrows -> Value? {
        try accessQueue.sync {
            cache[key]
        } ?? {
            let value = try action()
            if let value = value {
                accessQueue.sync {
                    cache[key] = value
                }
            }
            return value
        }()
    }
    
}

/// Parses and returns terms from SDEF data `sdef`,
/// adding subtyping information to `typeTree`.
///
/// SDEF data can be obtained from `readSDEF(from:)`.
///
/// - Throws: `SDEFError` if the data cannot be parsed for any reason.
public func parse(sdef: Data, typeTree: TypeTree) throws -> [Term] {
    let delegate = SetOfTermSDEFParserDelegate()
    try SDEFParser(delegate: delegate).parse(sdef)
    
    for (type, supertypeName) in delegate.inheritedClassTypes {
        if let supertype = delegate.nameToClassType[supertypeName] {
            typeTree.add(type.uri, supertype: supertype.uri)
        } else {
            os_log("No class type found for supertype name ‘%{public}@’, ignoring", log: log, "\(supertypeName)")
        }
    }
    
    return delegate.terms
}

private class SetOfTermSDEFParserDelegate: SDEFParserDelegate {
    
    var terms: [Term] = []
    var nameToClassType: [Term.Name : Term] = [:]
    var inheritedClassTypes: [(type: Term, supertypeName: Term.Name)] = []
    
    private func add(_ term: Term) {
        terms.append(term)
    }
    
    func addType(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4(.type, term))
    }
    func addClass(_ term: SDEFinitely.ClassTerm) {
        let classType = convertAE4(.type, term)
        add(classType)
        if let name = classType.name {
            nameToClassType[name] = classType
        }
        if let supertypeName = term.inheritsFromName {
            inheritedClassTypes.append((type: classType, supertypeName: Term.Name(supertypeName)))
        }
    }
    func addProperty(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4(.property, term))
    }
    func addEnumerator(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4(.constant, term))
    }
    func addCommand(_ term: SDEFinitely.CommandTerm) {
        add(Term(
            .command,
            .ae8(class: term.eventClass, id: term.eventID),
            name: Term.Name(term.name),
            dictionary: TermDictionary(contents: term.parameters.map { convertAE4(.parameter, $0) })
        ))
    }
    
    private func convertAE4(_ role: Term.SyntacticRole, _ term: SDEFinitely.KeywordTermProtocol) -> Term {
        Term(role, .ae4(code: term.code), name: Term.Name(term.name))
    }
    
}
