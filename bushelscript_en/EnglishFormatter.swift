import Bushel

public final class EnglishFormatter: SourceFormatter {
    
    public init() {
    }
    
    public func reformat(expression: Expression, level: Int) -> String {
        switch expression.kind {
        case .empty:
            return ""
        case .sequence(_):
            fatalError("unreachable")
        case .scoped(let expression):
            return format(expression, level: level)
        case .parentheses(let expression):
            return "(\(format(expression, level: level)))"
        case let .try_(body, handle):
            var formatted = "try"
            if case .sequence = body.kind {
                formatted += "\n"
            } else {
                formatted += " "
            }
            formatted += format(body, level: level)
            
            formatted += "handle"
            var needsEnd: Bool = true
            if case .sequence = handle.kind {
                formatted += "\n"
                needsEnd = true
            } else {
                formatted += " "
                needsEnd = false
            }
            formatted += format(handle, level: level)
            
            if needsEnd {
                formatted += "end"
            }
            return formatted
        case let .if_(condition, then, else_):
            var needsEnd: Bool = true
            var formatted = "if \(format(condition, level: level))"
            if case .sequence = then.kind {
                formatted += "\n"
            } else {
                formatted += " then "
                needsEnd = false
            }
            formatted += format(then, level: level)
            
            if let `else` = else_ {
                formatted += "else"
                if case .sequence = `else`.kind {
                    formatted += "\n"
                    needsEnd = true
                } else {
                    formatted += " "
                    needsEnd = false
                }
                formatted += format(`else`, level: level)
            }
            
            if needsEnd {
                formatted += "end"
            }
            return formatted
        case let .repeatWhile(condition, repeating):
            return "repeat while \(format(condition, level: level))\n\(format(repeating, level: level))end"
        case let .repeatTimes(times, repeating):
            return "repeat \(format(times, level: level)) times\n\(format(repeating, level: level))end"
        case let .repeatFor(variable, container, repeating):
            return "repeat for \(variable) in \(format(container, level: level))\n\(format(repeating, level: level))end"
        case .tell(let target, let to):
            if case .sequence = to.kind {
                return "tell \(format(target, level: level))\n\(format(to, level: level))end"
            } else {
                return "tell \(format(target, level: level)) to \(format(to, level: level))"
            }
        case .let_(let term, let initialValue):
            var formatted = "let \(term)"
            if let initialValue = initialValue {
                formatted += " be \(format(initialValue, level: level))"
            }
            return formatted
        case let .define(term, as: existingTerm):
            var formatted = "define \(term)"
            if let existingTerm = existingTerm {
                formatted += " as \(existingTerm)"
            }
            return formatted
        case let .defining(term, as: existingTerm, body: body):
            var formatted = "defining \(term)"
            if let existingTerm = existingTerm {
                formatted += " as \(existingTerm)"
            }
            formatted += "\n\(format(body, level: level))end"
            return formatted
        case .return_(let returnValue):
            var formatted = "return"
            if let returnValue = returnValue {
                formatted += " \(format(returnValue, level: level))"
            }
            return formatted
        case .raise(let error):
            return "raise \(format(error, level: level))"
        case .use(let resourceTerm):
            return "use \(resourceTerm.formattedForUseStatement)"
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
            return "{\(expressions.map { "\(format($0.key, level: level)): \(format($0.value, level: level))" }.joined(separator: ", "))}"
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
                    return "is \(formattedRhs.startsWithVowel ? "an" : "a")"
                case .isNotA:
                    return "is not \(formattedRhs.startsWithVowel ? "an" : "a")"
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
                case .coerce:
                    return "as"
                }
            }()
            
            return "\(format(lhs, level: level)) \(formattedOperator) \(formattedRhs)"
        case .variable(let term),
             .enumerator(let term),
             .type(let term):
            return "\(term)"
        case .command(let term, var parameters):
            var formatted = "\(term)"
            
