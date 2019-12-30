import Foundation

public protocol TermDescriptor {
    
    var uid: TermUID { get }
    
    func realize(_ pool: TermPool) -> Term
    
}

public struct DictionaryDescriptor: TermDescriptor {
    
    public var uid: TermUID

    public var name: TermName
    public var contents: [TermDescriptor]
    
    public init(_ uid: TermUID, name: TermName, contents: [TermDescriptor]) {
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
    
    public var uid: TermUID
    
    public var name: TermName?
    public var parentUID: TermUID
    
    public init(_ predefined: TypeUID, name: TermName? = nil, parent: TermUID = TermUID(TypeUID.item)) {
        self.init(uid: TermUID(predefined), name: name, parent: parent)
    }
    
    public init(uid: TermUID, name: TermName? = nil, parent: TermUID = TermUID(TypeUID.item)) {
        self.uid = uid
        self.name = name
        self.parentUID = parent
    }
    
    public func realize(_ pool: TermPool) -> Term {
        ClassTerm(uid, name: name, parentClass: pool.term(forUID: TypedTermUID(.type, parentUID)) as? ClassTerm)
    }
    
}

public struct PropertyDescriptor: TermDescriptor {
    
    public var uid: TermUID
    
    public var name: TermName?
    
    public init(_ predefined: PropertyUID, name: TermName? = nil) {
        self.init(uid: TermUID(predefined), name: name)
    }
    
    public init(uid: TermUID, name: TermName? = nil) {
        self.uid = uid
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        PropertyTerm(uid, name: name)
    }
    
}

public struct CommandDescriptor: TermDescriptor {
    
    public var uid: TermUID
    
    public var name: TermName?
    public var parameters: [ParameterDescriptor]
    
    public init(_ predefined: CommandUID, name: TermName? = nil, parameters: [ParameterDescriptor] = []) {
        self.init(uid: TermUID(predefined), name: name, parameters: parameters)
    }
    
    public init(uid: TermUID, name: TermName? = nil, parameters: [ParameterDescriptor] = []) {
        self.uid = uid
        self.name = name
        self.parameters = parameters
    }
    
    public func realize(_ pool: TermPool) -> Term {
        CommandTerm(uid, name: name, parameters: ParameterTermDictionary(contents: parameters.map { $0.realize(pool) as! ParameterTerm }))
    }
    
}

public struct ParameterDescriptor: TermDescriptor {
    
    public var uid: TermUID
    
    public var name: TermName?
    
    public init(_ predefined: ParameterUID, name: TermName? = nil) {
        self.init(uid: TermUID(predefined), name: name)
    }
    
    public init(uid: TermUID, name: TermName? = nil) {
        self.uid = uid
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        ParameterTerm(uid, name: name)
    }
    
}

public struct ConstantDescriptor: TermDescriptor {
    
    public var uid: TermUID
    
    public var name: TermName?
    
    public init(_ predefined: ConstantUID, name: TermName? = nil) {
        self.init(uid: TermUID(predefined), name: name)
    }
    
    public init(uid: TermUID, name: TermName? = nil) {
        self.uid = uid
        self.name = name
    }
    
    public func realize(_ pool: TermPool) -> Term {
        EnumeratorTerm(uid, name: name)
    }
    
}
