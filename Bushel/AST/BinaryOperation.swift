import Foundation

public enum BinaryOperation: Int {
    
    public enum Associativity {
        
        case left
        case right
        
    }
    
    public enum PrecedenceGroup: Int, Comparable {
        
        case identity // Always has the lowest possible precedence.
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
            case .concatenation:
                return .left
            case .addition:
                return .left
            case .multiplication:
                return .left
            }
        }
        
    }
    
    case add, subtract, multiply, divide
    case concatenate
    
    public var precedence: PrecedenceGroup {
        switch self {
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