            // Do direct parameter first
            if parameters.first?.key.uri == Term.SemanticURI(Parameters.direct) {
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
            
            let term = "\(specifier.term)"
            switch specifier.kind {
            case .simple(let dataExpression):
                formatted = "\(term) \(format(dataExpression, level: level))"
            case .index(let dataExpression):
                formatted = "\(term) index \(format(dataExpression, level: level))"
            case .name(let dataExpression):
                formatted = "\(term) named \(format(dataExpression, level: level))"
            case .id(let dataExpression):
                formatted = "\(term) id \(format(dataExpression, level: level))"
            case .all:
                formatted = "every \(term)"
            case .first:
                formatted = "first \(term)"
            case .middle:
                formatted = "middle \(term)"
            case .last:
                formatted = "last \(term)"
            case .random:
                formatted = "some \(term)"
            case .previous:
                formatted = "\(term)\(specifier.parent.map { " before\(format($0, level: level))" } ?? "")"
            case .next:
                formatted = "\(term)\(specifier.parent.map { " after\(format($0, level: level))" } ?? "")"
            case .range(let from, let to):
                formatted = "\(term) \(format(from, level: level)) thru \(format(to, level: level))"
            case .test(let predicate, _):
                formatted = "\(term) where \(format(predicate, level: level))"
            case .property:
                formatted = "\(term)"
            }
            
            if let parent = specifier.parent {
                formatted += " of \(format(parent, level: level))"
            }
            
            return formatted
        case .insertionSpecifier(let insertionSpecifier):
            var formatted: String
            
            var useOf: Bool = false
            switch insertionSpecifier.kind {
            case .beginning:
                formatted = "first position"
                useOf = true
            case .end:
                formatted = "last position"
                useOf = true
            case .before:
                formatted = "position before"
            case .after:
                formatted = "position after"
            }
            
            if let parent = insertionSpecifier.parent {
                if useOf {
                    formatted += " of"
                }
                formatted += " \(format(parent, level: level))"
            }
            
            return formatted
        case .function(let name, let parameters, let types, let arguments, let body):
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
                    
                    if let type = types[index] {
                        formatted += "(\(format(type, level: level))"
                    }
                }
                
                appendParameter(at: parameters.startIndex)
                for index in parameters.indices.dropFirst() {
                    formatted += ","
                    appendParameter(at: index)
                }
            }
            
            formatted += "\n\(format(body, level: level))"
            
            formatted += "end"
            return formatted
        case .block(let arguments, let body):
            var formatted = ""
            
            if !arguments.isEmpty {
                formatted += "take \(arguments.map { "\($0)" }.joined(separator: ", ")) "
            }
            
            formatted += "do"
            if case .sequence = body.kind {
                formatted += "\n\(format(body, level: level))end"
            } else {
                formatted += "\(format(body, level: level))"
            }
            
            return formatted
        case .multilineString(let bihash, let body):
            return
                "##\(bihash.delimiter.isEmpty ? "" : "(\(bihash.delimiter))")\n\(body)\n##"
        case .weave(let hashbang, let body):
            return "#!\(hashbang.invocation)\n\(body.removingTrailingWhitespace(removingNewlines: true))"
        }
    }
    
}

extension Term {
    
    public var formattedForUseStatement: String {
        let name = self.name!
        switch resource {
        case .bushelscript:
            return "BushelScript"
        case .system(let version):
            return "system\(version.map { " version \($0)" } ?? "")"
        case .applicationByName:
            return "app \(name)"
        case .applicationByID:
            return "app id \(name)"
        case .scriptingAdditionByName:
            return "scripting addition \(name)"
        case .libraryByName:
            return "library \(name)"
        case .applescriptAtPath(let path, _):
            // TODO: Escape path when spitting back out
            return "AppleScript \(name) at \"\(path)\""
        case nil:
            return ""
        }
    }
    
}
