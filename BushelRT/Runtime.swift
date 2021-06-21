import Bushel
import os

private let log = OSLog(subsystem: logSubsystem, category: "Runtime")

public struct RuntimeError: CodableLocalizedError, Located {
    
    /// The error message as formatted during init.
    public let description: String
    
    /// The source location to which the error applies.
    public let location: SourceLocation
    
    public var errorDescription: String? {
        description
    }
    
}

/// The error thrown by `raise` in user code.
public struct RaisedObjectError: CodableLocalizedError, Located {
    
    /// The object given to `raise`.
    public let error: RT_Object
    
    /// The source location of the `raise` expression.
    public let location: SourceLocation
    
    public var errorDescription: String? {
        "\(error)"
    }
    
}

public class Runtime {
    
    @Atomic
    public var isRunning = false
    @Atomic
    public var shouldTerminate = false
    
    var builtin: Builtin!
    
    /// The result of the last expression executed in sequence.
    public lazy var lastResult: RT_Object = null
    
    /// The singleton `null` instance.
    public lazy var null = RT_Null(self)
    /// The singleton `true` boolean instance.
    public lazy var `true` = RT_Boolean(self, value: true)
    /// The singleton `false` boolean instance.
    public lazy var `false` = RT_Boolean(self, value: false)
    
    private var locations: [SourceLocation] = []
    private func pushLocation(_ location: SourceLocation) {
        locations.append(location)
    }
    private func popLocation() {
        _ = locations.popLast()
    }
    var currentLocation: SourceLocation? {
        locations.last
    }
    
    public var arguments: [String] = []
    public var scriptName: String?
    
    public init(arguments: [String] = [], scriptName: String? = nil) {
        self.arguments = arguments
        self.scriptName = scriptName
    }
    
    public lazy var topScript = RT_Script(self, name: scriptName)
    public lazy var core = RT_Core(self)
    
    public var reflection = Reflection()
    
}

public extension Runtime {
    
    func terminateIfNeeded() throws {
        if shouldTerminate {
            throw Terminated()
        }
    }
    
    func run(_ program: Program) throws -> RT_Object {
        reflection.inject(from: program.rootTerm)
        builtin = Builtin(
            self,
            frameStack: RT_FrameStack(bottom: [
                Term.SemanticURI(Variables.Core): core,
                Term.SemanticURI(Variables.Script): topScript
            ]),
            moduleStack: RT_ModuleStack(bottom: core, rest: [topScript]),
            targetStack: RT_TargetStack(bottom: core, rest: [topScript])
        )
        return try run(program.ast)
    }
    
    func run(_ expression: Expression) throws -> RT_Object {
        shouldTerminate = false
        isRunning = true
        defer {
            isRunning = false
        }
        
        let result: RT_Object
        do {
            result = try runPrimary(expression)
        } catch let earlyReturn as EarlyReturn {
            result = earlyReturn.value
        }
        
        os_log("Execution result: %@", log: log, type: .debug, String(describing: result))
        return result
    }
    
    struct Terminated: LocalizedError {
        
        public var errorDescription: String? {
            "Script terminated by request."
        }
        
    }
    
    struct EarlyReturn: Error {
        
        var value: RT_Object
        
    }
    
