import Bushel

/// Reformats an expression in a specific language, regardless of the
/// language it was originally written in.
public protocol SourceFormatter {
    
    func reformat(expression: Expression, level: Int) -> String
    
    init()
    
}

public extension SourceFormatter {
    
    func format(_ expression: Expression) -> String {
        return format(expression, level: -1) + "\n"
    }
    
    func format(_ expression: Expression, level: Int) -> String {
        return reformat(expression: expression, level: level)
    }
    
    func format(_ sequence: Sequence, level: Int) -> String {
        return sequence.expressions
            .compactMap {
                guard !$0.kind.omit else {
                    return nil
                }
                let formatted = format($0, level: level + 1)
                return indentation(for: $0.kind.deindent ? level : level + 1) + formatted
            }
            .joined(separator: "\n")
    }
    
    func indentation(for level: Int) -> String {
        return String(repeating: "    ", count: level < 0 ? 0 : level)
    }
    
}

private extension Expression.Kind {
    
    var omit: Bool {
        switch self {
        case .end:
            return true
        default:
            return false
        }
    }
    
    var deindent: Bool {
        switch self {
        case .weave, .endWeave:
            return true
        default:
            return false
        }
    }
    
}
