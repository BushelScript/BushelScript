import Bushel

public protocol TermInfo: CustomStringConvertible, CustomDebugStringConvertible {
    
    var kind: TypedTermUID.Kind { get }
    var uid: TermUID { get }
    var name: TermName? { get }
    
}

extension TermInfo {
    
    public var typedUID: TypedTermUID {
        TypedTermUID(kind, uid)
    }
    
}

extension TermInfo {
    
    public var description: String {
        if let name = name {
            return String(describing: name)
        } else {
            return "«\(typedUID.kind) \(uid)»"
        }
    }
    
    public var debugDescription: String {
        "[\(type(of: self)) \(typedUID)\(name.map { " / ”\($0)“" } ?? "")]"
    }
    
}
