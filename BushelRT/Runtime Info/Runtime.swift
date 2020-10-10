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

public class Runtime {
    
    public struct RuntimeError: CodableLocalizedError {
        
        /// The error message as formatted during init.
        public let description: String
        
        public var errorDescription: String? {
            description
        }
        
    }
    
    var options = CodeGenOptions(stackIntrospectability: false)
    var builtin: Builtin!
    
    public let termPool = TermPool()
    public let topScript: RT_Script
    public var global: RT_Global!
    
    private let objectPool = NSMapTable<RT_Object, NSNumber>(keyOptions: [.strongMemory, .objectPointerPersonality], valueOptions: .copyIn)
    
    public var currentApplicationBundleID: String?
    
    public init(scriptName: String? = nil, currentApplicationBundleID: String? = nil) {
        self.topScript = RT_Script(name: scriptName)
        self.currentApplicationBundleID = currentApplicationBundleID
        self.global = nil
        self.global = RT_Global(self)
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
    
    public func retain(_ object: RT_Object) {
        var retainCount = objectPool.object(forKey: object)?.intValue ?? 0
        retainCount += 1
        objectPool.setObject(retainCount as NSNumber, forKey: object)
    }
    
    public func release(_ object: RT_Object) {
        guard var retainCount = objectPool.object(forKey: object)?.intValue else {
            os_log("Warning: runtime object overreleased", log: log)
            return
        }
        retainCount -= 1
        if retainCount > 0 {
            objectPool.setObject(retainCount as NSNumber, forKey: object)
        } else {
            objectPool.removeObject(forKey: object)
        }
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

        builtin.stack.pushErrorHandler { message, rt in
            throw RuntimeError(description: message)
        }
        
        let result = try runPrimary(expression, lastResult: ExprValue(expression, RT_Null.null), target: ExprValue(expression, global))
        os_log("Execution result: %@", log: log, type: .debug, String(describing: result))
        return result
    }
    
    private struct EarlyReturn: Error {
        
        var value: RT_Object
        
    }
    
    private func runPrimary(_ expression: Expression, lastResult: ExprValue, target: ExprValue, evaluateSpecifiers: Bool = true) throws -> RT_Object {
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
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try runPrimary(condition, lastResult: lastResult, target: target)
            
            if builtin.isTruthy(toOpaque(conditionValue)) {
                return try runPrimary(then, lastResult: lastResult, target: target)
            } else if let else_ = else_ {
                return try runPrimary(else_, lastResult: lastResult, target: target)
            } else {
                return try evaluate(lastResult, lastResult: lastResult, target: target)
            }
        case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
            var repeatResult: RT_Object?
            while builtin.isTruthy(toOpaque(try runPrimary(condition, lastResult: lastResult, target: target))) {
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
            let timesValue = try runPrimary(times, lastResult: lastResult, target: target)
            
            var repeatResult: RT_Object?
            var count = 0
            while builtin.isTruthy(builtin.binaryOp(Int64(BinaryOperation.less.rawValue), toOpaque(RT_Integer(value: count)), toOpaque(timesValue))) {
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
                count += 1
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .repeatFor(let variable, let container, let repeating): // MARK: .repeatFor
            let containerValue = try runPrimary(container, lastResult: lastResult, target: target)
            let timesValue = try builtin.getSequenceLength(toOpaque(containerValue))
            
            var repeatResult: RT_Object?
            var count = 0
            while builtin.isTruthy(builtin.binaryOp(Int64(BinaryOperation.less.rawValue), toOpaque(RT_Integer(value: count)), toOpaque(timesValue))) {
                let elementValue = try builtin.getFromSequenceAtIndex(toOpaque(containerValue), Int64(count))
                builtin.newVariable(toOpaque(variable), elementValue)
                repeatResult = try runPrimary(repeating, lastResult: lastResult, target: target)
                count += 1
            }
            return try repeatResult ?? evaluate(lastResult, lastResult: lastResult, target: target)
        case .tell(let newTarget, let to): // MARK: .tell
            let newTargetValue = try mapEval(ExprValue(newTarget), lastResult: lastResult, target: target, evaluateSpecifiers: false)
            return try runPrimary(to, lastResult: lastResult, target: newTargetValue)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialExprValue = try initialValue.map { try runPrimary($0, lastResult: lastResult, target: target) } ?? RT_Null.null
            builtin.newVariable(toOpaque(term), toOpaque(initialExprValue))
            return initialExprValue
        case .define(_, as: _): // MARK: .define
            return try evaluate(lastResult, lastResult: lastResult, target: target)
        case .defining(_, as: _, body: let body): // MARK: .defining
            return try runPrimary(body, lastResult: lastResult, target: target)
        case .return_(let returnValue): // MARK: .return_
            let returnExprValue = try returnValue.map { try runPrimary($0, lastResult: lastResult, target: target) } ?? RT_Null.null
            throw EarlyReturn(value: returnExprValue)
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
            return RT_Record(contents:
                [RT_Object : RT_Object](
                    try keyValues.map {
                        try (
                            runPrimary($0.key, lastResult: lastResult, target: target, evaluateSpecifiers: false),
                            runPrimary($0.value, lastResult: lastResult, target: target)
                        )
                    },
                    uniquingKeysWith: {
                        builtin.isTruthy(builtin.binaryOp(Int64(BinaryOperation.greater.rawValue), toOpaque($1), toOpaque($0))) ? $1 : $0
                    }
                )
            )
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            let operandValue = try runPrimary(operand, lastResult: lastResult, target: target)
            return fromOpaque(builtin.unaryOp(Int64(operation.rawValue), toOpaque(operandValue))) as! RT_Object
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            let lhsValue = try runPrimary(lhs, lastResult: lastResult, target: target)
            let rhsValue = try runPrimary(rhs, lastResult: lastResult, target: target)
            return fromOpaque(builtin.binaryOp(Int64(operation.rawValue), toOpaque(lhsValue), toOpaque(rhsValue))) as! RT_Object
        case .variable(let term): // MARK: .variable
            return fromOpaque(builtin.getVariableValue(toOpaque(term))) as! RT_Object
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            return fromOpaque(builtin.getResource(toOpaque(term))) as! RT_Object
        case .enumerator(let term as Term): // MARK: .enumerator
            return fromOpaque(builtin.newConstant(toOpaque(RT_String(value: term.typedUID.normalized)))) as! RT_Object
        case .class_(let term as Term): // MARK: .class_
            return fromOpaque(builtin.newClass(toOpaque(RT_String(value: term.typedUID.normalized)))) as! RT_Object
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueExprValue = try runPrimary(newValueExpression, lastResult: lastResult, target: target)
                _ = builtin.setVariableValue(toOpaque(variableTerm), toOpaque(newValueExprValue))
                return newValueExprValue
            } else {
                let directParameterUIDExprValue = RT_String(value: TypedTermUID(ParameterUID.direct).normalized)
                let setToParameterUIDExprValue = RT_String(value: TypedTermUID(ParameterUID.set_to).normalized)
                
                let expressionExprValue = try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
                let newValueExprValue = try runPrimary(newValueExpression, lastResult: lastResult, target: target)
                
                let arguments = builtin.newArgumentRecord()
                builtin.addToArgumentRecord(arguments, toOpaque(directParameterUIDExprValue), toOpaque(expressionExprValue))
                builtin.addToArgumentRecord(arguments, toOpaque(setToParameterUIDExprValue), toOpaque(newValueExprValue))
                
                let command = self.command(forUID: TypedTermUID(CommandUID.set))
                
                return fromOpaque(try builtin.runCommand(toOpaque(command), arguments, toOpaque(evaluate(target, lastResult: lastResult, target: target)))) as! RT_Object
            }
            
        case .command(let term, let parameters): // MARK: .command
            let parameterExprValues: [(uid: RT_Object, value: RT_Object)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let uidExprValue = RT_String(value: parameterTerm.typedUID.normalized)
                let valueExprValue = try runPrimary(parameterValue, lastResult: lastResult, target: target)
                return (uidExprValue, valueExprValue)
            }
            
            let arguments = builtin.newArgumentRecord()
            for parameter in parameterExprValues {
                builtin.addToArgumentRecord(arguments, toOpaque(parameter.uid), toOpaque(parameter.value))
            }
            
            let command = self.command(forUID: term.typedUID)
            return fromOpaque(try builtin.runCommand(toOpaque(command), arguments, toOpaque(evaluate(target, lastResult: lastResult, target: target)))) as! RT_Object
        case .reference(let expression): // MARK: .reference
            return try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try evaluatingSpecifier(runPrimary(expression, lastResult: lastResult, target: target))
        case .specifier(let specifier): // MARK: .specifier
            let specifierExprValue = try runSpecifier(specifier, lastResult: lastResult, target: target)
            return evaluateSpecifiers ? try evaluatingSpecifier(specifierExprValue) : specifierExprValue
        case .function(let name, let parameters, let arguments, let body): // MARK: .function
//            let commandInfo = self.command(forUID: TypedTermUID(.command, name.uid))
//
//            let functionLLVMName = llvmify(name.name!)
//            let argumentsIRTypes = [PointerType.toVoid]
//
//            let function = builder.addFunction(functionLLVMName, type: FunctionType(argumentsIRTypes, PointerType.toVoid))
//            let entry = function.appendBasicBlock(named: "entry")
//            builder.positionAtEnd(of: entry)
//
//            let actualArguments = function.parameter(at: 0)!
//
//            for (index, (parameter, argument)) in zip(parameters, arguments).enumerated() {
//                // This special-cases the first argument to allow it to fall back
//                // on the value of the direct parameter.
//                //
//                // e.g.,
//                //     to cat: l, with r
//                //         l & r
//                //     end
//                //     cat "hello, " with "world"
//                //
//                //  l = "hello" even though it's not explicitly specified.
//                //  Without this special-case, the call would have to be:
//                //     cat l "hello, " with "world"
//                let getFunction: BuiltinFunction = (index == 0) ? .getFromArgumentRecordWithDirectParamFallback : .getFromArgumentRecord
//
//                let parameterUIDExprValue = parameter.typedUID.normalizedAsRTString(builder: builder, name: "parameter-uid")
//                let argumentValueExprValue = builder.buildCall(toExternalFunction: getFunction, args: [bp, actualArguments, parameterUIDExprValue])
//                let argumentTermExprValue = argument.irPointerValue(builder: builder)
//                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, argumentTermExprValue, argumentValueExprValue])
//            }
//
//            try returningResult() {
//                try body.generateLLVMIR(lastResult: builder.rtNull, target: rt.global.irPointerValue(builder: builder))
//            }
//
//            builder.positionAtEnd(of: lastBlock)
//
//            let commandInfoIRPointer = commandInfo.irPointerValue(builder: builder)
//            let functionIRPointer = builder.buildBitCast(function, type: PointerType.toVoid)
//
//            _ = builder.buildCall(toExternalFunction: .newFunction, args: [bp, commandInfoIRPointer, functionIRPointer, builder.rtNull])
//
            return try evaluate(lastResult, lastResult: lastResult, target: target)
        case .multilineString(_, let body): // MARK: .multilineString
            return RT_String(value: body)
        case .weave(let hashbang, let body): // MARK: .weave
            let hashbangRTString = RT_String(value: hashbang.invocation)
            let bodyRTString = RT_String(value: body)
            return fromOpaque(builtin.runWeave(toOpaque(hashbangRTString), toOpaque(bodyRTString), toOpaque(try evaluate(lastResult, lastResult: lastResult, target: target)))) as! RT_Object
        }
    }
    
    private func runSpecifier(_ specifier: Specifier, lastResult: ExprValue, target: ExprValue) throws -> RT_Object {
        let uidValue_ = RT_String(value: specifier.idTerm.typedUID.normalized)
        let uidValue = toOpaque(uidValue_)
        
        let parentValue_ = try specifier.parent.map { try runPrimary($0, lastResult: lastResult, target: target, evaluateSpecifiers: false) }
        let parentValue = parentValue_.map { toOpaque($0) }
        
        let dataExpressionValues: [RT_Object]
        if case .test(_, let testComponent) = specifier.kind {
            dataExpressionValues = [try runTestComponent(testComponent, lastResult: lastResult, target: target)]
        } else {
            dataExpressionValues = try specifier.allDataExpressions().map { dataExpression in
                try runPrimary(dataExpression, lastResult: lastResult, target: target)
            }
        }
        
        func generate() -> Builtin.RTObjectPointer {
            switch specifier.kind {
            case .simple:
                return builtin.newSpecifier1(parentValue, uidValue, UInt32(RT_Specifier.Kind.simple.rawValue), toOpaque(dataExpressionValues[0]))
            case .index:
                return builtin.newSpecifier1(parentValue, uidValue, UInt32(RT_Specifier.Kind.index.rawValue), toOpaque(dataExpressionValues[0]))
            case .name:
                return builtin.newSpecifier1(parentValue, uidValue, UInt32(RT_Specifier.Kind.name.rawValue), toOpaque(dataExpressionValues[0]))
            case .id:
                return builtin.newSpecifier1(parentValue, uidValue, UInt32(RT_Specifier.Kind.id.rawValue), toOpaque(dataExpressionValues[0]))
            case .all:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.all.rawValue))
            case .first:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.first.rawValue))
            case .middle:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.middle.rawValue))
            case .last:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.last.rawValue))
            case .random:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.random.rawValue))
            case .previous:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.previous.rawValue))
            case .next:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.next.rawValue))
            case .range:
                return builtin.newSpecifier2(parentValue, uidValue, UInt32(RT_Specifier.Kind.range.rawValue), toOpaque(dataExpressionValues[0]), toOpaque(dataExpressionValues[1]))
            case .test:
                return builtin.newSpecifier1(parentValue, uidValue, UInt32(RT_Specifier.Kind.test.rawValue), toOpaque(dataExpressionValues[0]))
            case .property:
                return builtin.newSpecifier0(parentValue, uidValue, UInt32(RT_Specifier.Kind.property.rawValue))
            }
        }
        
        let resultValue = fromOpaque(generate()) as! RT_Object
        return (specifier.parent == nil) ?
            fromOpaque(builtin.qualifySpecifier(toOpaque(resultValue), toOpaque(try evaluate(target, lastResult: lastResult, target: target)))) as! RT_Object :
            resultValue
    }
    
    private func runTestComponent(_ testComponent: TestComponent, lastResult: ExprValue, target: ExprValue) throws -> RT_Object {
        switch testComponent {
        case let .expression(expression):
            return try runPrimary(expression, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case let .predicate(predicate):
            let lhsValue = try runTestComponent(predicate.lhs, lastResult: lastResult, target: target)
            let rhsValue = try runTestComponent(predicate.rhs, lastResult: lastResult, target: target)
            return fromOpaque(builtin.newTestSpecifier(UInt32(predicate.operation.rawValue), toOpaque(lhsValue), toOpaque(rhsValue))) as! RT_Object
        }
    }
    
    private func evaluatingSpecifier(_ object: RT_Object) throws -> RT_Object {
        fromOpaque(try builtin.evaluateSpecifier(toOpaque(object))) as! RT_Object
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
