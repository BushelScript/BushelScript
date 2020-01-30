import Foundation

public protocol TerminologySource {
    
    associatedtype Term: Bushel.Term
    
    func term(forUID uid: TypedTermUID) -> Term?
    func term(named name: TermName) -> Term?
    
}
