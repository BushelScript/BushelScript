import Foundation

public protocol NamedTerm: CustomStringConvertible, PrettyPrintable {
    
    var uid: TermUID { get }
    var name: TermName? { get }
    
}

public extension NamedTerm {
    
    var ae4Code: OSType? {
        uid.ae4Code
    }
    
    var ae8Code: (class: AEEventClass, id: AEEventID)? {
        uid.ae8Code
    }
    
    var ae12Code: (class: AEEventClass, id: AEEventID, code: AEKeyword)? {
        uid.ae12Code
    }
    
}

public /*abstract*/ class Term: NamedTerm, Hashable {
    
    public let uid: TermUID
    public let name: TermName?
    
    // Swift is *sorely* in need of abstract classes… 😫
    public class var kind: TypedTermUID.Kind {
        fatalError("abstract method called")
    }
    public var enumerated: TermKind {
        fatalError("abstract method called")
    }
    
    public required init?(_ uid: TermUID, name: TermName?) {
        self.uid = uid
        self.name = name
    }
    
    public static func == (lhs: Term, rhs: Term) -> Bool {
        return lhs.uid == rhs.uid
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
    }
    
    public var description: String {
        if
            let name = name,
            !name.words.isEmpty
        {
            return "\(name)"
        } else {
            return "«\(type(of: self).kind) \(uid)»"
        }
    }
    
    public var typedUID: TypedTermUID {
        TypedTermUID(type(of: self).kind, uid)
    }
    
}

public final class EnumeratorTerm: Term {
    
    public override class var kind: TypedTermUID.Kind {
        .enumerator
    }
    public override var enumerated: TermKind {
        return .enumerator(self)
    }
    
    public required init(_ uid: TermUID, name: TermName?) {
        super.init(uid, name: name)!
    }
    
}

public final class DictionaryTerm: Term, TermDictionaryContainer {
    
    public override class var kind: TypedTermUID.Kind {
        .dictionary
    }
    public override var enumerated: TermKind {
        return .dictionary(self)
    }
    
    public var dictionary: TermDictionary
    
    public var terminology: TermDictionary? {
        return dictionary
    }
    
    public init(_ uid: TermUID, name: TermName?, terminology: TermDictionary) {
        self.dictionary = terminology
        super.init(uid, name: name)!
    }
    
    public required init?(_ uid: TermUID, name: TermName?) {
        return nil
    }
    
}

public class ClassTerm: Term, TermDictionaryDelayedInitContainer {
    
    public override class var kind: TypedTermUID.Kind {
        .type
    }
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
    
    public init(_ uid: TermUID, name: TermName?, parentClass: ClassTerm?) {
        self.parentClass = parentClass
        super.init(uid, name: name)!
    }
    
    public required convenience init?(_ uid: TermUID, name: TermName?) {
        self.init(uid, name: name, parentClass: nil)
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
    
}

public final class PluralClassTerm: ClassTerm {
    
    public override var enumerated: TermKind {
        return .pluralClass(self)
    }
    
    public var singularClass: ClassTerm
    
    public init(singularClass: ClassTerm, name: TermName) {
        self.singularClass = singularClass
        super.init(.variant(.plural, singularClass.uid), name: name, parentClass: singularClass.parentClass)
    }
    
    public required init?(_ uid: TermUID, name: TermName?) {
        return nil
    }
    
}

public final class PropertyTerm: Term {
    
    public override class var kind: TypedTermUID.Kind {
        .property
    }
    public override var enumerated: TermKind {
        return .property(self)
    }
    
    public required init(_ uid: TermUID, name: TermName?) {
        super.init(uid, name: name)!
    }
    
}

public final class CommandTerm: Term {
    
    public var parameters: ParameterTermDictionary
    
    public override class var kind: TypedTermUID.Kind {
        .command
    }
    public override var enumerated: TermKind {
        .command(self)
    }
    
    public init(_ uid: TermUID, name: TermName?, parameters: ParameterTermDictionary) {
        self.parameters = parameters
        super.init(uid, name: name)!
    }
    
    public required convenience init(_ uid: TermUID, name: TermName?) {
        self.init(uid, name: name, parameters: ParameterTermDictionary())
    }
    
}

public final class ParameterTerm: Term {
    
    public override class var kind: TypedTermUID.Kind {
        .parameter
    }
    public override var enumerated: TermKind {
        .parameter(self)
    }
    
    public required init(_ uid: TermUID, name: TermName?) {
        super.init(uid, name: name)!
    }
    
}

public final class VariableTerm: Term {
    
    public override class var kind: TypedTermUID.Kind {
        .variable
    }
    public override var enumerated: TermKind {
        .variable(self)
    }
    
    public required init(_ uid: TermUID, name: TermName?) {
        super.init(uid, name: name)!
    }
    
}

public final class ResourceTerm: Term, TermDictionaryDelayedInitContainer {
    
    public let resource: Resource
    
    public var terminology: TermDictionary?
    public var exportsTerminology: Bool {
        true
    }
    
    public override class var kind: TypedTermUID.Kind {
        .resource
    }
    public override var enumerated: TermKind {
        .resource(self)
    }
    
    public init(_ uid: TermUID, name: TermName, resource: Resource) {
        self.resource = resource
        super.init(uid, name: name)!
    }
    
    public required init?(_ uid: TermUID, name: TermName?) {
        return nil
    }
    
}

public enum Resource {
    
    case applicationByName(bundle: Bundle)
    case applicationByID(bundle: Bundle)
    
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
    /// A plural datatype, possibly with a four-byte AppleEvent code.
    /// Contains a (non-exporting) dictionary.
    case pluralClass(PluralClassTerm)
    /// A property, possibly with a four-byte AppleEvent code.
    case property(PropertyTerm)
    /// A command, possibly with four-byte AppleEvent class and ID codes.
    case command(CommandTerm)
    /// A command parameter, possibly with a four-byte AppleEvent code.
    case parameter(ParameterTerm)
    /// A user-defined variable.
    case variable(VariableTerm)
    /// An imported resource.
    case resource(ResourceTerm)
    
    /// The parts of this kind of term that are common to all kinds of terms.
    var generalized: Term {
        switch self {
        case .enumerator(let term as Term),
             .dictionary(let term as Term),
             .class_(let term as Term),
             .pluralClass(let term as Term),
             .property(let term as Term),
             .command(let term as Term),
             .parameter(let term as Term),
             .variable(let term as Term),
             .resource(let term as Term):
            return term
        }
    }
    
}
