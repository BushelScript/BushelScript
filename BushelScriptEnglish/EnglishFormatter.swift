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
            return ""
        case .end:
            return ""
        case .scoped(let sequence):
            return format(sequence, level: level)
        case .parentheses(let expression):
            return "(\(format(expression, level: level)))"
        case let .if_(condition, then, else_):
            var needsEnd: Bool = true
            var formatted = "if \(format(condition, level: level))"
            if case .scoped = then.kind {
                formatted += "\n"
            } else {
                needsEnd = false
                formatted += " then "
            }
            formatted += format(then, level: level)
            
            if let `else` = else_ {
                formatted += "\n\(indentation(for: level))else"
                if case .scoped = `else`.kind {
                    needsEnd = true
                    formatted += "\n"
                } else {
                    needsEnd = false
                    formatted += " "
                }
                formatted += format(`else`, level: level)
            }
            
            if needsEnd {
                formatted += "\n\(indentation(for: level))end if"
            }
            return formatted
        case let .repeatWhile(condition, repeating):
            return "repeat while \(format(condition, level: level))\n\(format(repeating, level: level))\n\(indentation(for: level))end repeat"
        case let .repeatTimes(times, repeating):
            return "repeat \(format(times, level: level)) times\n\(format(repeating, level: level))\n\(indentation(for: level))end repeat"
        case .tell(let target, let to):
            if case .scoped = to.kind {
                return "tell \(format(target, level: level))\n\(format(to, level: level))\n\(indentation(for: level))end tell"
            } else {
                return "tell \(format(target, level: level)) to \(format(to, level: level))"
            }
        case .let_(let term, let initialValue):
            var formatted = "let \(term)"
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
        case .use(let resourceTerm):
            return "use \(resourceTerm.term.formattedForUseStatement)"
        case .resource(let resource):
            return "\(resource)"
        case .that:
            return "that"
        case .it:
            return "it"
        case .null:
            return "null"
        case .integer(let value):
            return String(value)
        case .double(let value):
            return String(value)
        case .string(let value):
            return "\"\(value)\""
        case .list(let expressions):
            return "{\(expressions.map { format($0, level: level) }.joined(separator: ", "))}"
        case .record(let expressions):
            return "\(expressions.map { "\(format($0.key, level: level)): \(format($0.value, level: level))" }.joined(separator: ", "))"
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand):
            switch operation {
            case .not:
                return "not \(format(operand, level: level))"
            }
        case .infixOperator(let operation, let lhs, let rhs):
            let formattedRhs = format(rhs, level: level)
            
            let formattedOperator: String = {
                switch operation {
                case .or:
                    return "or"
                case .xor:
                    return "xor"
                case .and:
                    return "and"
                case .isA:
                    return "is \("aeiou".contains(formattedRhs.first!) ? "an" : "a")"
                case .isNotA:
                    return "is not \("aeiou".contains(formattedRhs.first!) ? "an" : "a")"
                case .less:
                    return "<"
                case .lessEqual:
                    return "≤"
                case .equal:
                    return "="
                case .notEqual:
                    return "≠"
                case .greater:
                    return ">"
                case .greaterEqual:
                    return "≥"
                case .startsWith:
                    return "starts with"
                case .endsWith:
                    return "ends with"
                case .contains:
                    return "contains"
                case .notContains:
                    return "does not contain"
                case .containedBy:
                    return "is in"
                case .notContainedBy:
                    return "is not in"
                case .concatenate:
                    return "&"
                case .add:
                    return "+"
                case .subtract:
                    return "-"
                case .multiply:
                    return "*"
                case .divide:
                    return "/"
                }
            }()
            
            return "\(format(lhs, level: level)) \(formattedOperator) \(formattedRhs)"
        case let .coercion(of: expression, to: type):
            return "\(format(expression, level: level)) as \(type)"
        case .variable(let term as NamedTerm),
             .enumerator(let term as NamedTerm),
             .class_(let term as NamedTerm):
            return "\(term)"
        case .command(let term, var parameters):
            var formatted = "\(term)"
            
            // Do direct parameter first
            if parameters.first?.key.term.uid == TermUID(ParameterUID.direct) {
                formatted += " \(format(parameters.removeFirst().value, level: level))"
            }
            
            // Other (named) parameters
            for (parameterTerm, parameterValue) in parameters {
                formatted += " \(parameterTerm) \(format(parameterValue, level: level))"
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
            
            let className = "\(specifier.idTerm.term)"
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
            case .previous:
                formatted = "\(className)\(specifier.parent.map { " before\(format($0, level: level))" } ?? "")"
            case .next:
                formatted = "\(className)\(specifier.parent.map { " after\(format($0, level: level))" } ?? "")"
            case .range(let from, let to):
                formatted = "\(className) \(format(from, level: level)) thru \(format(to, level: level))"
            case .test(let predicate, _):
                formatted = "\(className) where \(format(predicate, level: level))"
            case .property:
                formatted = "\(className)"
            }
            
            if let parent = specifier.parent {
                formatted += " of \(format(parent, level: level))"
            }
            
            return formatted
        case .function(let name, let parameters, let arguments, let body):
            var formatted = "on \(name)"
            
            if !parameters.isEmpty {
                formatted += ":"
                
                func appendParameter(at index: Int) {
                    let parameter = parameters[index]
                    let argument = arguments[index]
                    formatted += " \(parameter)"
                    if argument.name != parameter.name {
                        formatted += " \(argument)"
                    }
                }
                
                appendParameter(at: parameters.startIndex)
                for index in parameters.indices.dropFirst() {
                    formatted += ","
                    appendParameter(at: index)
                }
            }
            
            formatted += "\n\(format(body, level: level))"
            
            formatted += "\n\(indentation(for: level))end \(name)"
            return formatted
        case .weave(let hashbang, let body):
            return "#!\(hashbang.invocation)\n\(body.removingTrailingWhitespace(removingNewlines: true))"
        case .endWeave:
            return "#!bushelscript"
        }
    }
    
}

extension ResourceTerm {
    
    public var formattedForUseStatement: String {
        resource.formattedForUseStatement
    }
    
}

extension Resource {
    
    public var formattedForUseStatement: String {
        switch self {
        case .applicationByName(let bundle):
            return "application \(bundle.object(forInfoDictionaryKey: kCFBundleNameKey as String) ?? bundle.bundleURL.lastPathComponent)"
        case .applicationByID(let bundle):
            return
                bundle.bundleIdentifier.map { "application id \($0))" } ??
                Resource.applicationByName(bundle: bundle).formattedForUseStatement
        }
    }
    
}
