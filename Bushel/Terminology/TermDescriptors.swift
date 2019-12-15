import Foundation

public protocol TermDescriptor {
    
    var uid: String { get }
    
    func realize(_ pool: TermPool) -> Term
    
}

public struct DictionaryDescriptor: TermDescriptor {
    
    public var uid: String

    public var name: TermName
    public var contents: [TermDescriptor]
    
    public init(_ uid: String, name: TermName, contents: [TermDescriptor]) {
        self.uid = uid
        self.name = name
        self.contents = contents
    }
    
    public func realize(_ pool: TermPool) -> Term {
        let contentsDictionary = TermDictionary(pool: pool, name: name, exports: true)
        contentsDictionary.add(contents.map { $0.realize(pool) })
        return DictionaryTerm(uid, name: name, terminology: contentsDictionary)
    }
    
}

public struct TypeDescriptor: TermDescriptor {
    
    public var uid: String
    public var code: OSType?
    
    public var name: TermName?
    public var parentUID: String
    
    public init(_ predefined: TypeUID, name: TermName? = nil, parent: String = TypeUID.item.rawValue) {
        self.init(predefined.rawValue, predefined.aeCode, name: name, parent: parent)
    }
    
    public init(_ uid: String, _ code: OSType? = nil, name: TermName? = nil, parent: String = TypeUID.item.rawValue) {
        self.uid = uid
        self.code = code
        self.name = name
        self.parentUID = parent
    }
    
    public func realize(_ pool: TermPool) -> Term {
        ClassTerm(uid, name: name, code: code, parentClass: pool.term(forID: parentUID) as? ClassTerm)
    }
    
}

public struct PropertyDescriptor: TermDescriptor {
    
    public var uid: String
    public var code: OSType?
    
    public var name: TermName?
    
    public init(_ predefined: PropertyUID, name: TermName? = nil) {
        self.init(predefined.rawValue, predefined.aeCode, name: name)
    }
    
    public init(_ uid: String, _ code: OSType? = nil, name: TermName? = nil) {
        self.uid = uid
        self.code = code
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        PropertyTerm(uid, name: name, code: code)
    }
    
}

public struct CommandDescriptor: TermDescriptor {
    
    public var uid: String
    public var codes: (class: AEEventClass, id: AEEventID)?
    
    public var name: TermName?
    public var parameters: [ParameterDescriptor]
    
    public init(_ predefined: CommandUID, name: TermName? = nil, parameters: [ParameterDescriptor] = []) {
        self.init(predefined.rawValue, predefined.aeDoubleCode, name: name, parameters: parameters)
    }
    
    public init(_ uid: String, _ codes: (class: AEEventClass, id: AEEventID)? = nil, name: TermName? = nil, parameters: [ParameterDescriptor]) {
        self.uid = uid
        self.codes = codes
        self.name = name
        self.parameters = parameters
    }
    
    public func realize(_ pool: TermPool) -> Term {
        CommandTerm(uid, name: name, codes: codes, parameters: ParameterTermDictionary(contents: parameters.map { $0.realize(pool) as! ParameterTerm }))
    }
    
}

public struct ParameterDescriptor: TermDescriptor {
    
    public var uid: String
    public var code: OSType?
    
    public var name: TermName?
    
    public init(_ predefined: ParameterUID, name: TermName? = nil) {
        self.init(predefined.rawValue, predefined.aeCode, name: name)
    }
    
    public init(_ uid: String, _ code: OSType? = nil, name: TermName? = nil) {
        self.uid = uid
        self.code = code
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        ParameterTerm(uid, name: name, code: code)
    }
    
}

public struct ConstantDescriptor: TermDescriptor {
    
    public var uid: String
    public var code: OSType?
    
    public var name: TermName?
    
    public init(_ predefined: ConstantUID, name: TermName? = nil) {
        self.init(predefined.rawValue, predefined.aeCode, name: name)
    }
    
    public init(_ uid: String, _ code: OSType? = nil, name: TermName? = nil) {
        self.uid = uid
        self.code = code
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        EnumeratorTerm(uid, name: name, code: code)
    }
    
}
