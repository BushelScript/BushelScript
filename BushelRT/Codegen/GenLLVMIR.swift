import Bushel
import LLVM
import cllvm
import os

private let log = OSLog(subsystem: logSubsystem, category: "LLVM IR gen")

extension IRBuilder {
    
    /// A pointer IRValue to the singleton instance of `RT_Null`.
    var rtNull: IRValue {
        return buildLoad(module.global(named: "rt_null")!)
    }
    
}

extension IRBuilder {
    
    /// `FnPtr` **must** be `@convention(c)`.
    func addExternalFunctionAsGlobal<FnPtr>(_ fnPtr: FnPtr, _ function: BuiltinFunction) {
        return addExternalFunctionAsGlobal(fnPtr, name: function.runtimeName, type: function.runtimeType)
    }
    
    /// `FnPtr` **must** be `@convention(c)`.
    func addExternalFunctionAsGlobal<FnPtr>(_ fnPtr: FnPtr, name: String, type: FunctionType) {
        let fnAddress = unsafeBitCast(fnPtr, to: UInt.self)
        let pointerType = PointerType(pointee: type)
        let pointerIRValue = buildIntToPtr(IntType.int64.constant(fnAddress), type: pointerType)
        addGlobal(name, type: pointerType).initializer = pointerIRValue
    }
    
    @discardableResult
    func buildCall(toExternalFunctionReturningVoid function: BuiltinFunction, args: [IRValue]) -> Call {
        precondition(LLVMGetTypeKind(function.runtimeType.returnType.asLLVM()) == LLVMVoidTypeKind)
        return buildCall(toExternalFunction: function, args: args, name: "")
    }
    
    func buildCall(toExternalFunction function: BuiltinFunction, args: [IRValue], name: String? = nil) -> Call {
        precondition(args.count == function.runtimeType.parameterTypes.count)
        return buildCallToExternalFunction(named: function.runtimeName, type: function.runtimeType, args: args, name: name ?? function.rawValue)
    }
    
    func buildCallToExternalFunction(named fnName: String, type fnType: FunctionType, args: [IRValue], name: String = "") -> Call {
        let fnPointerValue = buildLoad(module.global(named: fnName)!, name: fnName)
        return buildCall(fnPointerValue, args: args, name: name)
    }
    
}

enum BuiltinFunction: String {
    
    case release
    case pushFrame, pushFrameWithTarget, popFrame
    case getCurrentTarget
    case newVariable, getVariableValue, setVariableValue
    case isTruthy
    case numericEqual
    case newReal, newInteger, newBoolean, newString, newConstant, newClass
    case newList, newRecord, newArgumentRecord
    case addToList, addToRecord, addToArgumentRecord
    case getSequenceLength, getFromSequenceAtIndex
    case getFromArgumentRecord, getFromArgumentRecordWithDirectParamFallback
    case unaryOp, binaryOp
    case coerce
    case getResource
    case newSpecifier0, newSpecifier1, newSpecifier2
    case newTestSpecifier
    case qualifySpecifier, evaluateSpecifier
    case call
    case runWeave
    
    var runtimeName: String {
        return "bushel_" + rawValue
    }
    
    var runtimeType: FunctionType {
        let components = runtimeTypeComponents
        
        // First pointer is Builtin object
        let parameters = [PointerType.toVoid] + components.parameters
        let returnType = components.returnType
        
        return FunctionType(parameters, returnType)
    }
    
