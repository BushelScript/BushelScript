import Foundation

public protocol NamedTerm: PrettyPrintable {
    
    var name: TermName? { get }
    var displayName: String { get }
    
}

public protocol FCCCodedTerm {
    
    var code: OSType? { get }
    
}

public /*abstract*/ class Term: NamedTerm, Comparable, Hashable {
    
    public let uid: String
    public let name: TermName?
    
    // Swift is *sorely* in need of abstract classes… 😫
    public var enumerated: TermKind {
        fatalError("abstract method called")
    }
    
    public var displayName: String {
        name?.normalized ?? uid
    }
    
    public init(_ uid: String, name: TermName?) {
        self.uid = uid
        self.name = name
    }
    
    public static func < (lhs: Term, rhs: Term) -> Bool {
        return lhs.uid < rhs.uid
    }
    
    public static func == (lhs: Term, rhs: Term) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
}

public /*abstract*/ class ConstantTerm: Term, FCCCodedTerm, CustomStringConvertible {
    
    public var code: OSType?
    
    public required init(_ uid: String, name: TermName?, code: OSType?) {
        self.code = code
        super.init(uid, name: name)
    }
    
    public override var displayName: String {
        name?.normalized ?? description
    }
    
    public var description: String {
        fatalError("abstract method called")
    }
    
}

private extension ConstantTerm {
    
    func describe(tag: String) -> String {
        if !(name?.words.isEmpty ?? true) {
            return String(describing: name)
        } else if let code = code {
            return "«\(tag) \(String(fourCharCode: code))»"
        } else {
            return "«\(tag)»"
        }
    }
    
}

public final class EnumeratorTerm: ConstantTerm {
    
    public override var enumerated: TermKind {
        return .enumerator(self)
    }
    
    public override var description: String {
        describe(tag: "constant")
    }
    
}

public final class DictionaryTerm: Term, TermDictionaryContainer {
    
    public override var enumerated: TermKind {
        return .dictionary(self)
    }
    
    public var dictionary: TermDictionary
    
    public var terminology: TermDictionary? {
        return dictionary
    }
    
    public init(_ uid: String, name: TermName?, terminology: TermDictionary) {
        self.dictionary = terminology
        super.init(uid, name: name)
    }
    
}

public final class ClassTerm: ConstantTerm, TermDictionaryDelayedInitContainer {
    
    public override var enumerated: TermKind {
        return .class_(self)
    }
    
    public var terminology: TermDictionary? = nil {
        didSet {
            if
                let myTerminology = terminology,
                let parentTerminology = parentClass?.terminology
            {
                terminology = TermDictionary(merging: parentTerminology, into: myTerminology)
            }
        }
    }
    public var exportsTerminology: Bool {
        true
    }
    
    public var parentClass: ClassTerm?
    
    public init(_ uid: String, name: TermName?, code: OSType?, parentClass: ClassTerm?) {
        self.parentClass = parentClass
        super.init(uid, name: name, code: code)
    }
    
    public required convenience init(_ uid: String, name: TermName?, code: OSType?) {
        self.init(uid, name: name, code: code, parentClass: nil)
    }
    
    public func isA(_ other: ClassTerm) -> Bool {
        var classTerm = self
        while true {
            if classTerm == other {
                return true
            }
            guard let parent = classTerm.parentClass else {
                return false
            }
            classTerm = parent
        }
    }
    
    public override var description: String {
        describe(tag: "class")
    }
    
}

public final class PropertyTerm: ConstantTerm {
    
    public override var enumerated: TermKind {
        return .property(self)
    }
    
    public required init(_ uid: String, name: TermName?, code: OSType? = nil) {
        super.init(uid, name: name, code: code)
    }
    
    public override var description: String {
        describe(tag: "property")
    }
    
}

public final class CommandTerm: Term {
    
    public let codes: (class: AEEventClass, id: AEEventID)?
    public var parameters: ParameterTermDictionary
    
