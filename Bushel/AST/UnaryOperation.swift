import Foundation

public enum UnaryOperation: Int {
    
    case not
    case negate
    
    public var uri: Term.SemanticURI {
        Term.SemanticURI({
            switch self {
            case .not:
                return Commands.not
            case .negate:
                return Commands.negate
            }
        }())
    }
    
}
