import Foundation

public protocol TerminologySource {
    
    associatedtype Term: Bushel.Term
    
    func term(named name: TermName) -> Term?
    
}

extension TerminologySource {
    
    public func term(for stringName: String) -> Term? {
        return term(named: TermName(stringName))
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
        terminology = pool.dictionary(named: name, exports: exportsTerminology)
        return terminology!
    }
    
}

public var terminology: TermDictionary?
