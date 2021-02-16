import Bushel

public protocol TermInfo: CustomStringConvertible, CustomDebugStringConvertible {
    
    var kind: Term.SyntacticRole { get }
    var uid: Term.SemanticURI { get }
    var name: Term.Name? { get }
    
    func addName(_ name: Term.Name)
    
}

extension TermInfo {
    
    public var typedUID: Term.ID {
        Term.ID(kind, uid)
    }
    
}

extension TermInfo {
    
    public var description: String {
        if let name = name {
            return String(describing: name)
        } else {
            return "«\(typedUID.role) \(uid)»"
        }
    }
    
    public var debugDescription: String {
        "[\(type(of: self)) \(typedUID)\(name.map { " / ”\($0)“" } ?? "")]"
    }
    
}
