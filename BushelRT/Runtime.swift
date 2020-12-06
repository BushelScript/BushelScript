import Bushel
import os

private let log = OSLog(subsystem: logSubsystem, category: "Runtime")

public struct CodeGenOptions {
    
    /// Whether the stack should be runtime-introspectable.
    /// Generates push and pop runtime calls, and forces all variables to be
    /// tracked dynamically.
    /// For end-user debugging purposes.
    public let stackIntrospectability: Bool
    
}

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

public struct InFlightRuntimeError: Error {
    
    /// The error message as formatted during init.
    public let description: String
    
}

public class Runtime {
    
    var options = CodeGenOptions(stackIntrospectability: false)
    var builtin: Builtin!
    
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
    
    public let termPool = TermPool()
    public let topScript: RT_Script
    public var global: RT_Global!
    
    public var currentApplicationBundleID: String?
    
    public init(scriptName: String? = nil, currentApplicationBundleID: String? = nil) {
        self.topScript = RT_Script(name: scriptName)
        self.currentApplicationBundleID = currentApplicationBundleID
        self.global = nil
        self.global = RT_Global()
    }
    
    public func inject(terms: TermPool) {
        func add(classTerm term: Bushel.ClassTerm) {
            func typeInfo(for classTerm: Bushel.ClassTerm) -> TypeInfo {
                var tags: Set<TypeInfo.Tag> = []
                if let name = classTerm.name {
                    tags.insert(.name(name))
                }
                if let supertype = classTerm.parentClass.map({ typeInfo(for: $0) }) {
                    tags.insert(.supertype(supertype))
                }
                return TypeInfo(classTerm.uid, tags)
            }
            
            let type = typeInfo(for: term)
            typesByUID[type.typedUID] = type
            if let supertype = type.supertype {
                if typesBySupertype[supertype] == nil {
                    typesBySupertype[supertype] = []
                }
                typesBySupertype[supertype]!.append(type)
            }
            if let name = term.name {
                typesByName[name] = type
            }
        }
        
        termPool.add(terms)
        
        for term in terms.byTypedUID.values {
            switch term.enumerated {
            case .dictionary(_):
                break
            case .class_(let term):
                add(classTerm: term)
            case .pluralClass(let term):
                add(classTerm: term)
            case .property(let term):
                let tags: [PropertyInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let property = PropertyInfo(term.uid, Set(tags))
                propertiesByUID[property.typedUID] = property
            case .enumerator(let term):
                let tags: [ConstantInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let constant = ConstantInfo(term.uid, Set(tags))
                constantsByUID[constant.typedUID] = constant
            case .command(let term):
                let tags: [CommandInfo.Tag] = term.name.map { [.name($0)] } ?? []
                let command = CommandInfo(term.uid, Set(tags))
                commandsByUID[command.typedUID] = command
            case .parameter(_):
                break
            case .variable(_):
                break
            case .resource(_):
                break
            }
        }
    }
    
    private var typesByUID: [TypedTermUID : TypeInfo] = [:]
    private var typesBySupertype: [TypeInfo : [TypeInfo]] = [:]
    private var typesByName: [TermName : TypeInfo] = [:]
    
    private func add(forTypeUID uid: TermUID) -> TypeInfo {
        let info = TypeInfo(uid)
        typesByUID[TypedTermUID(.type, uid)] = info
        return info
    }
    
    public func type(forUID uid: TypedTermUID) -> TypeInfo {
        typesByUID[uid] ?? TypeInfo(uid.uid)
    }
    public func subtypes(of type: TypeInfo) -> [TypeInfo] {
        typesBySupertype[type] ?? []
    }
    public func type(for name: TermName) -> TypeInfo? {
        typesByName[name]
    }
    public func type(for code: OSType) -> TypeInfo {
        type(forUID: TypedTermUID(.type, .ae4(code: code)))
    }
    
    private var propertiesByUID: [TypedTermUID : PropertyInfo] = [:]
    
    private func add(forPropertyUID uid: TermUID) -> PropertyInfo {
        let info = PropertyInfo(uid)
        propertiesByUID[TypedTermUID(.property, uid)] = info
        return info
    }
    
    public func property(forUID uid: TypedTermUID) -> PropertyInfo {
        propertiesByUID[uid] ?? add(forPropertyUID: uid.uid)
    }
    public func property(for code: OSType) -> PropertyInfo {
        property(forUID: TypedTermUID(.property, .ae4(code: code)))
    }
    
    private var constantsByUID: [TypedTermUID : ConstantInfo] = [:]
    
    private func add(forConstantUID uid: TermUID) -> ConstantInfo {
        let info = ConstantInfo(uid)
        constantsByUID[TypedTermUID(.constant, uid)] = info
        return info
    }
    
    public func constant(forUID uid: TypedTermUID) -> ConstantInfo {
        constantsByUID[uid] ??
            propertiesByUID[TypedTermUID(.property, uid.uid)].map { ConstantInfo(property: $0) } ??
            typesByUID[TypedTermUID(.type, uid.uid)].map { ConstantInfo(type: $0) } ??
            add(forConstantUID: uid.uid)
    }
    public func constant(for code: OSType) -> ConstantInfo {
        constant(forUID: TypedTermUID(.constant, .ae4(code: code)))
    }
    
    private var commandsByUID: [TypedTermUID : CommandInfo] = [:]
    
    private func add(forCommandUID uid: TermUID) -> CommandInfo {
        let info = CommandInfo(uid)
        commandsByUID[TypedTermUID(.command, uid)] = info
        return info
    }
    
    public func command(forUID uid: TypedTermUID) -> CommandInfo {
        commandsByUID[uid] ?? add(forCommandUID: uid.uid)
    }
    
}

public extension Runtime {
    
    func run(_ program: Program) throws -> RT_Object {
        inject(terms: program.terms)
        return try run(program.ast)
    }
    
    func run(_ expression: Expression) throws -> RT_Object {
        builtin = Builtin()
        builtin.rt = self
        
        let result: RT_Object
        do {
            result = try runPrimary(expression, lastResult: ExprValue(expression, RT_Null.null), target: ExprValue(expression, global))
        } catch let earlyReturn as EarlyReturn {
            result = earlyReturn.value
        } catch let inFlightRuntimeError as InFlightRuntimeError {
            throw RuntimeError(description: inFlightRuntimeError.description, location: currentLocation ?? expression.location)
        }
        
        os_log("Execution result: %@", log: log, type: .debug, String(describing: result))
        return result
    }
    
    private struct EarlyReturn: Error {
        
        var value: RT_Object
        
    }
    
    func runFunction(_ functionExpression: Expression, actualArguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        guard case let .function(_, parameters, arguments, body) = functionExpression.kind else {
            preconditionFailure("expected function expression but got \(functionExpression)")
        }
        
        builtin.pushFrame()
        defer {
            builtin.popFrame()
        }
        
        // Create variables for each of the function's parameters.
        for (index, (parameter, argument)) in zip(parameters, arguments).enumerated() {
            // This special-cases the first argument to allow it to fall back
            // on the value of the direct parameter.
            //
            // e.g.,
            //     to cat: l, with r
            //         l & r
            //     end
            //     cat "hello, " with "world"
            //
            //  l = "hello" even though it's not explicitly specified.
            //  Without this special-case, the call would have to be:
            //     cat l "hello, " with "world"
            var argumentValue: RT_Object = RT_Null.null
            if index == 0 {
                argumentValue =
                    actualArguments[ParameterInfo(parameter.uid)] ??
                    actualArguments[ParameterInfo(ParameterUID.direct)] ??
                    RT_Null.null
            } else {
                argumentValue = actualArguments[ParameterInfo(parameter.uid)] ?? RT_Null.null
            }
            
            builtin.newVariable(argument, argumentValue)
        }
        
        do {
            return try runPrimary(body, lastResult: ExprValue(body, RT_Null.null), target: ExprValue(body, global))
        } catch let earlyReturn as EarlyReturn {
            return earlyReturn.value
        }
    }
    
    private func runPrimary(_ expression: Expression, lastResult: ExprValue, target: ExprValue, evaluateSpecifiers: Bool = true) throws -> RT_Object {
        pushLocation(expression.location)
        defer {
            popLocation()
        }
        
        switch expression.kind {
        case .empty, .end, .endWeave: // MARK: .empty, .end, .endWeave
            return try evaluate(lastResult, lastResult: lastResult, target: target)
        case .that: // MARK: .that
            return try
                evaluateSpecifiers ?
                evaluatingSpecifier(evaluate(lastResult, lastResult: lastResult, target: target)) :
                evaluate(lastResult, lastResult: lastResult, target: target)
        case .it: // MARK: .it
            return try
                evaluateSpecifiers ?
                evaluatingSpecifier(evaluate(target, lastResult: lastResult, target: target)) :
                evaluate(target, lastResult: lastResult, target: target)
        case .null: // MARK: .null
            return RT_Null.null
        case .sequence(let expressions): // MARK: .sequence
            return try evaluate(expressions
                .filter { if case .end = $0.kind { return false } else { return true } }
                .reduce(lastResult, { (lastResult, expression) in
                    return try mapEval(ExprValue(expression), lastResult: lastResult, target: target)
                }), lastResult: lastResult, target: target)
        case .scoped(let expression): // MARK: .scoped
            return try runPrimary(expression, lastResult: lastResult, target: target)
        case .parentheses(let expression): // MARK: .parentheses
            return try runPrimary(expression, lastResult: lastResult, target: target)
        case let .try_(body, handle): // MARK: .try_
            do {
                return try runPrimary(body, lastResult: lastResult, target: target)
            } catch {
                return try runPrimary(handle, lastResult: lastResult, target: ExprValue(Expression(.empty, at: SourceLocation(at: handle.location)), RT_Error(error)))
            }
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try runPrimary(condition, lastResult: lastResult, target: target)
            
            if conditionValue.truthy {
                return try runPrimary(then, lastResult: lastResult, target: target)
            } else if let else_ = else_ {
                return try runPrimary(else_, lastResult: lastResult, target: target)
            } else {
                return try evaluate(lastResult, lastResult: lastResult, target: target)
            }
        case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
            var repeatResult: RT_Object?
            while try runPrimary(condition, lastResult: lastResult, target: target).truthy {
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
            let timesValue = try runPrimary(times, lastResult: lastResult, target: target)
            
            var repeatResult: RT_Object?
            var count = 0
            while try builtin.binaryOp(.less, RT_Integer(value: count), timesValue).truthy {
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
                count += 1
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .repeatFor(let variable, let container, let repeating): // MARK: .repeatFor
            let containerValue = try runPrimary(container, lastResult: lastResult, target: target)
            let timesValue = try builtin.getSequenceLength(containerValue)
            
            var repeatResult: RT_Object?
            // 1-based indices wheeeeee
            for count in 1...timesValue {
                let elementValue = try builtin.getFromSequenceAtIndex(containerValue, Int64(count))
                builtin.newVariable(variable, elementValue)
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .tell(let newTarget, let to): // MARK: .tell
            let newTargetValue = try mapEval(ExprValue(newTarget), lastResult: lastResult, target: target, evaluateSpecifiers: false)
            return try runPrimary(to, lastResult: lastResult, target: newTargetValue)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialExprValue = try initialValue.map { try runPrimary($0, lastResult: lastResult, target: target) } ?? RT_Null.null
            builtin.newVariable(term, initialExprValue)
            return initialExprValue
        case .define(_, as: _): // MARK: .define
            return try evaluate(lastResult, lastResult: lastResult, target: target)
        case .defining(_, as: _, body: let body): // MARK: .defining
            return try runPrimary(body, lastResult: lastResult, target: target)
        case .return_(let returnValue): // MARK: .return_
            let returnExprValue = try returnValue.map { try runPrimary($0, lastResult: lastResult, target: target) } ?? RT_Null.null
            throw EarlyReturn(value: returnExprValue)
        case .raise(let error): // MARK: .raise
            let errorValue = try runPrimary(error, lastResult: lastResult, target: target)
            if let errorValue = errorValue as? RT_Error {
                throw errorValue.error
            } else {
                throw RaisedObjectError(error: errorValue, location: expression.location)
            }
        case .integer(let value): // MARK: .integer
            return RT_Integer(value: value)
        case .double(let value): // MARK: .double
            return RT_Real(value: value)
        case .string(let value): // MARK: .string
            return RT_String(value: value)
        case .list(let expressions): // MARK: .list
            return try RT_List(contents:
                expressions.map { try runPrimary($0, lastResult: lastResult, target: target) }
            )
        case .record(let keyValues): // MARK: .record
            return try RT_Record(contents:
                [RT_Object : RT_Object](
                    try keyValues.map {
                        try (
                            runPrimary($0.key, lastResult: lastResult, target: target, evaluateSpecifiers: false),
                            runPrimary($0.value, lastResult: lastResult, target: target)
                        )
                    },
                    uniquingKeysWith: {
                        try builtin.binaryOp(.greater, $1, $0).truthy ? $1 : $0
                    }
                )
            )
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            let operandValue = try runPrimary(operand, lastResult: lastResult, target: target)
            return builtin.unaryOp(operation, operandValue)
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            let lhsValue = try runPrimary(lhs, lastResult: lastResult, target: target)
            let rhsValue = try runPrimary(rhs, lastResult: lastResult, target: target)
            return try builtin.binaryOp(operation, lhsValue, rhsValue)
        case .variable(let term): // MARK: .variable
            return builtin.getVariableValue(term)
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            return builtin.getResource(term)
        case .enumerator(let term as Term): // MARK: .enumerator
            return builtin.newConstant(term.typedUID)
        case .class_(let term as Term): // MARK: .class_
            return RT_Class(value: type(forUID: term.typedUID))
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueExprValue = try runPrimary(newValueExpression, lastResult: lastResult, target: target)
                _ = builtin.setVariableValue(variableTerm, newValueExprValue)
                return newValueExprValue
            } else {
                let expressionExprValue = try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
                let newValueExprValue = try runPrimary(newValueExpression, lastResult: lastResult, target: target)
                
                let arguments: [ParameterInfo : RT_Object] = [
                    ParameterInfo(.direct): expressionExprValue,
                    ParameterInfo(.set_to): newValueExprValue
                ]
                let command = self.command(forUID: TypedTermUID(CommandUID.set))
                return try builtin.run(command: command, arguments: arguments, target: evaluate(target, lastResult: lastResult, target: target))
            }
        case .command(let term, let parameters): // MARK: .command
            let parameterExprValues: [(key: ParameterInfo, value: RT_Object)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let parameterInfo = ParameterInfo(parameterTerm.uid)
                let value = try runPrimary(parameterValue, lastResult: lastResult, target: target)
                return (parameterInfo, value)
            }
            let arguments = [ParameterInfo : RT_Object](uniqueKeysWithValues:
                parameterExprValues
            )
            let command = self.command(forUID: term.typedUID)
            return try builtin.run(command: command, arguments: arguments, target: evaluate(target, lastResult: lastResult, target: target))
        case .reference(let expression): // MARK: .reference
            return try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try evaluatingSpecifier(runPrimary(expression, lastResult: lastResult, target: target))
        case .specifier(let specifier): // MARK: .specifier
            let specifierValue = try buildSpecifier(specifier, lastResult: lastResult, target: target)
            return evaluateSpecifiers ? try evaluatingSpecifier(specifierValue) : specifierValue
        case .insertionSpecifier(let insertionSpecifier): // MARK: .insertionSpecifier
            let parentValue: RT_Object = try {
                if let parent = insertionSpecifier.parent {
                    return try runPrimary(parent, lastResult: lastResult, target: target)
                } else {
                    return try evaluate(target, lastResult: lastResult, target: target)
                }
            }()
            return RT_InsertionSpecifier(parent: parentValue, kind: insertionSpecifier.kind)
        case .function(let name, _, _, _): // MARK: .function
            let commandInfo = self.command(forUID: TypedTermUID(.command, name.uid))
            
            let function = RT_Function(self, expression)
            topScript.dynamicFunctions[commandInfo] = function
                
            return try evaluate(lastResult, lastResult: lastResult, target: target)
        case .multilineString(_, let body): // MARK: .multilineString
            return RT_String(value: body)
        case .weave(let hashbang, let body): // MARK: .weave
            return builtin.runWeave(hashbang.invocation, body, try evaluate(lastResult, lastResult: lastResult, target: target))
        }
    }
    
    private func buildSpecifier(_ specifier: Specifier, lastResult: ExprValue, target: ExprValue) throws -> RT_Object {
        let typedUID = specifier.idTerm.typedUID
        
        let parent = try specifier.parent.map { try runPrimary($0, lastResult: lastResult, target: target, evaluateSpecifiers: false) }
        
        let data: [RT_Object]
        if case .test(_, let testComponent) = specifier.kind {
            data = [try runTestComponent(testComponent, lastResult: lastResult, target: target)]
        } else {
            data = try specifier.allDataExpressions().map { dataExpression in
                try runPrimary(dataExpression, lastResult: lastResult, target: target)
            }
        }
        
        func generate() -> RT_Specifier {
            if case .property = specifier.kind {
                return RT_Specifier(parent: parent, type: nil, property: property(forUID: typedUID), data: [], kind: .property)
            }
            
            let kind: RT_Specifier.Kind = {
                switch specifier.kind {
                case .simple:
                    return .simple
                case .index:
                    return .index
                case .name:
                    return .name
                case .id:
                    return .id
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
                case .range:
                    return .range
                case .test:
                    return .test
                case .property:
                    fatalError("unreachable")
                }
            }()
            return RT_Specifier(parent: parent, type: type(forUID: typedUID), data: data, kind: kind)
        }
        
        let resultValue = generate()
        return (specifier.parent == nil) ?
            builtin.qualifySpecifier(resultValue, try evaluate(target, lastResult: lastResult, target: target)) :
            resultValue
    }
    
    private func runTestComponent(_ testComponent: TestComponent, lastResult: ExprValue, target: ExprValue) throws -> RT_Object {
        switch testComponent {
        case let .expression(expression):
            return try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case let .predicate(predicate):
            let lhsValue = try runTestComponent(predicate.lhs, lastResult: lastResult, target: target)
            let rhsValue = try runTestComponent(predicate.rhs, lastResult: lastResult, target: target)
            return builtin.newTestSpecifier(predicate.operation, lhsValue, rhsValue)
        }
    }
    
    private func evaluatingSpecifier(_ object: RT_Object) throws -> RT_Object {
        try builtin.evaluateSpecifier(object)
    }
    
}

extension Runtime {
    
    func evaluate(_ exprValue: ExprValue, lastResult: ExprValue, target: ExprValue, evaluateSpecifiers: Bool = true) throws -> RT_Object {
        if let value = exprValue.value {
            return value
        }
        
        let value = try runPrimary(exprValue.expression, lastResult: lastResult, target: target, evaluateSpecifiers: evaluateSpecifiers)
        exprValue.value = value
        return value
    }
    
    func mapEval(_ exprValue: ExprValue, lastResult: ExprValue, target: ExprValue, evaluateSpecifiers: Bool = true) throws -> ExprValue {
        ExprValue(exprValue.expression, try evaluate(exprValue, lastResult: lastResult, target: target, evaluateSpecifiers: evaluateSpecifiers))
    }
    
}

class ExprValue {
    
    var expression: Expression
    var value: RT_Object?
    
    init(_ expression: Expression, _ value: RT_Object? = nil) {
        self.expression = expression
        self.value = value
    }
    
}
