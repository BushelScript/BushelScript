import Bushel
import LLVM
import cllvm
import os

private let log = OSLog(subsystem: logSubsystem, category: "LLVM IR gen")

extension IRBuilder {
    
    /// A pointer IRValue to the singleton instance of `RT_Null`.
    var rtNull: IRValue {
        return buildLoad(module.global(named: "rt_null")!, type: PointerType.toVoid)
    }
    
}

extension IRBuilder {
    
    /// `FnPtr` **must** be `@convention(c)`.
    func addExternalFunctionAsGlobal<FnPtr>(_ fnPtr: FnPtr, _ function: BuiltinFunction) {
        return addExternalFunctionAsGlobal(fnPtr, name: function.runtimeName, type: function.runtimeType)
    }
    
    /// `FnPtr` **must** be `@convention(c)`.
    func addExternalFunctionAsGlobal<FnPtr>(_ fnPtr: FnPtr, name: String, type: FunctionType) {
        let fnAddress = unsafeBitCast(fnPtr, to: uintptr_t.self)
        let pointerType = PointerType(pointee: type)
        let pointerIRValue = buildIntToPtr(IntType.int64.constant(fnAddress), type: pointerType)
        addGlobal(name, type: pointerType).initializer = pointerIRValue
    }
    
    func buildCall(toExternalFunctionReturningVoid function: BuiltinFunction, args: [IRValue]) {
        precondition(LLVMGetTypeKind(function.runtimeType.returnType.asLLVM()) == LLVMVoidTypeKind)
        _ = buildCall(toExternalFunction: function, args: args, name: "")
    }
    
    func buildCall(toExternalFunction function: BuiltinFunction, args: [IRValue], name: String? = nil) -> Call {
        precondition(args.count == function.runtimeType.parameterTypes.count)
        return buildCallToExternalFunction(named: function.runtimeName, type: function.runtimeType, args: args, name: name ?? function.rawValue)
    }
    
    func buildCallToExternalFunction(named fnName: String, type fnType: FunctionType, args: [IRValue], name: String = "") -> Call {
        let fnPointerValue = buildLoad(module.global(named: fnName)!, type: PointerType(pointee: fnType), name: fnName)
        return buildCall(fnPointerValue, args: args, name: name)
    }
    
}

/// Creates an LLVM module and propagates it with necessary runtime facilities,
/// then generates an IR program from the given expression.
///
/// - Parameter expression: The expression from which to generate an LLVM IR program.
/// - Returns: The completed LLVM module.
func generateLLVMModule(from expression: Expression, builtin: Builtin) -> Module {
    let module = Module(name: "main")
    let builder = IRBuilder(module: module)
    let diBuilder = DIBuilder(module: module)
    
    let rtNullPointer = Builtin.toOpaque(RT_Null.null)
    module.addGlobal("rt_null", type: PointerType.toVoid).initializer = builder.buildIntToPtr(IntType.int64.constant(Int(bitPattern: rtNullPointer)), type: .toVoid)
    
    let rt = builtin.rt
    let bp = builtin.irPointerValue(builder: builder)
    
    let main = builder.addFunction("main", type: FunctionType([], PointerType.toVoid))
    let bootstrap = main.appendBasicBlock(named: "bootstrap")
    builder.positionAtEnd(of: bootstrap)
    
    let function = builder.addFunction("run", type: FunctionType([], PointerType.toVoid))
    let functionIRPointer = builder.buildBitCast(function, type: PointerType.toVoid)
    let commandInfoIRPointer = rt.command(forUID: TypedTermUID(CommandUID.run)).irPointerValue(builder: builder)
    
    _ = builder.buildCall(toExternalFunction: .newFunction, args: [bp, commandInfoIRPointer, functionIRPointer, builder.rtNull])
    
    let entry = function.appendBasicBlock(named: "entry")
    
    let returnValue = builder.buildCall(function, args: [])
    builder.buildRet(returnValue)
    
    builder.positionAtEnd(of: entry)
    do {
        try returningResult(builder, diBuilder) {
            try expression.generateLLVMIR(builder, diBuilder, builtin, options: CodeGenOptions(stackIntrospectability: false), lastResult: builder.rtNull, target: rt.global.irPointerValue(builder: builder))
        }
    } catch {
        fatalError("unhandled error \(error)")
    }
    
    if
        let dump = ProcessInfo.processInfo.environment["BUSHEL_DUMP_LLVM"],
        ["1", "true", "t", "yes", "y"].contains(dump.lowercased())
    {
        module.dump()
    }
    
    return module
}

