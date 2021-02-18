import Bushel

public protocol TermInfo: CustomStringConvertible, CustomDebugStringConvertible {
    
    var role: Term.SyntacticRole { get }
    var uri: Term.SemanticURI { get }
    var name: Term.Name? { get }
    
    func addName(_ name: Term.Name)
    
}

extension TermInfo {
    
    public var id: Term.ID {
        Term.ID(role, uri)
    }
    
}

extension TermInfo {
    
    public var description: String {
        if let name = name {
            return String(describing: name)
        } else {
            return "«\(id.role) \(uri)»"
        }
    }
    
    public var debugDescription: String {
        "[\(type(of: self)) \(id)\(name.map { " / ”\($0)“" } ?? "")]"
    }
    
}
