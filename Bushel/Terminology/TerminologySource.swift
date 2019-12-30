import Foundation

public protocol TerminologySource {
    
    associatedtype Term: Bushel.Term
    
    func term(forUID uid: TypedTermUID) -> Term?
    func term(named name: TermName) -> Term?
    
}

extension TerminologySource {
    
    public func dictionary(forUID uid: TypedTermUID) -> TermDictionary? {
        (term(forUID: uid) as? TermDictionaryContainer)?.terminology
    }
    
    public func dictionary(named name: TermName) -> TermDictionary? {
        (term(named: name) as? TermDictionaryContainer)?.terminology
    }
    
}

public protocol TermDictionaryContainer: AnyObject {
    
    var terminology: TermDictionary? { get }
    
}

public protocol TermDictionaryDelayedInitContainer: TermDictionaryContainer {
    
    var terminology: TermDictionary? { get set }
    var name: TermName? { get }
    var exportsTerminology: Bool { get }
    
}

public extension TermDictionaryDelayedInitContainer {
    
    @discardableResult
    func makeDictionary(under pool: TermPool) -> TermDictionary {
        terminology = TermDictionary(pool: pool, name: name, exports: exportsTerminology)
        return terminology!
    }
    
}
