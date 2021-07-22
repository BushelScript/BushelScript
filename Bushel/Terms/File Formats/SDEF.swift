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
/// - Throws: `SDEFError` if the data cannot be read for any reason.
func readSDEF(from url: URL) throws -> Data? {
    do {
        return try SDEFinitely.readSDEF(from: url)
    } catch is NoSDEF {
        return nil
    }
}

/// Parses and returns terms from SDEF data `sdef`,
/// adding subtyping information to `typeTree`.
///
/// SDEF data can be obtained from `readSDEF(from:)`.
///
/// - Throws: `SDEFError` if the data cannot be parsed for any reason.
func parse(sdef: Data, typeTree: TypeTree) throws -> ([Term], [TermDoc]) {
    let delegate = SetOfTermSDEFParserDelegate()
    try SDEFParser(delegate: delegate).parse(sdef)
    
    for (type, supertypeName) in delegate.inheritedClassTypes {
        if let supertype = delegate.nameToClassType[supertypeName] {
            typeTree.add(type.uri, supertype: supertype.uri)
        } else {
            os_log("No class type found for supertype name ‘%{public}@’, ignoring", log: log, "\(supertypeName)")
        }
    }
    
    return (delegate.terms, delegate.termDocs)
}

private class SetOfTermSDEFParserDelegate: SDEFParserDelegate {
    
    var terms: [Term] = []
    var termDocs: [TermDoc] = []
    var nameToClassType: [Term.Name : Term] = [:]
    var inheritedClassTypes: [(type: Term, supertypeName: Term.Name)] = []
    
    private func add(_ termDoc: TermDoc) {
        terms.append(termDoc.term)
        termDocs.append(termDoc)
    }
    
    func addType(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4Term(.type, term))
    }
    func addClass(_ term: SDEFinitely.ClassTerm) {
        let classTypeDoc = convertAE4Term(.type, term)
        let classType = classTypeDoc.term
        add(classTypeDoc)
        if let name = classType.name {
            nameToClassType[name] = classType
        }
        if let supertypeName = term.inheritsFromName {
            inheritedClassTypes.append((type: classType, supertypeName: Term.Name(supertypeName)))
        }
    }
    func addProperty(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4Term(.property, term))
    }
    func addEnumerator(_ term: SDEFinitely.KeywordTerm) {
        add(convertAE4Term(.constant, term))
    }
    func addCommand(_ term: SDEFinitely.CommandTerm) {
        add(TermDoc(
            term: Term(
                .command,
                .ae8(class: term.eventClass, id: term.eventID),
                name: Term.Name(term.name),
                dictionary: TermDictionary(contents: term.parameters.map { parameter in
                    let doc = convertAE4Term(.parameter, parameter)
                    termDocs.append(doc)
                    return doc.term
                })
            ),
            doc: term.termDescription ?? ""
        ))
    }
    
    private func convertAE4Term(_ role: Term.SyntacticRole, _ term: SDEFinitely.KeywordTermProtocol) -> TermDoc {
        TermDoc(
            term: Term(role, .ae4(code: term.code),
            name: Term.Name(term.name)),
            doc: term.termDescription ?? ""
        )
    }
    
}