    public override var enumerated: TermKind {
        return .command(self)
    }
    
    public init(_ uid: String, name: TermName?, codes: (class: AEEventClass, id: AEEventID)?, parameters: ParameterTermDictionary) {
        self.codes = codes
        self.parameters = parameters
        super.init(uid, name: name)
    }
    
    public override var displayName: String {
        name?.normalized ?? describe()
    }
    
    private func describe() -> String {
        if !(name?.words.isEmpty ?? true) {
            return String(describing: name)
        } else if let (classCode, idCode) = codes {
            return "«command \(String(fourCharCode: classCode))\(String(fourCharCode: idCode))»"
        } else {
            return "«command»"
        }
    }
    
}

public final class ParameterTerm: ConstantTerm {
    
    public override var enumerated: TermKind {
        return .parameter(self)
    }
    
    public override var description: String {
        describe(tag: "parameter")
    }
    
}

public final class VariableTerm: Term {
    
    public override var enumerated: TermKind {
        return .variable(self)
    }
    
}

public final class ApplicationNameTerm: Term, TermDictionaryDelayedInitContainer {
    
    public let bundle: Bundle
    
    public var terminology: TermDictionary?
    public var exportsTerminology: Bool {
        true
    }
    
    public override var enumerated: TermKind {
        return .applicationName(self)
    }
    
    public init(_ uid: String, name: TermName, bundle: Bundle) {
        self.bundle = bundle
        super.init(uid, name: name)
    }
    
}

public final class ApplicationIDTerm: Term, TermDictionaryDelayedInitContainer {
    
    public let bundle: Bundle
    
    public var terminology: TermDictionary?
    public var exportsTerminology: Bool {
        true
    }
    
    public override var enumerated: TermKind {
        return .applicationID(self)
    }
    
    public init(_ uid: String, name: TermName, bundle: Bundle) {
        self.bundle = bundle
        super.init(uid, name: name)
    }
    
}

/// An enumeration of all possible kinds of terms.
///
/// This type replaces what otherwise would be a visitor pattern for the
/// `Term` subclasses. Each subclass returns its own case of this enumeration
/// from its `enumerated` property. To "visit" a `Term`'s concrete type,
/// simply `switch` on `term.enumerated`.
public enum TermKind: Hashable {
    
    /// An enumerator, possibly with a four-byte AppleEvent code.
    /// Without a code, the term is treated like a symbol in Ruby.
    case enumerator(EnumeratorTerm)
    /// The name of a dictionary and nothing more.
    /// Terms may be accessed via scoped lookup while its dictionary
    /// is out of the lexicon.
    case dictionary(DictionaryTerm)
    /// A datatype, possibly with a four-byte AppleEvent code.
    /// Contains a (non-exporting) dictionary.
    case class_(ClassTerm)
    /// A property, possibly with a four-byte AppleEvent code.
    case property(PropertyTerm)
    /// A command, possibly with four-byte AppleEvent class and ID codes.
    case command(CommandTerm)
    /// A command parameter, possibly with a four-byte AppleEvent code.
    case parameter(ParameterTerm)
    /// A user-defined variable.
    case variable(VariableTerm)
    /// An application constant specified by name.
    /// Contains an exporting dictionary.
    case applicationName(ApplicationNameTerm)
    /// An application constant specified by bundle ID.
    /// Contains an exporting dictionary.
    case applicationID(ApplicationIDTerm)
    
    /// The parts of this kind of term that are common to all kinds of terms.
    var generalized: Term {
        switch self {
        case .enumerator(let term as Term),
             .dictionary(let term as Term),
             .class_(let term as Term),
             .property(let term as Term),
             .command(let term as Term),
             .parameter(let term as Term),
             .variable(let term as Term),
             .applicationName(let term as Term),
             .applicationID(let term as Term):
            return term
        }
    }
    
}
