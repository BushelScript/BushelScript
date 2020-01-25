import Foundation
import SDEFinitely

public class TermDictionary: TerminologySource, CustomDebugStringConvertible {
    
    private(set) public var pool: TermPool
    
    public var name: TermName?
    public let exports: Bool
    
    private var contentsByUID: [TypedTermUID : Term]
    private var contentsByName: [TermName : Term]
    
    private(set) public var dictionaryContainers: [TermName : TermDictionaryContainer] = [:]
    private(set) public var exportingDictionaryContainers: [TermName : TermDictionaryContainer] = [:]
    
    public init(pool: TermPool, name: TermName?, exports: Bool, contents: [Term] = []) {
        self.pool = pool
        self.name = name
        self.exports = exports
        self.contentsByUID = Dictionary(uniqueKeysWithValues: contents.map { (key: $0.typedUID, value: $0) })
        self.contentsByName = Dictionary(uniqueKeysWithValues:
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            })
        
        catalogueDictionaryContainers(in: contents)
        
        pool.add(contents)
    }
    
    public init(merging new: TermDictionary, into old: TermDictionary) {
        self.pool = new.pool
        self.name = new.name
        self.exports = new.exports
        self.contentsByUID = new.contentsByUID.merging(old.contentsByUID, uniquingKeysWith: TermDictionary.whichTermWins)
        self.contentsByName = new.contentsByName.merging(old.contentsByName, uniquingKeysWith: TermDictionary.whichTermWins)
        self.dictionaryContainers = new.dictionaryContainers.merging(old.dictionaryContainers, uniquingKeysWith: { $1 })
        self.exportingDictionaryContainers = new.exportingDictionaryContainers.merging(old.exportingDictionaryContainers, uniquingKeysWith: { $1 })
    }
    
    public func term(forUID uid: TypedTermUID) -> Term? {
        contentsByUID[uid]
    }
    
    public func term(named name: TermName) -> Term? {
        contentsByName[name]
    }
    
    public func add(_ term: Term) {
        contentsByUID[term.typedUID] = term
        if let name = term.name {
            contentsByName[name] = term
        }
        catalogueDictionaryContainers(in: [term])
        pool.add(term)
    }
    
    public func add(_ terms: [Term]) {
        contentsByUID.merge(terms.map { (key: $0.typedUID, value: $0) }, uniquingKeysWith: TermDictionary.whichTermWins)
        contentsByName.merge(
            terms.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: TermDictionary.whichTermWins
        )
        catalogueDictionaryContainers(in: terms)
        pool.add(terms)
    }
    
    public func merge(_ dictionary: TermDictionary) {
        contentsByUID.merge(dictionary.contentsByUID, uniquingKeysWith: TermDictionary.whichTermWins)
        contentsByName.merge(dictionary.contentsByName, uniquingKeysWith: TermDictionary.whichTermWins)
        catalogueDictionaryContainers(in: dictionary.contentsByUID.values)
        pool.add(Array(dictionary.contentsByUID.values))
    }
    
    private func catalogueDictionaryContainers<Terms: Collection>(in terms: Terms) where Terms.Element == Term {
        for case let containerTerm as TermDictionaryContainer in terms {
            if
                let dictionary = containerTerm.terminology,
                let dictionaryName = containerTerm.terminology?.name
            {
                dictionaryContainers[dictionaryName] = containerTerm
                if dictionary.exports {
                    exportingDictionaryContainers[dictionaryName] = containerTerm
                }
            }
        }
    }
    
    private static func whichTermWins(_ old: Term, _ new: Term) -> Term {
        // For compatibility.
        // e.g., AppleScript sees Xcode : project as a class whilst ignoring the identically named property term.
        if case .class_ = old.enumerated, case .property = new.enumerated {
            return old
        }
        return new
    }
    
    public var debugDescription: String {
        return "[TermDictionary ‘\(name?.normalized ?? "(unnamed)")’:\n\t\(contentsByUID)\n]"
    }
    
}

public class ParameterTermDictionary: TerminologySource {
    
    private var contentsByUID: [TypedTermUID : ParameterTerm]
    private var contentsByName: [TermName : ParameterTerm]
    
    public init(contents: [ParameterTerm] = []) {
        self.contentsByUID = Dictionary(contents.map { (key: $0.typedUID, value: $0) }, uniquingKeysWith: { x, _ in x })
        self.contentsByName = Dictionary(
            contents.compactMap { term in
                term.name.flatMap { (key: $0, value: term) }
            },
            uniquingKeysWith: { x, _ in x }
        )
    }
    
    public func term(forUID uid: TypedTermUID) -> ParameterTerm? {
        return contentsByUID[uid]
    }
    
    public func term(named name: TermName) -> ParameterTerm? {
        return contentsByName[name]
    }
    
    public func add(_ term: ParameterTerm) {
        contentsByUID[term.typedUID] = term
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
        add(ClassTerm(.ae4(code: term.code), name: term.termName, parentClass: (lexicon.pool.term(forUID: TypedTermUID(TypeUID.item)) as! ClassTerm)))
    }
    func addClass(_ term: SDEFinitely.ClassTerm) {
        let classTerm = ClassTerm(.ae4(code: term.code), name: term.termName, parentClass: (lexicon.pool.term(forUID: TypedTermUID(TypeUID.item)) as! ClassTerm))
        add(classTerm)
        add(PluralClassTerm(singularClass: classTerm, name: term.pluralTermName))
    }
    func addProperty(_ term: SDEFinitely.KeywordTerm) {
        add(PropertyTerm(.ae4(code: term.code), name: TermName(term.name)))
    }
    func addEnumerator(_ term: SDEFinitely.KeywordTerm) {
        add(EnumeratorTerm(.ae4(code: term.code), name: TermName(term.name)))
    }
    func addCommand(_ term: SDEFinitely.CommandTerm) {
        add(
            CommandTerm(.ae8(class: term.eventClass, id: term.eventID),
            name: TermName(term.name),
            parameters: ParameterTermDictionary(contents: term.parameters.map { convertParameterTerm($0, term) })
            )
        )
    }
    
    private func convertParameterTerm(_ parameterTerm: SDEFinitely.KeywordTerm, _ commandTerm: SDEFinitely.CommandTerm) -> ParameterTerm {
        return ParameterTerm(.ae4(code: parameterTerm.code), name: TermName(parameterTerm.name))
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

private extension SDEFinitely.ClassTerm {
    
    var pluralTermName: TermName {
        TermName(pluralName)
    }
    
}
