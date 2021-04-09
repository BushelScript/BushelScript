
/// Reformats an expression in a specific language, regardless of the
/// language it was originally written in.
public protocol SourceFormatter {
    
    func reformat(expression: Expression, level: Int) -> String
    
    init()
    
}

public extension SourceFormatter {
    
    func format(_ expression: Expression) -> String {
        return format(expression, level: -1)
    }
    
    func format(_ expression: Expression, level: Int) -> String {
        if case .sequence(let expressions) = expression.kind {
            guard !expressions.isEmpty else {
                return "\(indentation(for: level))"
            }
            return expressions
                .map {
                    let formatted = format($0, level: level + 1)
                    return indentation(for: $0.kind.deindent ? level : level + 1) + formatted
                }
                .joined(separator: "\n")
                + (level >= 0 ? "\n\(indentation(for: level))" : "")
        }
        
        return reformat(expression: expression, level: level)
    }
    
    func indentation(for level: Int) -> String {
        return String(repeating: "    ", count: level < 0 ? 0 : level)
    }
    
}

private extension Expression.Kind {
    
    var deindent: Bool {
        switch self {
        case .weave:
            return true
        default:
            return false
        }
    }
    
}
