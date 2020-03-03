import Foundation
import Regex

public protocol NamedTerm: CustomStringConvertible {
    
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
        return lhs.uid == rhs.uid && lhs.name == rhs.name
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(uid)
        hasher.combine(name)
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

    public static func make(for typedUID: TypedTermUID, name: TermName) -> Term? {
        let termType: Term.Type
        switch typedUID.kind {
        case .dictionary:
            termType = DictionaryTerm.self
        case .type:
            switch typedUID.uid {
            case .variant(let variant, let singularUID) where variant == .plural:
                let singularTerm = make(for: TypedTermUID(.type, singularUID), name: name) as! ClassTerm
                return PluralClassTerm(singularClass: singularTerm, name: name)
            default:
                termType = ClassTerm.self
            }
        case .property:
            termType = PropertyTerm.self
        case .constant:
            termType = EnumeratorTerm.self
        case .command:
            termType = CommandTerm.self
        case .parameter:
            termType = ParameterTerm.self
        case .variable:
            termType = VariableTerm.self
        case .resource:
            termType = ResourceTerm.self
        }
        return termType.init(typedUID.uid, name: name)
    }
    
}

public final class EnumeratorTerm: Term {
    
    public override class var kind: TypedTermUID.Kind {
        .constant
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
    
    public var storedDictionary: TermDictionary?
    public let exportsTerminology: Bool
    
    public init(_ uid: TermUID, name: TermName?, terminology: TermDictionary) {
        self.storedDictionary = terminology
        self.exportsTerminology = terminology.exports
        super.init(uid, name: name)!
    }
    
    public init(_ uid: TermUID, name: TermName?, exports: Bool) {
        self.storedDictionary = nil
        self.exportsTerminology = exports
        super.init(uid, name: name)!
    }
    
    public required convenience init(_ uid: TermUID, name: TermName?) {
        self.init(uid, name: name, exports: true)
    }
    
}

public class ClassTerm: Term, TermDictionaryContainer {
    
    public override class var kind: TypedTermUID.Kind {
        .type
    }
    public override var enumerated: TermKind {
        return .class_(self)
    }
    
