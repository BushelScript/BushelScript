import Foundation

public protocol TermDictionaryContainer: Term {
    
    var storedDictionary: TermDictionary? { get set }
    var exportsTerminology: Bool { get }
    
}

public extension TermDictionaryContainer {
    
    @discardableResult
    func makeDictionary(under pool: TermPool) -> TermDictionary {
        if let terminology = storedDictionary {
            return terminology
        }
        storedDictionary = TermDictionary(pool: pool, uid: uid, name: name, exports: exportsTerminology)
        return storedDictionary!
    }
    
}