    private var runtimeTypeComponents: (parameters: [IRType], returnType: IRType) {
        let object = PointerType.toVoid
        let void = VoidType()
        let double = FloatType.double
        let bool = IntType.int1
        let int32 = IntType.int32
        let int64 = IntType.int64
        switch self {
        case .release: return ([object], void)
        case .pushFrame: return ([], void)
        case .pushFrameWithTarget: return ([object], void)
        case .popFrame: return ([], void)
        case .getCurrentTarget: return ([], object)
        case .newVariable: return ([object, object], void)
        case .getVariableValue: return ([object], object)
        case .setVariableValue: return ([object, object], void)
        case .isTruthy: return ([object], bool)
        case .numericEqual: return ([object, object], bool)
        case .newReal: return ([double], object)
        case .newInteger: return ([int64], object)
        case .newBoolean: return ([bool], object)
        case .newString: return ([PointerType.toVoid], object)
        case .newConstant: return ([object], object)
        case .newClass: return ([object], object)
        case .newList: return ([], object)
        case .newRecord: return ([], object)
        case .newArgumentRecord: return ([], object)
        case .addToList: return ([object, object], void)
        case .addToRecord: return ([object, object, object], void)
        case .addToArgumentRecord: return ([object, object, object], void)
        case .getSequenceLength: return ([object], int64)
        case .getFromSequenceAtIndex: return ([object, int64], object)
        case .getFromArgumentRecord: return ([object, object], object)
        case .getFromArgumentRecordWithDirectParamFallback: return ([object, object], object)
        case .unaryOp: return ([int64, object], object)
        case .binaryOp: return ([int64, object, object], object)
        case .coerce: return ([object, object], object)
        case .getResource: return ([object], object)
        case .newSpecifier0: return ([object, object, int32], object)
        case .newSpecifier1: return ([object, object, int32, object], object)
        case .newSpecifier2: return ([object, object, int32, object, object], object)
        case .newTestSpecifier: return ([int32, object, object], object)
        case .qualifySpecifier: return ([object], object)
        case .evaluateSpecifier: return ([object], object)
        case .call: return ([object, object], object)
        case .runWeave: return ([object, object, object], object)
        }
    }
    
}

private func ø /* ⌥O */(_ builtinPointer: Builtin.Pointer) -> Builtin {
    Builtin.fromOpaque(builtinPointer)
}

