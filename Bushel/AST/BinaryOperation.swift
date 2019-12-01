import Foundation

public enum BinaryOperation: Int {
    
    case or, xor
    case and
    case equal, notEqual, less, lessEqual, greater, greaterEqual
    case concatenate
    case add, subtract, multiply, divide
    
    public var precedence: PrecedenceGroup {
        switch self {
        case .or, .xor:
            return .or
        case .and:
            return .and
        case .equal, .notEqual, .less, .lessEqual, .greater, .greaterEqual:
            return .comparison
        case .concatenate:
            return .concatenation
        case .add, .subtract:
            return .addition
        case .multiply, .divide:
            return .multiplication
        }
    }
    
    public var associativity: Associativity {
        precedence.associativity
    }
    
}
