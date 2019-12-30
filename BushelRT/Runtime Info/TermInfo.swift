import Bushel

public protocol TermInfo: CustomStringConvertible, CustomDebugStringConvertible {
    
    var uid: TermUID { get }
    var name: TermName? { get }
    
}

extension TermInfo {
    
    public var description: String {
        if let name = name {
            return String(describing: name)
        } else {
            return "«\(uid.kind) \(uid.name)»"
        }
    }
    
    public var debugDescription: String {
        "[\(type(of: self)) \(uid)\(name.map { " / ”\($0)“" } ?? "")]"
    }
    
}
