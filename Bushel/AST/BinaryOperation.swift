import Foundation

public enum BinaryOperation: Int {
    
    public enum Associativity {
        
        case left
        case right
        
    }
    
    public enum PrecedenceGroup: Int, Comparable {
        
        case identity // Always has the lowest possible precedence.
        case or
        case and
        case comparison
        case concatenation
        case addition
        case multiplication
        
        public static func < (lhs: BinaryOperation.PrecedenceGroup, rhs: BinaryOperation.PrecedenceGroup) -> Bool {
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
