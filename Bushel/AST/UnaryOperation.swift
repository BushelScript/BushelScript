import Foundation

public enum UnaryOperation: Int {
    
    case not
    
    public var uri: Term.SemanticURI {
        Term.SemanticURI({
            switch self {
            case .not:
                return Commands.not
            }
        }())
    }
    
}