private struct EarlyReturn: Error {
    
    var value: IRValue
    
}

private func returningResult(_ builder: IRBuilder, _ diBuilder: DIBuilder, from action: () throws -> IRValue) rethrows {
    let resultValue: IRValue
    do {
        resultValue = try action()
    } catch let earlyReturn as EarlyReturn {
        resultValue = earlyReturn.value
    }
    builder.buildRet(resultValue)
}

private func catchingEarlyReturn(_ builder: IRBuilder, _ diBuilder: DIBuilder, branchingTo nextBlock: BasicBlock, from action: () throws -> IRValue) rethrows -> IRValue {
    try catchingEarlyReturn(builder, diBuilder, branching: { builder.buildBr(nextBlock) }, from: action)
}

private func catchingEarlyReturn(_ builder: IRBuilder, _ diBuilder: DIBuilder, branching: () throws -> Void, from action: () throws -> IRValue) rethrows -> IRValue {
    let resultValue: IRValue
    do {
        resultValue = try action()
    } catch let earlyReturn as EarlyReturn {
        builder.buildRet(earlyReturn.value)
        return PointerType.toVoid.undef()
    }
    try branching()
    return resultValue
}

extension Expression {
    
    /// Recursively builds an LLVM IR program out of this expression.
    ///
    /// - Parameters:
    ///   - builder: The `IRBuilder` to use.
    ///   - options: A set of options that control how the code is generated.
    ///   - lastResult: The last result produced by the program. This value
    ///                 is produced by the `that` keyword. Also, if no value
    ///                 is produced by this expression, `lastResult`
    ///                 is returned back.
    ///   - target: The current default target.
    ///   - evaluateSpecifiers: Whether specifiers should be evaluated by
    ///                         default. Subsequent recursive calls ignore
    ///                         the current setting.
    /// - Returns: The resultant `IRValue` from building the code for this
    ///            expression.
   func generateLLVMIR(_ builder: IRBuilder, _ diBuilder: DIBuilder, _ builtin: Builtin, options: CodeGenOptions, lastResult: IRValue, target: IRValue, evaluateSpecifiers: Bool = true) throws -> IRValue {
        let rt = builtin.rt
        let bp = builtin.irPointerValue(builder: builder)
        
        let lastBlock = builder.insertBlock!
        let function = lastBlock.parent!
        
        switch kind {
        case .empty, .end: // MARK: .empty, .end
            return lastResult
        case .that: // MARK: .that
            return
                evaluateSpecifiers ?
                lastResult.evaluatingSpecifier(builder: builder, bp: bp) :
                lastResult
        case .it: // MARK: .it
            return
                evaluateSpecifiers ?
                target.evaluatingSpecifier(builder: builder, bp: bp) :
                target
        case .null: // MARK: .null
            return builder.rtNull
        case .sequence(let expressions): // MARK: .sequence
            return try expressions
                .filter { if case .end = $0.kind { return false } else { return true } }
                .reduce(lastResult, { (lastResult, expression) -> IRValue in
                    guard !lastResult.isAReturnInst else {
                        // We've already returned; generating more code can
                        // confuse phi nodes
                        return lastResult
                    }
                    return try expression
                        .generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                })
        case .scoped(let expression): // MARK: .scoped
            if options.stackIntrospectability {
                builder.buildCall(toExternalFunctionReturningVoid: .pushFrame, args: [bp])
            }
            defer {
                if options.stackIntrospectability {
                    builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [bp])
                }
            }
            
            return try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
        case .parentheses(let expression): // MARK: .parentheses
            return try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try condition.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            
            let conditionTest = builder.buildCall(toExternalFunction: .isTruthy, args: [bp, conditionValue])
            
            let thenBlock = function.appendBasicBlock(named: "then")
            let elseBlock = BasicBlock(context: builder.module.context, name: "else")
            let mergeBlock = BasicBlock(context: builder.module.context, name: "merge")
            
            builder.buildCondBr(condition: conditionTest, then: thenBlock, else: elseBlock)
            
            builder.positionAtEnd(of: thenBlock)
            
            let thenValue = try catchingEarlyReturn(builder, diBuilder, branchingTo: mergeBlock) {
                try then.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            }
            let thenMergeBlock = builder.insertBlock!
            
            function.append(elseBlock)
            builder.positionAtEnd(of: elseBlock)
            
            let elseValue: IRValue
            if let else_ = else_ {
                elseValue = try catchingEarlyReturn(builder, diBuilder, branchingTo: mergeBlock) {
                    try else_.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                }
            } else {
                builder.buildBr(mergeBlock)
                elseValue = lastResult
            }
            let elseMergeBlock = builder.insertBlock!
            
            function.append(mergeBlock)
            builder.positionAtEnd(of: mergeBlock)
            
            let phi = builder.buildPhi(PointerType.toVoid, name: "if-then-else")
            phi.addIncoming([(thenValue, thenMergeBlock), (elseValue, elseMergeBlock)])
            return phi
        case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
            let repeatBlock = function.appendBasicBlock(named: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            func evalConditionAndCondBr() throws {
                let conditionValue = try condition.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                let conditionTest = builder.buildCall(toExternalFunction: .isTruthy, args: [bp, conditionValue])
                
                builder.buildCondBr(condition: conditionTest, then: repeatBlock, else: afterRepeatBlock)
            }
            
            try evalConditionAndCondBr()
            
            builder.positionAtEnd(of: repeatBlock)
            
            let repeatResult = try catchingEarlyReturn(builder, diBuilder, branching: evalConditionAndCondBr) {
                try repeating.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            }
            
            let repeatMergeBlock = builder.insertBlock!
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            let result = builder.buildPhi(PointerType.toVoid, name: "repeat-result-or-that")
            result.addIncoming([(repeatResult, repeatMergeBlock), (lastResult, lastBlock)])
            
            return result
        case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
            let repeatHeaderBlock = function.appendBasicBlock(named: "repeat-header")
            let repeatBlock = function.appendBasicBlock(named: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            let timesValue = try times.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            
            let initialRepeatCount = IntType.int64.constant(1)
            
            builder.buildBr(repeatHeaderBlock)
            builder.positionAtEnd(of: repeatHeaderBlock)
            
            let repeatCount = builder.buildPhi(IntType.int64, name: "repeat-index")
            repeatCount.addIncoming([(initialRepeatCount, lastBlock)])
            let repeatResult = builder.buildPhi(PointerType.toVoid, name: "repeat-result")
            repeatResult.addIncoming([(lastResult, lastBlock)])
            
            func evalConditionAndCondBr() throws {
                let newRepeatCountObj = repeatCount.asRTInteger(builder: builder, bp: bp)
                let repeatCondition = builder.buildCall(toExternalFunction: .isTruthy, args: [
                    bp,
                    builder.buildCall(toExternalFunction: .binaryOp, args: [bp, BinaryOperation.lessEqual.rawValue, newRepeatCountObj, timesValue])
                ])
                builder.buildCall(toExternalFunctionReturningVoid: .release, args: [bp, newRepeatCountObj])
                
                builder.buildCondBr(condition: repeatCondition, then: repeatBlock, else: afterRepeatBlock)
            }
            
            try evalConditionAndCondBr()
            
            builder.positionAtEnd(of: repeatBlock)
            
            _ = try catchingEarlyReturn(builder, diBuilder, branchingTo: repeatHeaderBlock) {
                let repeatMergeBlock = builder.insertBlock!
                
                let newRepeatResult = try repeating.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                repeatResult.addIncoming([(newRepeatResult, repeatMergeBlock)])
                
                let newRepeatCount = builder.buildBinaryOperation(.add, repeatCount, IntType.int64.constant(1), name: "next-repeat-index")
                repeatCount.addIncoming([(newRepeatCount, builder.insertBlock!)])
                
                return newRepeatResult
            }
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            return repeatResult
        case .repeatFor(let variable, let container, let repeating): // MARK: .repeatFor
            let repeatHeaderBlock = function.appendBasicBlock(named: "repeat-header")
            let repeatBlock = function.appendBasicBlock(named: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            let containerIRValue = try container.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            
            let lengthIRValue = builder.buildCall(toExternalFunction: .getSequenceLength, args: [bp, containerIRValue]).asRTInteger(builder: builder, bp: bp)
            
            let initialRepeatCount = IntType.int64.constant(1)
            
            builder.buildBr(repeatHeaderBlock)
            builder.positionAtEnd(of: repeatHeaderBlock)
            
            let repeatCount = builder.buildPhi(IntType.int64, name: "repeat-index")
            repeatCount.addIncoming([(initialRepeatCount, lastBlock)])
            let repeatResult = builder.buildPhi(PointerType.toVoid, name: "repeat-result")
            repeatResult.addIncoming([(lastResult, lastBlock)])
            
            func evalConditionAndCondBr() throws {
                let newRepeatCountObj = repeatCount.asRTInteger(builder: builder, bp: bp)
                let repeatCondition = builder.buildCall(toExternalFunction: .isTruthy, args: [
                    bp,
                    builder.buildCall(toExternalFunction: .binaryOp, args: [bp, BinaryOperation.lessEqual.rawValue, newRepeatCountObj, lengthIRValue])
                ])
                builder.buildCall(toExternalFunctionReturningVoid: .release, args: [bp, newRepeatCountObj])
                
                builder.buildCondBr(condition: repeatCondition, then: repeatBlock, else: afterRepeatBlock)
            }
            
            try evalConditionAndCondBr()
            
            builder.positionAtEnd(of: repeatBlock)
            
            _ = try catchingEarlyReturn(builder, diBuilder, branchingTo: repeatHeaderBlock) {
                let elementIRValue = builder.buildCall(toExternalFunction: .getFromSequenceAtIndex, args: [bp, containerIRValue, repeatCount])
                
                let variableTermIRValue = variable.irPointerValue(builder: builder)
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, variableTermIRValue, elementIRValue])
                
                let repeatMergeBlock = builder.insertBlock!
                
                let newRepeatResult = try repeating.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                repeatResult.addIncoming([(newRepeatResult, repeatMergeBlock)])
                
                let newRepeatCount = builder.buildBinaryOperation(.add, repeatCount, IntType.int64.constant(1), name: "next-repeat-index")
                repeatCount.addIncoming([(newRepeatCount, builder.insertBlock!)])
                
                return newRepeatResult
            }
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            return repeatResult
        case .tell(let newTarget, let to): // MARK: .tell
            let newTargetValue = try newTarget.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false)
            return try to.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: newTargetValue)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialIRValue = try initialValue?.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target) ?? builder.rtNull
            
            let termIRValue = term.irPointerValue(builder: builder)
            
            builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, termIRValue, initialIRValue])
            
            return initialIRValue
        case .define(_, as: _): // MARK: .define
            return lastResult
        case .defining(_, as: _, body: let body): // MARK: .defining
            return try body.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
        case .return_(let returnValue): // MARK: .return_
            let returnIRValue = (try returnValue?.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target) ?? builder.rtNull)
            
            throw EarlyReturn(value: returnIRValue)
        case .integer(let value): // MARK: .integer
            return IntType.int64.constant(value).asRTInteger(builder: builder, bp: bp)
        case .double(let value): // MARK: .double
            return FloatType.double.constant(value).asRTReal(builder: builder, bp: bp)
        case .string(let value): // MARK: .string
            return builder.addGlobalString(name: "str", value: value).asRTString(builder: builder, bp: bp)
        case .list(let expressions): // MARK: .list
            let listIRValue = builder.buildCall(toExternalFunction: .newList, args: [bp])
            
            for expression in expressions {
                let expressionIRValue = try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToList, args: [bp, listIRValue, expressionIRValue])
            }
            
            return listIRValue
        case .record(let keyValues): // MARK: .record
            let recordIRValue = builder.buildCall(toExternalFunction: .newRecord, args: [bp])
            
            for (key, value) in keyValues {
                let keyIRValue = try key.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false)
                let valueIRValue = try value.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToRecord, args: [bp, recordIRValue, keyIRValue, valueIRValue])
            }
            
            return recordIRValue
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            return builder.buildCall(toExternalFunction: .unaryOp, args: [bp, IntType.int64.constant(operation.rawValue), try operand.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)])
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            return builder.buildCall(toExternalFunction: .binaryOp, args: [bp, IntType.int64.constant(operation.rawValue), try lhs.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target), try rhs.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)])
        case .variable(let term): // MARK: .variable
            let termIRValue = term.irPointerValue(builder: builder)
            
            return builder.buildCall(toExternalFunction: .getVariableValue, args: [bp, termIRValue])
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            return builder.buildCall(toExternalFunction: .getResource, args: [bp, term.irPointerValue(builder: builder)])
        case .enumerator(let term as Term): // MARK: .enumerator
            return builder.buildCall(toExternalFunction: .newConstant, args: [bp, term.typedUID.normalizedAsRTString(builder: builder, name: "constant-uid", bp: bp)])
        case .class_(let term as Term): // MARK: .class_
            return builder.buildCall(toExternalFunction: .newClass, args: [bp, term.typedUID.normalizedAsRTString(builder: builder, name: "class-uid", bp: bp)])
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                
                let termIRValue = variableTerm.irPointerValue(builder: builder)
                
                builder.buildCall(toExternalFunctionReturningVoid: .setVariableValue, args: [bp, termIRValue, newValueIRValue])
                return newValueIRValue
            } else {
                let directParameterUIDIRValue = TypedTermUID(ParameterUID.direct).normalizedAsRTString(builder: builder, name: "dp-uid", bp: bp)
                let toParameterUIDIRValue = TypedTermUID(ParameterUID.set_to).normalizedAsRTString(builder: builder, name: "dp-uid", bp: bp)
                let expressionIRValue = try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false)
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                
                let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [bp])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, directParameterUIDIRValue, expressionIRValue])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, toParameterUIDIRValue, newValueIRValue])
                
                let command = rt.command(forUID: TypedTermUID(CommandUID.set))
                let setCommandIRValue = command.irPointerValue(builder: builder)
                
                return builder.buildCall(toExternalFunction: .runCommand, args: [bp, setCommandIRValue, arguments, target])
            }
            
        case .command(let term, let parameters): // MARK: .command
            let parameterIRValues: [(uid: IRValue, value: IRValue)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let uidIRValue = parameterTerm.typedUID.normalizedAsRTString(builder: builder, name: "parameter-uid", bp: bp)
                let valueIRValue = try parameterValue.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
                return (uidIRValue, valueIRValue)
            }
            
            let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [bp])
            for parameter in parameterIRValues {
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, parameter.uid, parameter.value])
            }
            
            let commandIRValue = rt.command(forUID: term.typedUID).irPointerValue(builder: builder)
            return builder.buildCall(toExternalFunction: .runCommand, args: [bp, commandIRValue, arguments, target])
        case .reference(let expression): // MARK: .reference
            return try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target).evaluatingSpecifier(builder: builder, bp: bp)
        case .specifier(let specifier): // MARK: .specifier
            let specifierIRValue = try specifier.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            return evaluateSpecifiers ? specifierIRValue.evaluatingSpecifier(builder: builder, bp: bp) : specifierIRValue
        case .function(let name, let parameters, let arguments, let body): // MARK: .function
            let commandInfo = rt.command(forUID: TypedTermUID(.command, name.uid))
            
            let functionLLVMName = llvmify(name.name!)
            let argumentsIRTypes = [PointerType.toVoid]
            
            let function = builder.addFunction(functionLLVMName, type: FunctionType(argumentsIRTypes, PointerType.toVoid))
            let entry = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entry)
            
            let actualArguments = function.parameter(at: 0)!

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
                let getFunction: BuiltinFunction = (index == 0) ? .getFromArgumentRecordWithDirectParamFallback : .getFromArgumentRecord
                
                let parameterUIDIRValue = parameter.typedUID.normalizedAsRTString(builder: builder, name: "parameter-uid", bp: bp)
                let argumentValueIRValue = builder.buildCall(toExternalFunction: getFunction, args: [bp, actualArguments, parameterUIDIRValue])
                let argumentTermIRValue = argument.irPointerValue(builder: builder)
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, argumentTermIRValue, argumentValueIRValue])
            }
            
            try returningResult(builder, diBuilder) {
                try body.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: builder.rtNull, target: rt.global.irPointerValue(builder: builder))
            }
            
            builder.positionAtEnd(of: lastBlock)
            
            let commandInfoIRPointer = commandInfo.irPointerValue(builder: builder)
            let functionIRPointer = builder.buildBitCast(function, type: PointerType.toVoid)
            
            _ = builder.buildCall(toExternalFunction: .newFunction, args: [bp, commandInfoIRPointer, functionIRPointer, builder.rtNull])
            
            return lastResult
        case .multilineString(_, let body): // MARK: .multilineString
            return builder.addGlobalString(name: "multiline-str", value: body).asRTString(builder: builder, bp: bp)
        case .weave(let hashbang, let body): // MARK: .weave
            let hashbangRTString = builder.addGlobalString(name: "weave-hashbang", value: hashbang.invocation).asRTString(builder: builder, bp: bp)
            let bodyRTString = builder.addGlobalString(name: "weave-body", value: body).asRTString(builder: builder, bp: bp)
            
            return builder.buildCall(toExternalFunction: .runWeave, args: [bp, hashbangRTString, bodyRTString, lastResult])
        case .endWeave: // MARK: .endWeave
            return lastResult
        }
    }
    
}