/// Creates an LLVM module and propagates it with necessary runtime facilities,
/// then generates an IR program from the given expression.
///
/// - Parameter expression: The expression from which to generate an LLVM IR program.
/// - Returns: The completed LLVM module.
func generateLLVMModule(from expression: Expression, builtin: Builtin) -> Module {
    let module = Module(name: "main")
    let builder = IRBuilder(module: module)
    
    module.addGlobal("rt_null", type: PointerType.toVoid).initializer = builder.buildIntToPtr(IntType.int64.constant(Int(bitPattern: Builtin.toOpaque(RT_Null.null))), type: .toVoid)
    
    let release: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Void = { a, b in ø(a).release(b) }
    builder.addExternalFunctionAsGlobal(release, .release)
    
    let pushFrame: @convention(c) (Builtin.Pointer) -> Void = { a in ø(a).pushFrame() }
    builder.addExternalFunctionAsGlobal(pushFrame, .pushFrame)
    
    let pushFrameWithTarget: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Void = { a, b in ø(a).pushFrame(newTarget: b) }
    builder.addExternalFunctionAsGlobal(pushFrameWithTarget, .pushFrameWithTarget)
    
    let popFrame: @convention(c) (Builtin.Pointer) -> Void = { a in ø(a).popFrame() }
    builder.addExternalFunctionAsGlobal(popFrame, .popFrame)
    
    let getCurrentTarget: @convention(c) (Builtin.Pointer) -> Builtin.RTObjectPointer = { a in ø(a).getCurrentTarget() }
    builder.addExternalFunctionAsGlobal(getCurrentTarget, .getCurrentTarget)
    
    let newVariable: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = { a, b, c in ø(a).newVariable(b, c) }
    builder.addExternalFunctionAsGlobal(newVariable, .newVariable)
    
    let getVariableValue: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).getVariableValue(b) }
    builder.addExternalFunctionAsGlobal(getVariableValue, .getVariableValue)
    
    let setVariableValue: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).setVariableValue(b, c) }
    builder.addExternalFunctionAsGlobal(setVariableValue, .setVariableValue)
    
    let isTruthy: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Bool = { a, b in ø(a).isTruthy(b) }
    builder.addExternalFunctionAsGlobal(isTruthy, .isTruthy)
    
    let equal: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Bool = { a, b, c in ø(a).numericEqual(b, c) }
    builder.addExternalFunctionAsGlobal(equal, .numericEqual)
    
    let newReal: @convention(c) (Builtin.Pointer, Double) -> Builtin.RTObjectPointer = { a, b in ø(a).newReal(b) }
    builder.addExternalFunctionAsGlobal(newReal, .newReal)
    
    let newInteger: @convention(c) (Builtin.Pointer, Int64) -> Builtin.RTObjectPointer = { a, b in ø(a).newInteger(b) }
    builder.addExternalFunctionAsGlobal(newInteger, .newInteger)
    
    let newBoolean: @convention(c) (Builtin.Pointer, Bool) -> Builtin.RTObjectPointer = { a, b in ø(a).newBoolean(b) }
    builder.addExternalFunctionAsGlobal(newBoolean, .newBoolean)
    
    let newString: @convention(c) (Builtin.Pointer, UnsafePointer<CChar>) -> Builtin.RTObjectPointer = { a, b in ø(a).newString(b) }
    builder.addExternalFunctionAsGlobal(newString, .newString)
    
    let newConstant: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).newConstant(b) }
    builder.addExternalFunctionAsGlobal(newConstant, .newConstant)
    
    let newClass: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).newClass(b) }
    builder.addExternalFunctionAsGlobal(newClass, .newClass)
    
    let newList: @convention(c) (Builtin.Pointer) -> Builtin.RTObjectPointer = { a in ø(a).newList() }
    builder.addExternalFunctionAsGlobal(newList, .newList)
    
    let newRecord: @convention(c) (Builtin.Pointer) -> Builtin.RTObjectPointer = { a in ø(a).newRecord() }
    builder.addExternalFunctionAsGlobal(newRecord, .newRecord)
    
    let newArgumentRecord: @convention(c) (Builtin.Pointer) -> Builtin.RTObjectPointer = { a in ø(a).newArgumentRecord() }
    builder.addExternalFunctionAsGlobal(newArgumentRecord, .newArgumentRecord)
    
    let addToList: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = { a, b, c in ø(a).addToList(b, c) }
    builder.addExternalFunctionAsGlobal(addToList, .addToList)
    
    let addToRecord: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = { a, b, c, d in ø(a).addToRecord(b, c, d) }
    builder.addExternalFunctionAsGlobal(addToRecord, .addToRecord)
    
    let addToArgumentRecord: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = { a, b, c, d in ø(a).addToArgumentRecord(b, c, d) }
    builder.addExternalFunctionAsGlobal(addToArgumentRecord, .addToArgumentRecord)
    
    let getSequenceLength: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Int64 = { a, b in ø(a).getSequenceLength(b) }
    builder.addExternalFunctionAsGlobal(getSequenceLength, .getSequenceLength)
    
    let getFromSequenceAtIndex: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Int64) -> Builtin.RTObjectPointer = { a, b, c in ø(a).getFromSequenceAtIndex(b, c) }
    builder.addExternalFunctionAsGlobal(getFromSequenceAtIndex, .getFromSequenceAtIndex)
    
    let getFromArgumentRecord: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).getFromArgumentRecord(b, c) }
    builder.addExternalFunctionAsGlobal(getFromArgumentRecord, .getFromArgumentRecord)
    
    let getFromArgumentRecordWithDirectParamFallback: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).getFromArgumentRecordWithDirectParamFallback(b, c) }
    builder.addExternalFunctionAsGlobal(getFromArgumentRecordWithDirectParamFallback, .getFromArgumentRecordWithDirectParamFallback)
    
    let unaryOp: @convention(c) (Builtin.Pointer, Int64, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).unaryOp(b, c) }
    builder.addExternalFunctionAsGlobal(unaryOp, .unaryOp)
    
    let binaryOp: @convention(c) (Builtin.Pointer, Int64, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c, d in ø(a).binaryOp(b, c, d) }
    builder.addExternalFunctionAsGlobal(binaryOp, .binaryOp)
    
    let coerce: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.InfoPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).coerce(b, to: c) }
    builder.addExternalFunctionAsGlobal(coerce, .coerce)
    
    let getResource: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).getResource(b) }
    builder.addExternalFunctionAsGlobal(getResource, .getResource)
    
    let newSpecifier0: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32) -> Builtin.RTObjectPointer = { a, b, c, d in ø(a).newSpecifier0(b, c, d) }
    builder.addExternalFunctionAsGlobal(newSpecifier0, .newSpecifier0)
    let newSpecifier1: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c, d, e in ø(a).newSpecifier1(b, c, d, e) }
    builder.addExternalFunctionAsGlobal(newSpecifier1, .newSpecifier1)
    let newSpecifier2: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c, d, e, f in ø(a).newSpecifier2(b, c, d, e, f) }
    builder.addExternalFunctionAsGlobal(newSpecifier2, .newSpecifier2)
    
    let newTestSpecifier: @convention(c) (Builtin.Pointer, UInt32, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c, d in ø(a).newTestSpecifier(b, c, d) }
    builder.addExternalFunctionAsGlobal(newTestSpecifier, .newTestSpecifier)
    
    let qualifySpecifier: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).qualifySpecifier(b) }
    builder.addExternalFunctionAsGlobal(qualifySpecifier, .qualifySpecifier)
    
    let evaluateSpecifier: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b in ø(a).evaluateSpecifier(b) }
    builder.addExternalFunctionAsGlobal(evaluateSpecifier, .evaluateSpecifier)
    
    let call: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c in ø(a).call(b, c) }
    builder.addExternalFunctionAsGlobal(call, .call)
    
    let runWeave: @convention(c) (Builtin.Pointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = { a, b, c, d in ø(a).runWeave(b, c, d) }
    builder.addExternalFunctionAsGlobal(runWeave, .runWeave)
    
    let main = builder.addFunction("main", type: FunctionType([], PointerType.toVoid))
    let entry = main.appendBasicBlock(named: "entry")
    builder.positionAtEnd(of: entry)
    var stack = StaticStack()
    do {
        try returningResult(builder) {
            try expression.generateLLVMIR(builder, builtin, &stack, options: CodeGenOptions(stackIntrospectability: false), lastResult: builder.rtNull)
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

private func returningResult(_ builder: IRBuilder, from action: () throws -> IRValue) rethrows {
    let resultValue: IRValue
    do {
        resultValue = try action()
    } catch let earlyReturn as EarlyReturn {
        resultValue = earlyReturn.value
    }
    builder.buildRet(resultValue)
}

private func catchingEarlyReturn(_ builder: IRBuilder, branchingTo nextBlock: BasicBlock, from action: () throws -> IRValue) rethrows -> IRValue {
    try catchingEarlyReturn(builder, branching: { builder.buildBr(nextBlock) }, from: action)
}

private func catchingEarlyReturn(_ builder: IRBuilder, branching: () throws -> Void, from action: () throws -> IRValue) rethrows -> IRValue {
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

public struct CodeGenOptions {
    
    /// Whether the stack should be runtime-introspectable.
    /// Generates push and pop runtime calls, and forces all variables to be
    /// tracked dynamically.
    /// For end-user debugging purposes.
    public let stackIntrospectability: Bool
    
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
    ///   - evaluateSpecifiers: Whether specifiers should be evaluated by
    ///                         default. Subsequent recursive calls ignore
    ///                         the current setting.
    /// - Returns: The resultant `IRValue` from building the code for this
    ///            expression.
   func generateLLVMIR(_ builder: IRBuilder, _ builtin: Builtin, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue, evaluateSpecifiers: Bool = true) throws -> IRValue {
        let rt = builtin.rt
        let bp = builtin.irPointerValue(builder: builder)
        
        let lastBlock = builder.insertBlock!
        let function = lastBlock.parent!
        
        switch kind {
        case .topLevel: // MARK: .topLevel
            fatalError()
        case .empty, .end, .that: // MARK: .empty, .end., .that
            return lastResult
        case .it: // MARK: .it
            return builder.buildCall(toExternalFunction: .getCurrentTarget, args: [bp])
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
                        .generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                })
        case .scoped(let expression): // MARK: .scoped
            stack.push()
            defer {
                stack.pop()
            }
            
            if options.stackIntrospectability {
                builder.buildCall(toExternalFunctionReturningVoid: .pushFrame, args: [bp])
            }
            defer {
                if options.stackIntrospectability {
                    builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [bp])
                }
            }
            
            return try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
        case .parentheses(let expression): // MARK: .parentheses
            return try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try condition.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            
            let conditionTest = builder.buildCall(toExternalFunction: .isTruthy, args: [bp, conditionValue])
            
            var thenBlock = function.appendBasicBlock(named: "then")
            var elseBlock = BasicBlock(context: builder.module.context, name: "else")
            let mergeBlock = BasicBlock(context: builder.module.context, name: "merge")
            
            builder.buildCondBr(condition: conditionTest, then: thenBlock, else: elseBlock)
            
            builder.positionAtEnd(of: thenBlock)
            
            let thenValue = try catchingEarlyReturn(builder, branchingTo: mergeBlock) {
                try then.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            }
            thenBlock = builder.insertBlock!
            
            function.append(elseBlock)
            builder.positionAtEnd(of: elseBlock)
            let elseValue: IRValue
            if let else_ = else_ {
                elseValue = try catchingEarlyReturn(builder, branchingTo: mergeBlock) {
                    try else_.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                }
                elseBlock = builder.insertBlock!
            } else {
                builder.buildBr(mergeBlock)
                elseValue = lastResult
            }
            
            function.append(mergeBlock)
            builder.positionAtEnd(of: mergeBlock)
            
            switch (thenValue.isUndef, elseValue.isUndef) {
            case (false, false):
                let phi = builder.buildPhi(PointerType.toVoid, name: "if-then-else")
                phi.addIncoming([(thenValue, thenBlock), (elseValue, elseBlock)])
                return phi
            case (true, false):
                return elseValue
            case (false, true):
                return thenValue
            case (true, true):
                return builder.buildUnreachable()
            }
        case .repeatWhile(let condition, let repeating): // MARK: .repeatWhile
            let repeatBlock = function.appendBasicBlock(named: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            func evalConditionAndCondBr() throws {
                let conditionValue = try condition.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                let conditionTest = builder.buildCall(toExternalFunction: .isTruthy, args: [bp, conditionValue])
                
                builder.buildCondBr(condition: conditionTest, then: repeatBlock, else: afterRepeatBlock)
            }
            
            try evalConditionAndCondBr()
            
            builder.positionAtEnd(of: repeatBlock)
            
            let repeatResult = try catchingEarlyReturn(builder, branching: evalConditionAndCondBr) {
                try repeating.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            }
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            let result = builder.buildPhi(PointerType.toVoid, name: "repeat-result-or-that")
            result.addIncoming([(repeatResult, repeatBlock), (lastResult, lastBlock)])
            
            return repeatResult
        case .repeatTimes(let times, let repeating): // MARK: .repeatTimes
            let repeatHeaderBlock = function.appendBasicBlock(named: "repeat-header")
            let repeatBlock = function.appendBasicBlock(named: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            let timesValue = try times.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            
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
            
            _ = try catchingEarlyReturn(builder, branchingTo: repeatHeaderBlock) {
                let newRepeatResult = try repeating.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                repeatResult.addIncoming([(newRepeatResult, builder.insertBlock!)])
                
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
            
            let containerIRValue = try container.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            
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
            
            _ = try catchingEarlyReturn(builder, branchingTo: repeatHeaderBlock) {
                let elementIRValue = builder.buildCall(toExternalFunction: .getFromSequenceAtIndex, args: [bp, containerIRValue, repeatCount])
                
                let variableTermIRValue = variable.term.irPointerValue(builder: builder)
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, variableTermIRValue, elementIRValue])
                
                let newRepeatResult = try repeating.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                repeatResult.addIncoming([(newRepeatResult, builder.insertBlock!)])
                
                let newRepeatCount = builder.buildBinaryOperation(.add, repeatCount, IntType.int64.constant(1), name: "next-repeat-index")
                repeatCount.addIncoming([(newRepeatCount, builder.insertBlock!)])
                
                return newRepeatResult
            }
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            return repeatResult
        case .tell(let target, let to): // MARK: .tell
            let targetValue = try target.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
            
            stack.currentTarget = targetValue
            
            builder.buildCall(toExternalFunctionReturningVoid: .pushFrameWithTarget, args: [bp, targetValue])
            defer {
                builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [bp])
            }
            
            return try to.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialIRValue = try initialValue?.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult) ?? builder.rtNull
            
            let termIRValue = term.term.irPointerValue(builder: builder)
            
            builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, termIRValue, initialIRValue])
            
            return initialIRValue
        case .return_(let returnValue): // MARK: .return_
            let returnIRValue = (try returnValue?.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult) ?? builder.rtNull)
            
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
                let expressionIRValue = try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToList, args: [bp, listIRValue, expressionIRValue])
            }
            
            return listIRValue
        case .record(let keyValues): // MARK: .record
            let recordIRValue = builder.buildCall(toExternalFunction: .newRecord, args: [bp])
            
            for (key, value) in keyValues {
                let keyIRValue = try key.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
                let valueIRValue = try value.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToRecord, args: [bp, recordIRValue, keyIRValue, valueIRValue])
            }
            
            return recordIRValue
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            return builder.buildCall(toExternalFunction: .unaryOp, args: [bp, IntType.int64.constant(operation.rawValue), try operand.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)])
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            return builder.buildCall(toExternalFunction: .binaryOp, args: [bp, IntType.int64.constant(operation.rawValue), try lhs.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult), try rhs.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)])
        case .coercion(of: let expression, to: let type): // MARK: .coercion
            return builder.buildCall(toExternalFunction: .coerce, args: [bp, try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult), rt.type(forUID: type.term.typedUID).irPointerValue(builder: builder)])
        case .variable(let term): // MARK: .variable
            let termIRValue = term.irPointerValue(builder: builder)
            
            return builder.buildCall(toExternalFunction: .getVariableValue, args: [bp, termIRValue])
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            return builder.buildCall(toExternalFunction: .getResource, args: [bp, term.term.irPointerValue(builder: builder)])
        case .enumerator(let term as Term): // MARK: .enumerator
            return builder.buildCall(toExternalFunction: .newConstant, args: [bp, term.typedUID.normalizedAsRTString(builder: builder, name: "constant-uid", bp: bp)])
        case .class_(let term as Term): // MARK: .class_
            return builder.buildCall(toExternalFunction: .newClass, args: [bp, term.typedUID.normalizedAsRTString(builder: builder, name: "class-uid", bp: bp)])
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                
                let termIRValue = variableTerm.irPointerValue(builder: builder)
                
                return builder.buildCall(toExternalFunctionReturningVoid: .setVariableValue, args: [bp, termIRValue, newValueIRValue])
            } else {
                let directParameterUIDIRValue = TypedTermUID(ParameterUID.direct).normalizedAsRTString(builder: builder, name: "dp-uid", bp: bp)
                let toParameterUIDIRValue = TypedTermUID(ParameterUID.set_to).normalizedAsRTString(builder: builder, name: "dp-uid", bp: bp)
                let expressionIRValue = try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                
                let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [bp])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, directParameterUIDIRValue, expressionIRValue])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, toParameterUIDIRValue, newValueIRValue])
                
                let command = rt.command(forUID: TypedTermUID(CommandUID.set))
                let setCommandIRValue = command.irPointerValue(builder: builder)
                
                return builder.buildCall(toExternalFunction: .call, args: [bp, setCommandIRValue, arguments])
            }
            
        case .command(let term, let parameters): // MARK: .command
            let parameterIRValues: [(uid: IRValue, value: IRValue)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let uidIRValue = parameterTerm.term.typedUID.normalizedAsRTString(builder: builder, name: "parameter-uid", bp: bp)
                let valueIRValue = try parameterValue.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
                return (uidIRValue, valueIRValue)
            }
            
            let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [bp])
            for parameter in parameterIRValues {
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [bp, arguments, parameter.uid, parameter.value])
            }
            
            if
                let name = term.name,
                let function = stack.function(for: name)
            {
                return builder.buildCall(function, args: [arguments])
            } else {
                let commandIRValue = rt.command(forUID: term.term.typedUID).irPointerValue(builder: builder)
                return builder.buildCall(toExternalFunction: .call, args: [bp, commandIRValue, arguments])
            }
            
        case .reference(let expression): // MARK: .reference
            return try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: true)
        case .specifier(let specifier): // MARK: .specifier
            let specifierIRValue = try specifier.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            return evaluateSpecifiers ? specifierIRValue.evaluatingSpecifier(builder: builder, bp: bp) : specifierIRValue
        case .function(let name, let parameters, let arguments, let body): // MARK: .function
            let prevBlock = builder.insertBlock!
            
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
                
                let parameterUIDIRValue = parameter.term.typedUID.normalizedAsRTString(builder: builder, name: "parameter-uid", bp: bp)
                let argumentValueIRValue = builder.buildCall(toExternalFunction: getFunction, args: [actualArguments, parameterUIDIRValue])
                let argumentTermIRValue = argument.term.irPointerValue(builder: builder)
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [bp, argumentTermIRValue, argumentValueIRValue])
            }
            
            stack.currentFrame.add(function: function, for: name.name!)
            
            try returningResult(builder) {
                try body.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: builder.rtNull)
            }
            
            builder.positionAtEnd(of: prevBlock)
            
            return lastResult
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
    return name.normalized.replacingOccurrences(of: " ", with: "_")
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

