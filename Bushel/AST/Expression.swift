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
        case sequence(Sequence)
        case scoped(Expression)
        case parentheses(Expression)
        case function(name: Located<VariableTerm>, parameters: [Located<ParameterTerm>], arguments: [Located<VariableTerm>], body: Expression)
        case if_(condition: Expression, then: Expression, else: Expression?)
        case repeatWhile(condition: Expression, repeating: Expression)
        case repeatTimes(times: Expression, repeating: Expression)
        case repeatFor(variable: Located<VariableTerm>, container: Expression, repeating: Expression)
        case tell(target: Expression, to: Expression)
        case let_(Located<VariableTerm>, initialValue: Expression?)
        case return_(Expression?)
        case use(resource: Located<ResourceTerm>)
        case resource(Located<ResourceTerm>)
        case integer(Int64)
        case double(Double)
        case string(String)
        case list([Expression])
        case record([(key: Expression, value: Expression)])
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

public extension Expression {
    
    var kindName: String {
        kind.kindName
    }
    
    var kindDescription: String {
        kind.kindDescription
    }
    
}

extension Expression.Kind {
    
    public var kindName: String {
        kindDescriptionStrings.kindName
    }
    
    public var kindDescription: String {
        kindDescriptionStrings.kindDescription
    }
    
    private var kindDescriptionStrings: (kindName: String, kindDescription: String) {
        switch self {
        case .topLevel:
            return ("Top-level", "")
        case .empty:
            return ("Empty expression", "No effect.")
        case .end:
            return ("End of block", "Ends the last opened block. Pops its dictionary, if any, off the lexicon.")
        case .that:
            return ("Previous result specifier", "Specifies the result of the last expression executed in sequence.")
        case .it:
            return ("Current target specifier", "Specifies the current command target, as set by the nearest “tell” block.")
        case .null:
            return ("Null literal", "The absence of a value.")
        case .sequence:
            return ("Sequence", "A list of sequentially evaluated expressions.")
        case .scoped:
            return ("Scoped block expression", "Provides a local dictionary that pops off the lexicon when the expression ends.")
        case .parentheses:
            return ("Parenthesized expression", "Contains an expression to allow for grouping.")
        case .function:
            return ("Function definition", "Defines a custom, reusable function.")
        case .if_:
            return ("Conditional expression", "Evaluates its condition. When the result is truthy, executes its “then” block. Otherwise, executes its ”else” block, if any.")
        case .repeatWhile:
            return ("Conditional repeat expression", "Executes the contained block as long as its condition is truthy.")
        case .repeatTimes:
            return ("Constant-bounded repeat expression", "Evaluates its ”times“ expression, then executes the contained block that many times.")
        case .repeatFor:
            return ("Iterative repeat expression", "Executes the contained block for each element in the specified collection.")
        case .tell:
            return ("Tell expression", "Changes the current command target and pushes the new target’s dictionary, if any, onto the lexicon.")
        case .let_:
            return ("Variable binding expression", "Defines a new variable term and assigns it the result of the initial value expression, or “null” if absent.")
        case .return_:
            return ("Return expression", "Immediately transfers control out of the current function. The result of the function is that of the specified expression, or “null” if absent.")
        case .use:
            return ("Use expression", "Acquires the specified resource and binds it to an exporting term of the same name. Produces a compile-time error if the resource cannot be found.")
        case .resource:
            return ("Resource reference", "A resource declared by a “use” statement.")
        case .integer:
            return ("Integer literal", "An integer with the specified value.")
        case .double:
            return ("Real literal", "A double-precision floating point number (roughly, a real number) with the specified value.")
        case .string:
            return ("String literal", "A string representing the specified text.")
        case .list:
            return ("List literal", "A heterogeneous list of items.")
        case .record:
            return ("Record literal", "A heterogeneous list of keys and values, indexed by key and stored as a hash table. Converts to an AppleScript-style record (with four-byte code keys) if possible when sent in an AppleEvent.")
        case .prefixOperator:
            return ("Prefix operator", "")
        case .postfixOperator:
            return ("Postfix operator", "")
        case .infixOperator:
            return ("Infix operator", "")
        case .coercion:
            return ("Coercion", "Attempts to convert the result of an expression to the specified type.")
        case .variable:
            return ("Variable reference", "A previously defined variable.")
        case .enumerator:
            return ("Constant reference", "An enumerated, symbolic constant whose semantics depend on the context of use.")
        case .class_:
            return ("Type reference", "A BushelScript type value.")
        case .specifier:
            return ("Specifier", "Refers to one or more object(s). Can be evaluated with a “get” command or passed around as a reference. Automatically evaluated in most contexts; use a reference expression to prevent this.")
        case .reference:
            return ("Reference expression", "Prevents the automatic evaluation of a specifier, producing an unevaluated reference as an object.")
        case .get:
            return ("Get command", "Explicitly evaluates a specifier, even in a nonevaluating context.")
        case .set:
            return ("Set command", "Assigns a new value to the target expression. The target may be a variable or a local or remote property.")
        case .command:
            return ("Command invocation", "Invokes the specified command with the given arguments.\n\nIf there is no direct object, the current command target is used as the direct object. First, asks the direct object to perform the command. If it cannot handle the command, and the current command target was not used as the direct object, asks the current command target to perform the command. In either case, if the command has still not been handled, asks the built-in top-level command target to perform the command.")
        case .weave:
            return ("Weave expression", "Calls out to an external shell program using the given hashbang line.\n\nInput and output: The result of the previous expression is coerced to a string and written to standard input; the weave expression’s result is a string containing whatever the program writes to standard output.\n\nHashbangs: If the hashbang line begins with a ‘/’, e.g., “#!/bin/sh”, it is used verbatim. Otherwise, the line is fed as input into ‘env’, e.g., “#!ruby” is transformed to “#!/usr/bin/env ruby”.\n\nEnding a weave: To end the weave, either write a new hashbang line with a different shell program, or write “#!bushelscript” to return to the previous BushelScript context.\n\nWeaves are an experimental feature and are likely to change with time.")
        case .endWeave:
            return ("End of weave expression", "Ends a weave expression and returns to the BushelScript context.")
        }
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