private func llvmify(_ name: TermName) -> String {
    return name.normalized.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
}

protocol IRPointerConvertible {
}

extension IRPointerConvertible {
    
    func irPointerValue(builder: IRBuilder) -> IRValue {
        return builder.buildIntToPtr(IntType.int64.constant(UInt(bitPattern: BushelRT.toOpaque(self))), type: .toVoid)
    }
    
}

extension Builtin: IRPointerConvertible {}
extension Bushel.Term: IRPointerConvertible {}
extension TypeInfo: IRPointerConvertible {}
extension CommandInfo: IRPointerConvertible {}
extension ParameterInfo: IRPointerConvertible {}
extension PropertyInfo: IRPointerConvertible {}
extension RT_Global: IRPointerConvertible {} // Temporary

extension TypedTermUID {
    
    func normalizedAsRTString(builder: IRBuilder, name: String, bp: IRValue) -> IRValue {
        builder.module.addGlobalString(name: "\(name).\(self)", value: normalized).asRTString(builder: builder, bp: bp)
    }
    
}

extension Specifier {
    
    func generateLLVMIR(_ builder: IRBuilder, _ diBuilder: DIBuilder, _ builtin: Builtin, options: CodeGenOptions, lastResult: IRValue, target: IRValue) throws -> IRValue {
        let bp = builtin.irPointerValue(builder: builder)
        
        let uidIRValue = builder.buildGlobalString(idTerm.typedUID.normalized).asRTString(builder: builder, bp: bp)
        
        let parentIRValue = try parent?.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false) ?? PointerType.toVoid.null()
        
