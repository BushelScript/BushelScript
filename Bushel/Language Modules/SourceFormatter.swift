
/// Reformats an expression in a specific language, regardless of the
/// language it was originally written in.
public protocol SourceFormatter {
    
    func reformat(expression: Expression, level: Int) -> String
    
    var defaultEndKeyword: String { get }
    
    init()
    
}

extension SourceFormatter {
    
    public func format(_ expression: Expression) -> String {
        return format(expression, level: -1)
    }
    
    public func format(_ expression: Expression, level: Int, beginKeyword: String? = nil, endKeyword: String? = nil) -> String {
        if case .sequence(let expressions) = expression.kind {
            return
                (!expressions.isEmpty && level >= 0 ? "\n" : "")
                + expressions
                    .map {
                        let formatted = format($0, level: level + 1)
                        return indentation(for: $0.kind.deindent ? level : level + 1) + formatted
                    }
                    .joined(separator: "\n")
                + (level >= 0 ? "\n\(indentation(for: level))\(endKeyword ?? defaultEndKeyword)" : "")
        }
        
        return
            (beginKeyword ?? "")
            + reformat(expression: expression, level: level)
            + (endKeyword == nil ? "" : "\n\(indentation(for: level))\(endKeyword!)")
    }
    
    public func indentation(for level: Int) -> String {
        return String(repeating: "    ", count: level < 0 ? 0 : level)
    }
    
}

extension Expression.Kind {
    
    fileprivate var deindent: Bool {
        switch self {
        case .weave:
            return true
        default:
            return false
        }
    }
    
}
