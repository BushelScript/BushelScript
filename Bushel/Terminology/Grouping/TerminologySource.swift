import Foundation

public protocol TerminologySource {
    
    func term(id: Term.ID) -> Term?
    func term(named name: Term.Name) -> Term?
    
}