        let dataExpressionIRValues: [IRValue]
        if case .test(_, let testComponent) = kind {
            dataExpressionIRValues = [try testComponent.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)]
        } else {
            dataExpressionIRValues = try allDataExpressions().map { dataExpression in
                try dataExpression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            }
        }
        
        func generate() -> IRValue {
            switch kind {
            case .simple:
                return builder.buildCall(toExternalFunction: .newSpecifier1, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.simple.rawValue), dataExpressionIRValues[0]])
            case .index:
                return builder.buildCall(toExternalFunction: .newSpecifier1, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.index.rawValue), dataExpressionIRValues[0]])
            case .name:
                return builder.buildCall(toExternalFunction: .newSpecifier1, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.name.rawValue), dataExpressionIRValues[0]])
            case .id:
                return builder.buildCall(toExternalFunction: .newSpecifier1, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.id.rawValue), dataExpressionIRValues[0]])
            case .all:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.all.rawValue)])
            case .first:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.first.rawValue)])
            case .middle:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.middle.rawValue)])
            case .last:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.last.rawValue)])
            case .random:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.random.rawValue)])
            case .previous:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.previous.rawValue)])
            case .next:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.next.rawValue)])
            case .range:
                return builder.buildCall(toExternalFunction: .newSpecifier2, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.range.rawValue), dataExpressionIRValues[0], dataExpressionIRValues[1]])
            case .test:
                return builder.buildCall(toExternalFunction: .newSpecifier1, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.test.rawValue), dataExpressionIRValues[0]])
            case .property:
                return builder.buildCall(toExternalFunction: .newSpecifier0, args: [bp, parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.property.rawValue)])
            }
        }
        
        let resultIRValue = generate()
        return (parent == nil) ?
            builder.buildCall(toExternalFunction: .qualifySpecifier, args: [bp, resultIRValue, target]) :
            resultIRValue
    }
    
}