    public var storedDictionary: TermDictionary? = nil {
        didSet {
            if
                let myTerminology = storedDictionary,
                let parentTerminology = parentClass?.storedDictionary
            {
                storedDictionary = TermDictionary(merging: parentTerminology, into: myTerminology)
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

public final class ResourceTerm: Term, TermDictionaryContainer {
    
    public let resource: Resource
    
    public var storedDictionary: TermDictionary?
    public var exportsTerminology: Bool {
        true
    }
    
    public override class var kind: TypedTermUID.Kind {
        .resource
    }
    public override var enumerated: TermKind {
        .resource(self)
    }
    
    public init(_ uid: TermUID, name: TermName?, resource: Resource) {
        self.resource = resource
        super.init(uid, name: name)!
    }
    
    public required convenience init?(_ uid: TermUID, name: TermName?) {
        guard
            let resName = uid.resName,
            let resource = Resource(normalized: resName)
        else {
            return nil
        }
        
        self.init(uid, name: name, resource: resource)
    }
    
}

public enum Resource {
    
    case system(version: String?)
    case applicationByName(bundle: Bundle)
    case applicationByID(bundle: Bundle)
    case scriptingAdditionByName(bundle: Bundle)
    case applescriptAtPath(path: String, script: NSAppleScript)
    
}

public protocol ResolvedResource {
    
    func enumerated() -> Resource
    
}

extension OperatingSystemVersion: CustomStringConvertible {
    
    public var description: String {
        "\(majorVersion).\(minorVersion).\(patchVersion)"
    }
    
}

// MARK: Resource resolution
extension Resource {
    
    public struct System: ResolvedResource {
        
        public let version: OperatingSystemVersion?
        
        public init?(versionString: String) {
            guard !versionString.isEmpty else {
                self.init()
                return
            }
            
            guard let match = Regex("[vV]?(\\d+)\\.(\\d+)(?:\\.(\\d+))?").firstMatch(in: versionString) else {
                return nil
            }
            
            let versionComponents = match.captures.compactMap { $0.map { Int($0)! } }
            let majorVersion = versionComponents[0]
            let minorVersion = versionComponents[1]
            let patchVersion = versionComponents.indices.contains(2) ? versionComponents[2] : 0
            
            let version = OperatingSystemVersion(majorVersion: majorVersion, minorVersion: minorVersion, patchVersion: patchVersion)
            self.init(version: version)
        }
        public init?(version: OperatingSystemVersion?) {
            if let version = version {
                guard ProcessInfo.processInfo.isOperatingSystemAtLeast(version) else {
                    return nil
                }
            }
            
            self.version = version
        }
        public init() {
            self.version = nil
        }
        
        public func enumerated() -> Resource {
            .system(version: version.map { "\($0)" })
        }
        
    }
    
    public struct ApplicationByName: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(name: String) {
            guard let bundle = Bundle(applicationName: name) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .applicationByName(bundle: bundle)
        }
        
    }
    
    public struct ApplicationByID: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(id: String) {
            guard let bundle = Bundle(applicationBundleIdentifier: id) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .applicationByID(bundle: bundle)
        }
        
    }
    
    public struct ScriptingAdditionByName: ResolvedResource {
        
        public let bundle: Bundle
        
        public init?(name: String) {
            guard let bundle = Bundle(scriptingAdditionName: name) else {
                return nil
            }
            
            self.bundle = bundle
        }
        
        public func enumerated() -> Resource {
            .scriptingAdditionByName(bundle: bundle)
        }
        
    }
    
    public struct AppleScriptAtPath: ResolvedResource {
        
        public let path: String
        public let script: NSAppleScript
        
        public init?(path: String) {
            let fileURL = URL(fileURLWithPath: path)
            guard let script = NSAppleScript(contentsOf: fileURL, error: nil) else {
                return nil
            }
            
            self.path = path
            self.script = script
        }
        
        public func enumerated() -> Resource {
            .applescriptAtPath(path: path, script: script)
        }
        
    }
    
}

// MARK: Resource → String
extension Resource: CustomStringConvertible {
    
    public var description: String {
        normalized
    }
    
    public var normalized: String {
        "\(kind):\(data)"
    }
    
    public enum Kind: String {
        case system
        case applicationByName = "app"
        case applicationByID = "appid"
        case scriptingAdditionByName = "osax"
        case applescriptAtPath = "as"
    }
    
    public var kind: Kind {
        switch self {
        case .system:
            return .system
        case .applicationByName:
            return .applicationByName
        case .applicationByID:
            return .applicationByID
        case .scriptingAdditionByName:
            return .scriptingAdditionByName
        case .applescriptAtPath:
            return .applescriptAtPath
        }
    }
    
    public var data: String {
        switch self {
        case .system:
            return ""
        case .applicationByName(let bundle):
            return bundle.fileSystemName
        case .applicationByID(let bundle):
            return bundle.bundleIdentifier!
        case .scriptingAdditionByName(let bundle):
            return bundle.fileSystemName
        case .applescriptAtPath(let path, _):
            return path
        }
    }
    
}

// MARK: String → Resource
extension Resource {
    
    public init?(normalized: String) {
        let components = normalized.split(separator: ":", maxSplits: 1)
        guard
            components.indices.contains(0),
            let kind = Kind(rawValue: String(components[0]))
        else {
            return nil
        }
        self.init(kind: kind, data: components.indices.contains(1) ? String(components[1]) : "")
    }
    
    public init?(kind: Kind, data: String) {
        guard
            let resolved: ResolvedResource = { () -> ResolvedResource? in
                switch kind {
                case .system:
                    return System()
                case .applicationByName:
                    return ApplicationByName(name: data)
                case .applicationByID:
                    return ApplicationByID(id: data)
                case .scriptingAdditionByName:
                    return ScriptingAdditionByName(name: data)
                case .applescriptAtPath:
                    return AppleScriptAtPath(path: data)
                }
            }()
        else {
            return nil
        }
        
        self = resolved.enumerated()
    }
    
}

// MARK: Terminology loading
extension ResourceTerm {
    
    public func loadResourceTerminology(under pool: TermPool) throws {
        switch resource {
        case .system(_):
            guard let application = Resource.ApplicationByID(id: "com.apple.SystemEvents") else {
                return
            }
            try loadTerminology(at: application.bundle.bundleURL, under: pool)
        case .applicationByName(let bundle),
             .applicationByID(let bundle),
             .scriptingAdditionByName(let bundle):
            try loadTerminology(at: bundle.bundleURL, under: pool)
        case .applescriptAtPath(let path, _):
            try loadTerminology(at: URL(fileURLWithPath: path), under: pool)
        }
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