    func runPrimary(_ expression: Expression, evaluateSpecifiers: Bool = true) throws -> RT_Object {
        pushLocation(expression.location)
        defer {
            popLocation()
        }
        
        do {
            try terminateIfNeeded()
            switch expression.kind {
            case .empty: // MARK: .empty
                return lastResult
            case .that: // MARK: .that
                return try evaluateSpecifiers ? evaluatingSpecifier(lastResult) : lastResult
            case .it: // MARK: .it
                return try evaluateSpecifiers ? evaluatingSpecifier(builtin.target) : builtin.target
            case .null: // MARK: .null
                return null
            case .sequence(let expressions): // MARK: .sequence
                for expression in expressions {
                    lastResult = try runPrimary(expression)
                }
                return lastResult
            case .scoped(let expression): // MARK: .scoped
                return try runPrimary(expression)
            case .parentheses(let expression): // MARK: .parentheses
                return try runPrimary(expression)
            case let .try_(body, handle): // MARK: .try_
                do {
                    return try runPrimary(body)
                } catch {
                    builtin.targetStack.push(RT_Error(self, error))
                    defer { builtin.targetStack.pop() }
                    return try runPrimary(handle)
                }
            case let .if_(condition, then, else_): // MARK: .if_
                let conditionValue = try runPrimary(condition)
                
                if conditionValue.truthy {
                    return try runPrimary(then)
                } else if let else_ = else_ {
                    return try runPrimary(else_)
                } else {
                    return lastResult
                }
            case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
                var repeatResult: RT_Object?
                while try runPrimary(condition).truthy {
                    repeatResult = try runPrimary(repeating)
                }
                return repeatResult ?? lastResult
            case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
                let timesValue = try runPrimary(times)
                
                var repeatResult: RT_Object?
                var count = 0
                while try builtin.binaryOp(.less, RT_Integer(self, value: count), timesValue).truthy {
                    repeatResult = try runPrimary(repeating)
                    count += 1
                }
                return repeatResult ?? lastResult
            case .repeatFor(let variable, let container, let repeating): // MARK: .repeatFor
                let containerValue = try runPrimary(container)
                let timesValue = try builtin.getSequenceLength(containerValue)
                
                var repeatResult: RT_Object?
                // 1-based indices wheeeeee
                for count in 1...timesValue {
                    let elementValue = try builtin.getFromSequenceAtIndex(containerValue, Int64(count))
                    builtin[variable: variable] = elementValue
                    repeatResult = try runPrimary(repeating)
                }
                return repeatResult ?? lastResult
            case .tell(let newModule, let to): // MARK: .tell
                let newModuleObject = try runPrimary(newModule, evaluateSpecifiers: false)
                guard let newModule = newModuleObject as? RT_Module else {
                    throw NotAModule(object: newModuleObject)
                }
                builtin.moduleStack.push(newModule)
                defer {
                    builtin.moduleStack.pop()
                }
                return try runPrimary(to)
            case .target(let newTarget, let body): // MARK: .target
                let newTargetValue = try runPrimary(newTarget, evaluateSpecifiers: false)
                builtin.targetStack.push(newTargetValue)
                defer {
                    builtin.targetStack.pop()
                }
                return try runPrimary(body)
            case .let_(let term, let initialValue): // MARK: .let_
                let initialExprValue = try initialValue.map { try runPrimary($0) } ?? null
                builtin[variable: term] = initialExprValue
                return initialExprValue
            case .define(_, as: _): // MARK: .define
                return lastResult
            case .defining(_, as: _, body: let body): // MARK: .defining
                return try runPrimary(body)
            case .return_(let returnValue): // MARK: .return_
                let returnExprValue = try returnValue.map { try runPrimary($0) } ??
                    lastResult
                throw EarlyReturn(value: returnExprValue)
            case .raise(let error): // MARK: .raise
                let errorValue = try runPrimary(error)
                if let errorValue = errorValue as? RT_Error {
                    throw errorValue.error
                } else {
                    throw RaisedObjectError(error: errorValue, location: expression.location)
                }
            case .integer(let value): // MARK: .integer
                return RT_Integer(self, value: value)
            case .double(let value): // MARK: .double
                return RT_Real(self, value: value)
            case .string(let value): // MARK: .string
                return RT_String(self, value: value)
            case .list(let expressions): // MARK: .list
                return try RT_List(self, contents:
                    expressions.map { try runPrimary($0) }
                )
            case .record(let keyValues): // MARK: .record
                return try RT_Record(self, contents:
                    [RT_Object : RT_Object](
                        try keyValues.map {
                            try (
                                runPrimary($0.key, evaluateSpecifiers: false),
                                runPrimary($0.value)
                            )
                        },
                        uniquingKeysWith: {
                            try builtin.binaryOp(.greater, $1, $0).truthy ? $1 : $0
                        }
                    )
                )
            case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
                let operandValue = try runPrimary(operand)
                return builtin.unaryOp(operation, operandValue)
            case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
                let lhsValue = try runPrimary(lhs)
                let rhsValue = try runPrimary(rhs)
                return try builtin.binaryOp(operation, lhsValue, rhsValue)
            case .variable(let term): // MARK: .variable
                return builtin[variable: term]
            case .use(let term), // MARK: .use
                 .resource(let term): // MARK: .resource
                return try builtin.getResource(term)
            case .enumerator(let term): // MARK: .constant
                return builtin.newConstant(term.id)
            case .type(let term): // MARK: .class_
                return RT_Type(self, value: reflection.types[term.uri])
            case .set(let expression, to: let newValueExpression): // MARK: .set
                if case .variable(let variableTerm) = expression.kind {
                    let newValueExprValue = try runPrimary(newValueExpression)
                    builtin[variable: variableTerm] = newValueExprValue
                    return newValueExprValue
                } else {
                    let expressionExprValue = try runPrimary(expression, evaluateSpecifiers: false)
                    let newValueExprValue = try runPrimary(newValueExpression)
                    
                    let arguments: [Reflection.Parameter : RT_Object] = [
                        Reflection.Parameter(.direct): expressionExprValue,
                        Reflection.Parameter(.set_to): newValueExprValue
                    ]
                    let command = reflection.commands[.set]
                    return try builtin.run(command: command, arguments: arguments)
                }
            case .command(let term, let parameters): // MARK: .command
                let parameterExprValues: [(key: Reflection.Parameter, value: RT_Object)] = try parameters.map { kv in
                    let (parameterTerm, parameterValue) = kv
                    let parameter = reflection.commands[term.uri].parameters[parameterTerm.uri]
                    let value = try runPrimary(parameterValue)
                    return (parameter, value)
                }
                let arguments = [Reflection.Parameter : RT_Object](uniqueKeysWithValues:
                    parameterExprValues
                )
                let command = reflection.commands[term.uri]
                return try builtin.run(command: command, arguments: arguments)
            case .reference(let expression): // MARK: .reference
                return try runPrimary(expression, evaluateSpecifiers: false)
            case .get(let expression): // MARK: .get
                return try evaluatingSpecifier(runPrimary(expression))
            case .specifier(let specifier): // MARK: .specifier
                let specifierValue = try buildSpecifier(specifier)
                return evaluateSpecifiers ? try evaluatingSpecifier(specifierValue) : specifierValue
            case .insertionSpecifier(let insertionSpecifier): // MARK: .insertionSpecifier
                let parentValue: RT_Object = try {
                    if let parent = insertionSpecifier.parent {
                        return try runPrimary(parent)
                    } else {
                        return builtin.target
                    }
                }()
                return RT_InsertionSpecifier(self, parent: parentValue, kind: insertionSpecifier.kind)
            case .function(let name, let parameters, let types, let arguments, let body): // MARK: .function
                let evaluatedTypes = try types.map { try $0.map { try runPrimary($0) } }
                let types = evaluatedTypes.map { $0.flatMap { ($0 as? RT_Type)?.value } ?? reflection.types[.item] }
                
                var parameterSignature = RT_Function.ParameterSignature(
                    parameters.enumerated().map { (Reflection.Parameter($0.element.uri), types[$0.offset]) },
                    uniquingKeysWith: { l, r in l }
                )
                let command = reflection.commands[name.uri]
                if !types.isEmpty {
                    parameterSignature[command.parameters[.direct]] = types[0]
                }
                let signature = RT_Function.Signature(command: command, parameters: parameterSignature)
                
                let implementation = RT_ExpressionImplementation(self, formalParameters: parameters, formalArguments: arguments, body: body)
                
                let function = RT_Function(self, signature: signature, implementation: implementation)
                builtin.moduleStack.add(function: function)
                    
                return lastResult
            case .block(let arguments, let body): // MARK: .block
                let command = reflection.commands[.run]
                let blockSignature = RT_Function.Signature(
                    command: command,
                    parameters: [command.parameters[.direct]: reflection.types[.list]]
                )
                let implementation = RT_BlockImplementation(
                    self,
                    formalArguments: arguments,
                    body: body
                )
                return RT_Function(self, signature: blockSignature, implementation: implementation)
            case .multilineString(_, let body): // MARK: .multilineString
                return RT_String(self, value: body)
            case .weave(let hashbang, let body): // MARK: .weave
                if hashbang.isEmpty {
                    return lastResult
                } else {
                    return builtin.runWeave(hashbang.invocation, body, lastResult)
                }
            case .debugInspectTerm(_, let message):
                return RT_String(self, value: message)
            case .debugInspectLexicon(let message):
                return RT_String(self, value: message)
            }
        } catch where !(error is RuntimeError || error is EarlyReturn) {
            throw RuntimeError(description: error.localizedDescription, location: currentLocation ?? expression.location)
        }
    }
    
