import Foundation
import SDEFinitely

public class TermDictionary: TerminologySource, CustomStringConvertible {
    
    private(set) public var pool: TermPool
    
    public var name: TermName?
    public let exports: Bool
    
    private var contentsByUID: [String : Term]
    private var contentsByName: [TermName : Term]
    
    public var includedDictionary: TermDictionary?
    
    internal init(pool: TermPool, name: TermName?, exports: Bool, contents: [Term] = [], including included: TermDictionary? = nil) {
        self.pool = pool
        self.name = name
        self.exports = exports
        self.contentsByUID = Dictionary(uniqueKeysWithValues: contents.map { (key: $0.uid, value: $0) })
        self.contentsByName = Dictionary(uniqueKeysWithValues:
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            })
        self.includedDictionary = included
        
        pool.add(contents)
    }
    
    public func term(forUID uid: String) -> Term? {
        contentsByUID[uid] ?? includedDictionary?.term(forUID: uid)
    }
    
    public func term(named name: TermName) -> Term? {
        contentsByName[name] ?? includedDictionary?.term(named: name)
    }
    
    public func add(_ term: Term) {
        contentsByUID[term.uid] = term
        if let name = term.name {
            contentsByName[name] = term
        }
        pool.add(term)
    }
    
    public func add(_ terms: [Term]) {
        contentsByUID.merge(terms.map { (key: $0.uid, value: $0) }, uniquingKeysWith: { $1 })
        contentsByName.merge(
            terms.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: { $1 }
        )
        pool.add(terms)
    }
    
    public func merge(_ dictionary: TermDictionary) {
        contentsByUID.merge(dictionary.contentsByUID, uniquingKeysWith: { $1 })
        contentsByName.merge(dictionary.contentsByName, uniquingKeysWith: { $1 })
        pool.add(Array(dictionary.contentsByName.values))
    }
    
    public var description: String {
        return "[TermDictionary ‘\(name?.normalized ?? "(unnamed)")’:\n\t\(contentsByName)\n]"
    }
    
}

public class ParameterTermDictionary: TerminologySource {
    
    private var contentsByUID: [String : ParameterTerm]
    private var contentsByName: [TermName : ParameterTerm]
    
    public init(contents: Set<ParameterTerm> = []) {
        self.contentsByUID = Dictionary(uniqueKeysWithValues: contents.map { (key: $0.uid, value: $0) })
        self.contentsByName = Dictionary(uniqueKeysWithValues:
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            })
    }
    
    public func term(forUID uid: String) -> ParameterTerm? {
        return contentsByUID[uid]
    }
    
    public func term(named name: TermName) -> ParameterTerm? {
        return contentsByName[name]
    }
    
    public func add(_ term: ParameterTerm) {
        contentsByUID[term.uid] = term
        if let name = term.name {
            contentsByName[name] = term
        }
    }
    
}

extension TermDictionary: Hashable {
    
    public static func == (lhs: TermDictionary, rhs: TermDictionary) -> Bool {
        return lhs.name == rhs.name && lhs.contentsByName == rhs.contentsByName
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(contentsByName)
    }
    
}

public func parse(sdef: Data, under lexicon: Lexicon) throws -> [Term] {
    let delegate = SetOfTermSDEFParserDelegate(lexicon)
    try SDEFParser(delegate: delegate).parse(sdef)
    return delegate.terms
}

private class SetOfTermSDEFParserDelegate: SDEFParserDelegate {
    
    var lexicon: Lexicon
    
    init(_ lexicon: Lexicon) {
        self.lexicon = lexicon
    }
    
    var terms: [Term] = []
    
    func addType(_ term: SDEFinitely.KeywordTerm) {
        add(ClassTerm(lexicon.makeUID("type", term.termName), name: term.termName, code: term.code, parentClass: (lexicon.pool.term(forID: TypeUID.item.rawValue) as! ClassTerm)))
    }
    func addClass(_ term: SDEFinitely.ClassTerm) {
        add(ClassTerm(lexicon.makeUID("type", term.termName), name: term.termName, code: term.code, parentClass: (lexicon.pool.term(forID: TypeUID.item.rawValue) as! ClassTerm)))
    }
    func addProperty(_ term: SDEFinitely.KeywordTerm) {
        add(PropertyTerm(lexicon.makeUID("property", term.termName), name: TermName(term.name), code: term.code))
    }
    func addEnumerator(_ term: SDEFinitely.KeywordTerm) {
        add(EnumeratorTerm(lexicon.makeUID("constant", term.termName), name: TermName(term.name), code: term.code))
    }
    func addCommand(_ term: SDEFinitely.CommandTerm) {
        add(
            CommandTerm(lexicon.makeUID("command", term.termName),
            name: TermName(term.name),
            codes: (class: term.eventClass,
                    id: term.eventID),
            parameters: ParameterTermDictionary(contents:
                Set(term.parameters.map { convertParameterTerm($0, term) }))
            )
        )
    }
    
    private func convertParameterTerm(_ parameterTerm: SDEFinitely.KeywordTerm, _ commandTerm: SDEFinitely.CommandTerm) -> ParameterTerm {
        return ParameterTerm(lexicon.makeUID("parameter", commandTerm.termName, parameterTerm.termName), name: TermName(parameterTerm.name), code: parameterTerm.code)
    }
    
    private func add(_ term: Term) {
        terms.append(term)
    }
    
}

private extension SDEFinitely.TermProtocol {
    
    var termName: TermName {
        TermName(name)
    }
    
}
