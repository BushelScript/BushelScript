import Foundation

public protocol ByNameTermLookup {
    
    func term(named name: Term.Name) -> Term?
    
}