    private func buildSpecifier(_ specifier: Specifier) throws -> RT_Object {
        let parent = try specifier.parent.map { try runPrimary($0, evaluateSpecifiers: false) }
        let termURI = specifier.term.uri
        func generate() throws -> RT_Specifier {
            if case .property = specifier.kind {
                return RT_Specifier(self, parent: parent, kind: .property(reflection.properties[termURI]))
            }
            
            let form: RT_Specifier.Kind.Element.Form = try {
                switch specifier.kind {
                case let .simple(data):
                    return try .simple(runPrimary(data))
                case let .index(index):
                    return try .index(runPrimary(index))
                case let .name(name):
                    return try .name(runPrimary(name))
                case let .id(id):
                    return try .id(runPrimary(id))
                case .all:
                    return .all
                case .first:
                    return .first
                case .middle:
                    return .middle
                case .last:
                    return .last
                case .random:
                    return .random
                case .previous:
                    return .previous
                case .next:
                    return .next
                case let .range(from, thru):
                    return try .range(from: runPrimary(from), thru: runPrimary(thru))
                case let .test(predicate, _):
                    return try .test(runPrimary(predicate))
                case .property:
                    fatalError("unreachable")
                }
            }()
            let element = RT_Specifier.Kind.Element(type: reflection.types[termURI], form: form)
            return RT_Specifier(self, parent: parent, kind: .element(element))
        }
        
        let resultValue = try generate()
        return (specifier.parent == nil) ?
            builtin.qualifySpecifier(resultValue) :
            resultValue
    }
    
    private func runTestComponent(_ testComponent: TestComponent) throws -> RT_Object {
        switch testComponent {
        case let .expression(expression):
            return try runPrimary(expression, evaluateSpecifiers: false)
        case let .predicate(predicate):
            let lhsValue = try runTestComponent(predicate.lhs)
            let rhsValue = try runTestComponent(predicate.rhs)
            return builtin.newTestSpecifier(predicate.operation, lhsValue, rhsValue)
        }
    }
    
    private func evaluatingSpecifier(_ object: RT_Object) throws -> RT_Object {
        try builtin.evaluateSpecifier(object)
    }
    
}