extension TypedTermUID {
    
    func normalizedAsRTString(builder: IRBuilder, name: String, bp: IRValue) -> IRValue {
        builder.module.addGlobalString(name: "\(name).\(self)", value: normalized).asRTString(builder: builder, bp: bp)
    }
    
}

extension Specifier {
    
    func generateLLVMIR(_ builder: IRBuilder, _ builtin: Builtin, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue) throws -> IRValue {
        let rt = builtin.rt
        let bp = builtin.irPointerValue(builder: builder)
        
        let uidIRValue = builder.buildGlobalString(idTerm.term.typedUID.normalized).asRTString(builder: builder, bp: bp)
        
        let parentIRValue = try parent?.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false) ?? PointerType.toVoid.null()
        
        let dataExpressionIRValues: [IRValue]
        if case .test(_, let testComponent) = kind {
            dataExpressionIRValues = [try testComponent.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)]
        } else {
            dataExpressionIRValues = try allDataExpressions().map { dataExpression in
                try dataExpression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
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
            builder.buildCall(toExternalFunction: .qualifySpecifier, args: [bp, resultIRValue]) :
            resultIRValue
    }
    
}

extension TestComponent {
    
    func generateLLVMIR(_ builder: IRBuilder, _ builtin: Builtin, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue) throws -> IRValue {
        let bp = builtin.irPointerValue(builder: builder)
        
        switch self {
        case .expression(let expression):
            return try expression.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
        case .predicate(let predicate):
            let lhsIRValue = try predicate.lhs.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            let rhsIRValue = try predicate.rhs.generateLLVMIR(builder, builtin, &stack, options: options, lastResult: lastResult)
            
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