extension TestComponent {
    
    func generateLLVMIR(_ builder: IRBuilder, _ diBuilder: DIBuilder, _ builtin: Builtin, options: CodeGenOptions, lastResult: IRValue, target: IRValue) throws -> IRValue {
        let bp = builtin.irPointerValue(builder: builder)
        
        switch self {
        case .expression(let expression):
            return try expression.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target, evaluateSpecifiers: false)
        case .predicate(let predicate):
            let lhsIRValue = try predicate.lhs.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            let rhsIRValue = try predicate.rhs.generateLLVMIR(builder, diBuilder, builtin, options: options, lastResult: lastResult, target: target)
            
            return builder.buildCall(toExternalFunction: .newTestSpecifier, args: [bp, IntType.int32.constant(predicate.operation.rawValue), lhsIRValue, rhsIRValue])
        }
        
    }
    
}

extension IRValue {
    
    func evaluatingSpecifier(builder: IRBuilder, bp: IRValue) -> IRValue {
        guard type.asLLVM() == PointerType.toVoid.asLLVM() else {
            return self
        }
        return builder.buildCall(toExternalFunction: .evaluateSpecifier, args: [bp, self])
    }
    
}

extension IRValue {
    
    func asRTReal(builder: IRBuilder, bp: IRValue) -> IRValue {
        return builder.buildCall(toExternalFunction: .newReal, args: [bp, self])
    }
    
    func asRTInteger(builder: IRBuilder, bp: IRValue) -> IRValue {
        return builder.buildCall(toExternalFunction: .newInteger, args: [bp, self])
    }
    
    func asRTBoolean(builder: IRBuilder, bp: IRValue) -> IRValue {
        return builder.buildCall(toExternalFunction: .newBoolean, args: [bp, self])
    }
    
    func asRTString(builder: IRBuilder, bp: IRValue) -> IRValue {
        let opaquedSelf = builder.buildPointerCast(of: self, to: PointerType.toVoid, name: "opaqued-str")
        return builder.buildCall(toExternalFunction: .newString, args: [bp, opaquedSelf])
    }
    
}
