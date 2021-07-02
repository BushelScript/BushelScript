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
    
    public var uri: Term.SemanticURI {
        Term.SemanticURI({
            switch self {
            case .or:
                return Commands.or
            case .xor:
                return Commands.xor
            case .and:
                return Commands.and
            case .isA:
                return Commands.isA
            case .isNotA:
                return Commands.isNotA
            case .equal:
                return Commands.equal
            case .notEqual:
                return Commands.notEqual
            case .less:
                return Commands.less
            case .lessEqual:
                return Commands.lessEqual
            case .greater:
                return Commands.greater
            case .greaterEqual:
                return Commands.greaterEqual
            case .startsWith:
                return Commands.startsWith
            case .endsWith:
                return Commands.endsWith
            case .contains:
                return Commands.contains
            case .notContains:
                return Commands.notContains
            case .containedBy:
                return Commands.containedBy
            case .notContainedBy:
                return Commands.notContainedBy
            case .concatenate:
                return Commands.concatenate
            case .add:
                return Commands.add
            case .subtract:
                return Commands.subtract
            case .multiply:
                return Commands.multiply
            case .divide:
                return Commands.divide
            case .coerce:
                return Commands.coerce
            }
        }())
    }
    
}
