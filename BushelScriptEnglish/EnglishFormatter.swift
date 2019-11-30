import Bushel
import BushelLanguage

public final class EnglishFormatter: BushelLanguage.SourceFormatter {
    
    public init() {
    }
    
    public func reformat(expression: Expression, level: Int) -> String {
        switch expression.kind {
        case .topLevel:
            fatalError("Expression.Kind.topLevel should not be formatting itself!")
        case .empty:
            return "\n"
        case .end:
            return ""
        case .scoped(let expression):
            return format(expression, level: level)
        case .parentheses(let expression):
            return "(\(format(expression, level: level + 1)))"
        case let .if_(condition, then, else_):
            var formatted = "if \(format(condition, level: level + 1)) then\n\(format(then, level: level + 1, indentFirstLine: true))"
            if let else_ = else_ {
                formatted += "\n\(indentation(for: level))else\n\(format(else_, level: level + 1, indentFirstLine: true))"
            }
            formatted += "\n\(indentation(for: level))end if"
            return formatted
        case let .repeatTimes(times: times, repeating: repeating):
            return "repeat \(times) times\n\(format(repeating, level: level + 1, indentFirstLine: true))"
        case .tell(let target, let to):
            return "tell \(format(target, level: level))\n\(format(to, level: level + 1, indentFirstLine: true))\n\(indentation(for: level))end tell"
        case .let_(let term, let initialValue):
            var formatted = "let \(term.displayName)"
            if let initialValue = initialValue {
                formatted += " be \(format(initialValue, level: level))"
            }
            return formatted
        case .return_(let returnValue):
            var formatted = "return"
            if let returnValue = returnValue {
                formatted += " \(format(returnValue, level: level))"
            }
            return formatted
        case .use(let resource):
            return "use \(resource.formattedForUseStatement)"
        case .resource(let resource):
            return resource.formatted
        case .null:
            return "null"
        case .that:
            return "that"
        case .it:
            return "it"
        case .number(let value):
            return String(value)
        case .string(let value):
            return "\"\(value)\""
        case .list(let expressions):
            return "{\(expressions.map { format($0, level: level) }.joined(separator: ", "))}"
        case .infixOperator(let operation, let lhs, let rhs):
            let formattedOperator: String = {
                switch operation {
                case .add:
                    return "+"
                case .subtract:
                    return "-"
                case .multiply:
                    return "*"
                case .divide:
                    return "/"
                case .concatenate:
                    return "&"
                }
            }()
            
            return "\(format(lhs, level: level)) \(formattedOperator) \(format(rhs, level: level))"
        case .variable(let term as NamedTerm),
             .enumerator(let term as NamedTerm),
             .class_(let term as NamedTerm):
            return term.displayName
        case .command(let term, var parameters):
            var formatted = "\(term.displayName)"
            
            // Do direct parameter first
            if parameters.first?.key.term.uid == ParameterUID.direct.rawValue {
                formatted += " \(format(parameters.removeFirst().value, level: level))"
            }
            
            // Other (named) parameters
            for (parameterTerm, parameterValue) in parameters {
                formatted += " \(parameterTerm.displayName) \(format(parameterValue, level: level))"
            }
            
            return formatted
        case .reference(to: let expression):
            return "ref \(format(expression, level: level))"
        case .get(let expression):
            return "get \(format(expression, level: level))"
        case .set(let expression, to: let newValueExpression):
            return "set \(format(expression, level: level)) to \(format(newValueExpression, level: level))"
        case .specifier(let specifier):
            var formatted: String
            
            let className = specifier.idTerm.displayName
            switch specifier.kind {
            case .simple(let dataExpression):
                formatted = "\(className) \(format(dataExpression, level: level))"
            case .index(let dataExpression):
                formatted = "\(className) index \(format(dataExpression, level: level))"
            case .name(let dataExpression):
                formatted = "\(className) named \(format(dataExpression, level: level))"
            case .id(let dataExpression):
                formatted = "\(className) id \(format(dataExpression, level: level))"
            case .all:
                formatted = "every \(className)"
            case .first:
                formatted = "first \(className)"
            case .middle:
                formatted = "middle \(className)"
            case .last:
                formatted = "last \(className)"
            case .random:
                formatted = "some \(className)"
            case .before(let expression):
                formatted = "\(className) before \(format(expression, level: level))"
            case .after(let expression):
                formatted = "\(className) after \(format(expression, level: level))"
            case .range(let from, let to):
                formatted = "\(className) \(format(from, level: level)) thru \(format(to, level: level))"
            case .test(let predicate):
                formatted = "\(className) where \(format(predicate, level: level))"
            case .property:
                formatted = "\(className)"
            }
            
            if let parent = specifier.parent {
                formatted += " of \(format(parent, level: level))"
            }
            
            return formatted
        case .function:
            fatalError("unimplemented")
        case .weave(let hashbang, let body):
            return "#!\(hashbang.invocation)\n\(body)"
        case .endWeave:
            return "#!bushelscript"
        }
    }
    
}

extension Resource {
    
    public var formattedForUseStatement: String {
        switch self {
        case .applicationByName(let term):
            return "application \(term.displayName)"
        case .applicationByID(let term):
            return "application id \(term.displayName)"
        }
    }
    
    public var formatted: String {
        switch self {
        case .applicationByName(let term as LocatedTerm),
             .applicationByID(let term as LocatedTerm):
            return "\(term.displayName)"
        }
    }
    
}
