import Foundation

public struct Keyword: PrettyPrintable {
    
    public enum Styling {
        case keyword
        case `operator`
        case variable
        case number
        case string
    }
    
    public var keyword: String
    public var styling: Styling
    
    public init(keyword: String, styling: Styling = .keyword) {
        self.keyword = keyword
        self.styling = styling
    }
    
    public func prettified(source: String, level: Int) -> String {
        return keyword
    }
    
}

public struct Newline: PrettyPrintable {
    
    public init() {
    }
    
    public func prettified(source: String, level: Int) -> String {
        return "\n"
    }
    
}

public struct Expression {
    
    public indirect enum Kind {
        case topLevel
        case empty
        case end
        case that
        case it
        case null
        case scoped(Sequence)
        case parentheses(Expression)
        case function(name: Located<VariableTerm>, parameters: [Located<ParameterTerm>], arguments: [Located<VariableTerm>], body: Expression)
        case if_(condition: Expression, then: Expression, else: Expression?)
        case repeatTimes(times: Expression, repeating: Expression)
        case tell(target: Expression, to: Expression)
        case let_(Located<VariableTerm>, initialValue: Expression?)
        case return_(Expression?)
        case use(resource: Resource)
        case resource(Resource)
        case number(Double)
        case string(String)
        case list([Expression])
        case prefixOperator(operation: UnaryOperation, operand: Expression)
        case postfixOperator(operation: UnaryOperation, operand: Expression)
        case infixOperator(operation: BinaryOperation, lhs: Expression, rhs: Expression)
        case coercion(of: Expression, to: Located<ClassTerm>)
        case variable(VariableTerm)
        case enumerator(EnumeratorTerm)
        case class_(ClassTerm)
        case specifier(Specifier)
        case reference(to: Expression)
        case get(Expression)
        case set(Expression, to: Expression)
        case command(Located<CommandTerm>, parameters: [(key: Located<ParameterTerm>, value: Expression)])
        case weave(hashbang: Hashbang, body: String)
        case endWeave
    }
    
    public let kind: Kind
    public let location: SourceLocation
    public private(set) var elements: [PrettyPrintable]
    
    public static func empty(at index: String.Index) -> Expression {
        return Expression(.empty, [], at: SourceLocation(at: index, source: ""))
    }
    
    public init(_ kind: Kind, _ elements: [PrettyPrintable] = [], at location: SourceLocation) {
        self.kind = kind
        self.elements = elements
        self.location = location
        if elements.isEmpty {
            self.elements = [self]
        }
    }
    
}

public struct ParsedExpression {
    
    public let kind: Expression.Kind
    public let elements: [PrettyPrintable]
    
    public init(kind: Expression.Kind, elements: [PrettyPrintable]) {
        self.kind = kind
        self.elements = elements
    }
    
}

//
//extension Expression: PrettyPrintable {
//
//    public func prettified(source: String) -> String {
//        switch kind {
//        case .topLevel:
//            fatalError("Expression.Kind.topLevel should not be formatting itself!")
//        case .empty:
//            return ""
//        case .end:
//            return
//        case .scoped(let sequence):
//            printables = [sequence]
//        case .parentheses(let expression):
//            printables = [expression]
//        case let .function(name: name, parameters: parameters, body: body):
//            break
//        //            printables = [name, parameters, body]
//        case let .if_(condition, then, else_):
//            printables = [condition, then]
//            if let else_ = else_ {
//                printables += [else_]
//            }
//        case let .repeatTimes(times: times, repeating: repeating):
//            printables = [times, repeating]
//        case .tell(let target, let to):
//            printables = [target, to]
//        case .let_(let term, let initialValue):
//            printables = [term]
//            if let initialValue = initialValue {
//                printables += [initialValue]
//            }
//        case .use(let resource):
//            switch resource {
//            case .applicationByName(let term as LocatedTerm),
//                 .applicationByID(let term as LocatedTerm):
//                printables = [term]
//            }
//        case .resource(let resource):
//            printables = [resource.prettified]
//        case .null:
//            printables = [location.words(in: source)]
//        case .that:
//            printables = [location.words(in: source)]
//        case .number(let value):
//            printables = [String(value)]
//        case .string(let value):
//            printables = ["\"\(value)\""]
//        case .list(let expressions):
//            printables = expressions
//        case .variable(let term as NamedTerm),
//             .enumerator(let term as NamedTerm),
//             .class_(let term as NamedTerm):
//            printables = [term]
//        case .command(let term, var parameters):
//            printables = [term]
//
//            // Do direct parameter first
//            if parameters.first?.key.name.words.isEmpty ?? false {
//                printables += [parameters.removeFirst().value]
//            }
//
//            // Other named parameters
//            for (parameterTerm, parameterValue) in parameters {
//                if !parameterTerm.name.words.isEmpty {
//                    printables += [parameterTerm]
//                }
//                printables += [parameterValue]
//            }
//        case .reference(to: let expression):
//            printables = [expression]
//        case .get(let expression):
//            printables = [expression]
//        case .set(let expression, to: let newValueExpression):
//            printables = [expression, newValueExpression]
//        case .specifier(let specifier):
//            printables = [specifier.idTerm]
//
//            switch specifier.kind {
//            case .all,
//                 .first,
//                 .middle,
//                 .last,
//                 .random,
//                 .property:
//                break
//            case .simple(let dataExpression),
//                 .index(let dataExpression),
//                 .name(let dataExpression),
//                 .id(let dataExpression),
//                 .before(let dataExpression),
//                 .after(let dataExpression),
//                 .test(let dataExpression):
//                printables += [dataExpression]
//            case .range(let from, let to):
//                printables += [from, to]
//            }
//
//            if let parent = specifier.parent {
//                printables += [parent]
//            }
//        }
//    }
//
//}
