import Foundation

public enum PrecedenceGroup: Int, Comparable {
    
    case identity // Always has the lowest possible precedence.
    case or
    case and
    case introspection
    case comparison
    case concatenation
    case addition
    case multiplication
    
    public static func < (lhs: PrecedenceGroup, rhs: PrecedenceGroup) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var associativity: Associativity {
        switch self {
        case .identity:
            return .left
        case .or:
            return .left
        case .and:
            return .left
        case .introspection:
            return .left
        case .comparison:
            return .left
        case .concatenation:
            return .left
        case .addition:
            return .left
        case .multiplication:
            return .left
        }
    }
    
}

public enum Associativity {
    
    case left
    case right
    
}
