import Foundation

public enum BinaryOperation: Int {
    
    // Ordered by precedence, ascending
    case or, xor
    case and
    case isA, isNotA
    case equal, notEqual, less, lessEqual, greater, greaterEqual, startsWith, endsWith, contains, notContains, containedBy, notContainedBy
    case concatenate
    case add, subtract
    case multiply, divide
    case coerce
    
    public var precedence: PrecedenceGroup {
        switch self {
        case .or, .xor:
            return .or
        case .and:
            return .and
        case .isA, .isNotA:
            return .introspection
        case .equal, .notEqual, .less, .lessEqual, .greater, .greaterEqual, .startsWith, .endsWith, .contains, .notContains, .containedBy, .notContainedBy:
            return .comparison
        case .concatenate:
            return .concatenation
        case .add, .subtract:
            return .addition
        case .multiply, .divide:
            return .multiplication
        case .coerce:
            return .coercion
        }
    }
    
    public var associativity: Associativity {
        precedence.associativity
    }
    
}
