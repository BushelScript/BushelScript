import Bushel

/// Reformats an expression in a specific language, regardless of the
/// language it was originally written in.
public protocol SourceFormatter {
    
    func reformat(expression: Expression, level: Int) -> String
    
    init()
    
}

public extension SourceFormatter {
    
    func format(_ expression: Expression) -> String {
        return format(expression, level: 0, indentFirstLine: true)
    }
    
    func format(_ expression: Expression, level: Int, indentFirstLine: Bool = false) -> String {
        return formatAndIndent(expression: expression, level: level, indentFirstLine: indentFirstLine)
    }
    
    func format(_ sequence: Sequence, level: Int) -> String {
        return sequence.expressions.map { format($0, level: level, indentFirstLine: true) }.filter { !$0.isEmpty }.joined(separator: "\n")
    }
    
    func indentation(for level: Int) -> String {
        return String(repeating: "    ", count: level)
    }
    
}

private extension SourceFormatter {
    
    func formatAndIndent(expression: Expression, level: Int, indentFirstLine: Bool = false) -> String {
        if case .end = expression.kind {
            return ""
        }
        let formatted = reformat(expression: expression, level: level)
        return indentFirstLine ? indentation(for: level) + formatted : formatted
    }
    
}
