import Bushel
import LLVM
import cllvm
import os

private let log = OSLog(subsystem: logSubsystem, category: "LLVM IR gen")

func release(_ object: Builtin.RTObjectPointer) {
    return Builtin.release(Builtin.fromOpaque(object))
}

func pushFrame() {
    return Builtin.pushFrame()
}

func pushFrame(newTarget: Builtin.RTObjectPointer) {
    return Builtin.pushFrame(newTarget: newTarget)
}

func popFrame() {
    return Builtin.popFrame()
}

func newVariable(_ term: Builtin.TermPointer, _ initialValue: Builtin.RTObjectPointer) {
    return Builtin.newVariable(term, initialValue)
}

func getVariableValue(_ term: Builtin.TermPointer) -> Builtin.RTObjectPointer {
    return Builtin.getVariableValue(term)
}

func setVariableValue(_ term: Builtin.TermPointer, _ newValue: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.setVariableValue(term, newValue)
}

func isTruthy(_ object: Builtin.RTObjectPointer) -> Bool {
    return Builtin.isTruthy(object)
}

func numericEqual(_ lhs: Builtin.RTObjectPointer, _ rhs: Builtin.RTObjectPointer) -> Bool {
    return Builtin.numericEqual(lhs, rhs)
}

func newReal(_ value: Double) -> Builtin.RTObjectPointer {
    return Builtin.newReal(value)
}

func newInteger(_ value: Int64) -> Builtin.RTObjectPointer {
    return Builtin.newInteger(value)
}

func newBoolean(_ value: Bool) -> Builtin.RTObjectPointer {
    return Builtin.newBoolean(value)
}

func newString(_ cString: UnsafePointer<CChar>) -> Builtin.RTObjectPointer {
    return Builtin.newString(cString)
}

func newConstant(_ value: OSType) -> Builtin.RTObjectPointer {
    return Builtin.newConstant(value)
}

func newSymbolicConstant(_ value: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.newSymbolicConstant(value)
}

func newClass(_ value: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.newClass(value)
}

func newList() -> Builtin.RTObjectPointer {
    return Builtin.newList()
}

func newRecord() -> Builtin.RTObjectPointer {
    return Builtin.newRecord()
}

func newArgumentRecord() -> Builtin.RTObjectPointer {
    return Builtin.newArgumentRecord()
}

func addToList(_ list: Builtin.RTObjectPointer, _ value: Builtin.RTObjectPointer) {
    return Builtin.addToList(list, value)
}

func addToRecord(_ record: Builtin.RTObjectPointer, _ key: Builtin.RTObjectPointer, _ value: Builtin.RTObjectPointer) {
    return Builtin.addToRecord(record, key, value)
}

func addToArgumentRecord(_ record: Builtin.RTObjectPointer, _ key: Builtin.RTObjectPointer, _ value: Builtin.RTObjectPointer) {
    return Builtin.addToArgumentRecord(record, key, value)
}

func getFromArgumentRecord(_ record: Builtin.RTObjectPointer, _ term: Builtin.TermPointer) -> Builtin.RTObjectPointer {
    return Builtin.getFromArgumentRecord(record, term)
}

func getFromArgumentRecordWithDirectParamFallback(_ record: Builtin.RTObjectPointer, _ term: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.getFromArgumentRecordWithDirectParamFallback(record, term)
}

func unaryOp(_ operation: Int64, _ operand: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.unaryOp(operation, operand)
}

func binaryOp(_ operation: Int64, _ lhs: Builtin.RTObjectPointer, _ rhs: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.binaryOp(operation, lhs, rhs)
}

func coerce(_ object: Builtin.RTObjectPointer, to type: Builtin.InfoPointer) -> Builtin.RTObjectPointer {
    return Builtin.coerce(object, to: type)
}

func newSpecifier0(_ parent: Builtin.RTObjectPointer?, _ uid: Builtin.RTObjectPointer, _ kind: UInt32) -> Builtin.RTObjectPointer {
    return Builtin.newSpecifier0(parent, uid, kind)
}
func newSpecifier1(_ parent: Builtin.RTObjectPointer?, _ uid: Builtin.RTObjectPointer, _ kind: UInt32, _ data1: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.newSpecifier1(parent, uid, kind, data1)
}
func newSpecifier2(_ parent: Builtin.RTObjectPointer?, _ uid: Builtin.RTObjectPointer, _ kind: UInt32, _ data1: Builtin.RTObjectPointer, _ data2: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.newSpecifier2(parent, uid, kind, data1, data2)
}

func newTestSpecifier(_ operation: UInt32, _ lhs: Builtin.RTObjectPointer, _ rhs: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.newTestSpecifier(operation, lhs, rhs)
}

func evaluateSpecifier(_ specifier: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.evaluateSpecifier(specifier)
}

func call(_ command: Builtin.TermPointer, arguments: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.call(command, arguments)
}

func runWeave(_ hashbang: Builtin.RTObjectPointer, _ body: Builtin.RTObjectPointer, _ input: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.runWeave(hashbang, body, input)
}

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
    case newVariable, getVariableValue, setVariableValue
    case isTruthy
    case numericEqual
    case newReal, newInteger, newBoolean, newString, newConstant, newSymbolicConstant, newClass
    case newList, newRecord, newArgumentRecord
    case addToList, addToRecord, addToArgumentRecord
    case getFromArgumentRecord, getFromArgumentRecordWithDirectParamFallback
    case unaryOp, binaryOp
    case coerce
    case newSpecifier0, newSpecifier1, newSpecifier2
    case newTestSpecifier
    case evaluateSpecifier
    case call
    case runWeave
    
    var runtimeName: String {
        return "bushel_" + rawValue
    }
    
    var runtimeType: FunctionType {
        let components = runtimeTypeComponents
        return FunctionType(components.parameters, components.returnType)
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
        case .newVariable: return ([object, object], void)
        case .getVariableValue: return ([object], object)
        case .setVariableValue: return ([object, object], void)
        case .isTruthy: return ([object], bool)
        case .numericEqual: return ([object, object], bool)
        case .newReal: return ([double], object)
        case .newInteger: return ([int64], object)
        case .newBoolean: return ([bool], object)
        case .newString: return ([PointerType.toVoid], object)
        case .newConstant: return ([int32], object)
        case .newSymbolicConstant: return ([object], object)
        case .newClass: return ([object], object)
        case .newList: return ([], object)
        case .newRecord: return ([], object)
        case .newArgumentRecord: return ([], object)
        case .addToList: return ([object, object], void)
        case .addToRecord: return ([object, object, object], void)
        case .addToArgumentRecord: return ([object, object, object], void)
        case .getFromArgumentRecord: return ([object, object], object)
        case .getFromArgumentRecordWithDirectParamFallback: return ([object, object], object)
        case .unaryOp: return ([int64, object], object)
        case .binaryOp: return ([int64, object, object], object)
        case .coerce: return ([object, object], object)
        case .newSpecifier0: return ([object, object, int32], object)
        case .newSpecifier1: return ([object, object, int32, object], object)
        case .newSpecifier2: return ([object, object, int32, object, object], object)
        case .newTestSpecifier: return ([int32, object, object], object)
        case .evaluateSpecifier: return ([object], object)
        case .call: return ([object, object], object)
        case .runWeave: return ([object, object, object], object)
        }
    }
    
}

/// Creates an LLVM module and propagates it with necessary runtime facilities,
/// then generates an IR program from the given expression.
///
/// - Parameter expression: The expression from which to generate an LLVM IR program.
/// - Returns: The completed LLVM module.
public func generateLLVMModule(from expression: Expression, rt: RTInfo) -> Module {
    let module = Module(name: "main")
    let builder = IRBuilder(module: module)
    
    module.addGlobal("rt_null", type: PointerType.toVoid).initializer = builder.buildIntToPtr(IntType.int64.constant(Int(bitPattern: Builtin.toOpaque(RT_Null.null))), type: .toVoid)
    
    let release: @convention(c) (Builtin.RTObjectPointer) -> Void = BushelRT.release
    builder.addExternalFunctionAsGlobal(release, .release)
    
    let pushFrame: @convention(c) () -> Void = BushelRT.pushFrame
    builder.addExternalFunctionAsGlobal(pushFrame, .pushFrame)
    
    let pushFrameWithTarget: @convention(c) (Builtin.RTObjectPointer) -> Void = BushelRT.pushFrame(newTarget:)
    builder.addExternalFunctionAsGlobal(pushFrameWithTarget, .pushFrameWithTarget)
    
    let popFrame: @convention(c) () -> Void = BushelRT.popFrame
    builder.addExternalFunctionAsGlobal(popFrame, .popFrame)
    
    let newVariable: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = BushelRT.newVariable
    builder.addExternalFunctionAsGlobal(newVariable, .newVariable)
    
    let getVariableValue: @convention(c) (Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.getVariableValue
    builder.addExternalFunctionAsGlobal(getVariableValue, .getVariableValue)
    
    let setVariableValue: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.setVariableValue
    builder.addExternalFunctionAsGlobal(setVariableValue, .setVariableValue)
    
    let isTruthy: @convention(c) (Builtin.RTObjectPointer) -> Bool = BushelRT.isTruthy
    builder.addExternalFunctionAsGlobal(isTruthy, .isTruthy)
    
    let equal: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Bool = BushelRT.numericEqual
    builder.addExternalFunctionAsGlobal(equal, .numericEqual)
    
    let newReal: @convention(c) (Double) -> Builtin.RTObjectPointer = BushelRT.newReal
    builder.addExternalFunctionAsGlobal(newReal, .newReal)
    
    let newInteger: @convention(c) (Int64) -> Builtin.RTObjectPointer = BushelRT.newInteger
    builder.addExternalFunctionAsGlobal(newInteger, .newInteger)
    
    let newBoolean: @convention(c) (Bool) -> Builtin.RTObjectPointer = BushelRT.newBoolean
    builder.addExternalFunctionAsGlobal(newBoolean, .newBoolean)
    
    let newString: @convention(c) (UnsafePointer<CChar>) -> Builtin.RTObjectPointer = BushelRT.newString
    builder.addExternalFunctionAsGlobal(newString, .newString)
    
    let newConstant: @convention(c) (OSType) -> Builtin.RTObjectPointer = BushelRT.newConstant
    builder.addExternalFunctionAsGlobal(newConstant, .newConstant)
    
    let newSymbolicConstant: @convention(c) (Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.newSymbolicConstant
    builder.addExternalFunctionAsGlobal(newSymbolicConstant, .newSymbolicConstant)
    
    let newClass: @convention(c) (Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.newClass
    builder.addExternalFunctionAsGlobal(newClass, .newClass)
    
    let newList: @convention(c) () -> Builtin.RTObjectPointer = BushelRT.newList
    builder.addExternalFunctionAsGlobal(newList, .newList)
    
    let newRecord: @convention(c) () -> Builtin.RTObjectPointer = BushelRT.newRecord
    builder.addExternalFunctionAsGlobal(newRecord, .newRecord)
    
    let newArgumentRecord: @convention(c) () -> Builtin.RTObjectPointer = BushelRT.newArgumentRecord
    builder.addExternalFunctionAsGlobal(newArgumentRecord, .newArgumentRecord)
    
    let addToList: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = BushelRT.addToList
    builder.addExternalFunctionAsGlobal(addToList, .addToList)
    
    let addToRecord: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = BushelRT.addToRecord
    builder.addExternalFunctionAsGlobal(addToRecord, .addToRecord)
    
    let addToArgumentRecord: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Void = BushelRT.addToArgumentRecord
    builder.addExternalFunctionAsGlobal(addToArgumentRecord, .addToArgumentRecord)
    
    let getFromArgumentRecord: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.getFromArgumentRecord
    builder.addExternalFunctionAsGlobal(getFromArgumentRecord, .getFromArgumentRecord)
    
    let getFromArgumentRecordWithDirectParamFallback: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.getFromArgumentRecordWithDirectParamFallback
    builder.addExternalFunctionAsGlobal(getFromArgumentRecordWithDirectParamFallback, .getFromArgumentRecordWithDirectParamFallback)
    
    let unaryOp: @convention(c) (Int64, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.unaryOp
    builder.addExternalFunctionAsGlobal(unaryOp, .unaryOp)
    
    let binaryOp: @convention(c) (Int64, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.binaryOp
    builder.addExternalFunctionAsGlobal(binaryOp, .binaryOp)
    
    let coerce: @convention(c) (Builtin.RTObjectPointer, Builtin.InfoPointer) -> Builtin.RTObjectPointer = BushelRT.coerce
    builder.addExternalFunctionAsGlobal(coerce, .coerce)
    
    let newSpecifier0: @convention(c) (Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32) -> Builtin.RTObjectPointer = BushelRT.newSpecifier0
    builder.addExternalFunctionAsGlobal(newSpecifier0, .newSpecifier0)
    let newSpecifier1: @convention(c) (Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.newSpecifier1
    builder.addExternalFunctionAsGlobal(newSpecifier1, .newSpecifier1)
    let newSpecifier2: @convention(c) (Builtin.RTObjectPointer?, Builtin.RTObjectPointer, UInt32, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.newSpecifier2
    builder.addExternalFunctionAsGlobal(newSpecifier2, .newSpecifier2)
    
    let newTestSpecifier: @convention(c) (UInt32, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.newTestSpecifier
    builder.addExternalFunctionAsGlobal(newTestSpecifier, .newTestSpecifier)
    
    let evaluateSpecifier: @convention(c) (Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.evaluateSpecifier
    builder.addExternalFunctionAsGlobal(evaluateSpecifier, .evaluateSpecifier)
    
    let call: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.call
    builder.addExternalFunctionAsGlobal(call, .call)
    
    let runWeave: @convention(c) (Builtin.RTObjectPointer, Builtin.RTObjectPointer, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.runWeave
    builder.addExternalFunctionAsGlobal(runWeave, .runWeave)
    
    do {
        let fn = builder.addFunction(".make-application-specifier", type: FunctionType([PointerType.toVoid], PointerType.toVoid))
        let block = fn.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: block)
        let result = builder.buildCall(toExternalFunction: .newSpecifier1, args: [PointerType.toVoid.null(), builder.buildGlobalString(TypedTermUID(TypeUID.application).normalized).asRTString(builder: builder), IntType.int32.constant(RT_Specifier.Kind.name.rawValue), fn.parameter(at: 0)!])
        builder.buildRet(result)
    }
    do {
        let fn = builder.addFunction(".make-application-id-specifier", type: FunctionType([PointerType.toVoid], PointerType.toVoid))
        let block = fn.appendBasicBlock(named: "entry")
        builder.positionAtEnd(of: block)
        let result = builder.buildCall(toExternalFunction: .newSpecifier1, args: [PointerType.toVoid.null(), builder.buildGlobalString(TypedTermUID(TypeUID.application).normalized).asRTString(builder: builder), IntType.int32.constant(RT_Specifier.Kind.id.rawValue), fn.parameter(at: 0)!])
        builder.buildRet(result)
    }
    
    let main = builder.addFunction("main", type: FunctionType([], PointerType.toVoid))
    let entry = main.appendBasicBlock(named: "entry")
    builder.positionAtEnd(of: entry)
    var stack = StaticStack()
    do {
        let resultIRValue = try expression.generateLLVMIR(builder, rt, &stack, options: CodeGenOptions(stackIntrospectability: false), lastResult: builder.rtNull)
        builder.buildRet(resultIRValue)
    } catch {
        fatalError("unhandled error \(error)")
    }
    
    let pipeliner = PassPipeliner(module: module)
    pipeliner.addStandardModulePipeline("std_module")
    pipeliner.addStandardFunctionPipeline("std_fn")
    pipeliner.execute()
    
    #if DEBUG
    module.dump()
    #endif
    
    return module
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
    public func generateLLVMIR(_ builder: IRBuilder, _ rt: RTInfo, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue, evaluateSpecifiers: Bool = true) throws -> IRValue {
        let currentBlock = builder.insertBlock!
        let function = currentBlock.parent!
        
        switch kind {
        case .topLevel: // MARK: .topLevel
            fatalError()
        case .empty, .end, .that: // MARK: .empty, .end., .that
            return lastResult
        case .it: // MARK: .it
            return stack.currentTarget ?? builder.rtNull
        case .null: // MARK: .null
            return builder.rtNull
        case .scoped(let sequence): // MARK: .scoped
            stack.push()
            defer {
                stack.pop()
            }
            
            if options.stackIntrospectability {
                builder.buildCall(toExternalFunctionReturningVoid: .pushFrame, args: [])
            }
            defer {
                if options.stackIntrospectability {
                    builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [])
                }
            }
            
            return try sequence.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
        case .parentheses(let expression): // MARK: .parentheses
            return try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
        case let .if_(condition, then, else_): // MARK: .if_
            let conditionValue = try condition.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            
            var conditionTest: IRValue!
            switch LLVMGetTypeKind(LLVMTypeOf(conditionValue.asLLVM())!) {
            case LLVMIntegerTypeKind:
                conditionTest = builder.buildICmp(conditionValue, IntType.int64.constant(0), .notEqual)
            case LLVMDoubleTypeKind:
                conditionTest = builder.buildFCmp(conditionValue, FloatType.double.constant(0.0), .orderedNotEqual)
            default: // pointer to RT_Object
                conditionTest = builder.buildCall(toExternalFunction: .isTruthy, args: [conditionValue])
            }
            
            if options.stackIntrospectability {
                builder.buildCall(toExternalFunctionReturningVoid: .pushFrame, args: [])
            }
            defer {
                if options.stackIntrospectability {
                    builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [])
                }
            }
            
            var thenBlock = function.appendBasicBlock(named: "then")
            var elseBlock = BasicBlock(context: builder.module.context, name: "else")
            let mergeBlock = BasicBlock(context: builder.module.context, name: "merge")
            
            builder.buildCondBr(condition: conditionTest, then: thenBlock, else: elseBlock)
            
            builder.positionAtEnd(of: thenBlock)
            let thenValue = try then.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            if !thenValue.isAReturnInst {
                builder.buildBr(mergeBlock)
            }
            thenBlock = builder.insertBlock!
            
            function.append(elseBlock)
            builder.positionAtEnd(of: elseBlock)
            let elseValue: IRValue
            if let else_ = else_ {
                elseValue = try else_.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                elseBlock = builder.insertBlock!
            } else {
                elseValue = lastResult
            }
            if !elseValue.isAReturnInst {
                builder.buildBr(mergeBlock)
            }
            
            function.append(mergeBlock)
            builder.positionAtEnd(of: mergeBlock)
            
            switch (thenValue.isAReturnInst, elseValue.isAReturnInst) {
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
        case .repeatTimes(times: let times, repeating: let repeating): // MARK: .repeatTimes
            let repeatBlock = BasicBlock(context: builder.module.context, name: "repeat")
            let afterRepeatBlock = BasicBlock(context: builder.module.context, name: "after-repeat")
            
            let result: IRValue
            
            let timesValue = try times.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            
            builder.buildBr(repeatBlock)
            
            function.append(repeatBlock)
            builder.positionAtEnd(of: repeatBlock)
            
            let repeatCount = builder.buildPhi(FloatType.double)
            repeatCount.addIncoming([(FloatType.double.constant(0), currentBlock)])
            
            result = try repeating.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            
            let newRepeatCount = builder.buildBinaryOperation(.fadd, repeatCount, FloatType.double.constant(1))
            repeatCount.addIncoming([(newRepeatCount, repeatBlock)])
            let newRepeatCountObj = newRepeatCount.asRTReal(builder: builder)
            
            let shouldEndRepeat = builder.buildCall(toExternalFunction: .numericEqual, args: [newRepeatCountObj, timesValue])
            
            builder.buildCall(toExternalFunctionReturningVoid: .release, args: [newRepeatCountObj])
            
            builder.buildCondBr(condition: shouldEndRepeat, then: afterRepeatBlock, else: repeatBlock)
            
            function.append(afterRepeatBlock)
            builder.positionAtEnd(of: afterRepeatBlock)
            
            return result
        case .tell(let target, let to): // MARK: .tell
            let targetValue = try target.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            
            stack.currentTarget = targetValue
            
            builder.buildCall(toExternalFunctionReturningVoid: .pushFrameWithTarget, args: [targetValue])
            defer {
                builder.buildCall(toExternalFunctionReturningVoid: .popFrame, args: [])
            }
            
            return try to.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
        case .let_(let term, let initialValue): // MARK: .let_
            let initialIRValue = try initialValue?.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult) ?? builder.rtNull
            
            let termIRValue = term.term.irPointerValue(builder: builder)
            
            builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [termIRValue, initialIRValue])
            
            return initialIRValue
        case .return_(let returnValue): // MARK: .return_
            let returnIRValue = (try returnValue?.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult) ?? builder.rtNull)
            
            return builder.buildRet(returnIRValue)
        case .integer(let value):
            return IntType.int64.constant(value).asRTInteger(builder: builder)
        case .double(let value): // MARK: .number
            return FloatType.double.constant(value).asRTReal(builder: builder)
        case .string(let value): // MARK: .string
            return builder.addGlobalString(name: "str", value: value).asRTString(builder: builder)
        case .list(let expressions): // MARK: .list
            let listIRValue = builder.buildCall(toExternalFunction: .newList, args: [])
            
            for expression in expressions {
                let expressionIRValue = try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToList, args: [listIRValue, expressionIRValue])
            }
            
            return listIRValue
        case .record(let keyValues): // MARK: .record
            let recordIRValue = builder.buildCall(toExternalFunction: .newRecord, args: [])
            
            for (key, value) in keyValues {
                let keyIRValue = try key.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
                let valueIRValue = try value.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                
                builder.buildCall(toExternalFunctionReturningVoid: .addToRecord, args: [recordIRValue, keyIRValue, valueIRValue])
            }
            
            return recordIRValue
        case .prefixOperator(let operation, let operand), .postfixOperator(let operation, let operand): // MARK: .prefixOperator, .postfixOperator
            return builder.buildCall(toExternalFunction: .unaryOp, args: [IntType.int64.constant(operation.rawValue), try operand.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)])
        case .infixOperator(let operation, let lhs, let rhs): // MARK: .infixOperator
            return builder.buildCall(toExternalFunction: .binaryOp, args: [IntType.int64.constant(operation.rawValue), try lhs.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult), try rhs.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)])
        case .coercion(of: let expression, to: let type): // MARK: .coercion
            return builder.buildCall(toExternalFunction: .coerce, args: [try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult), rt.type(forUID: type.term.typedUID)!.irPointerValue(builder: builder)])
        case .variable(let term): // MARK: .variable
            let termIRValue = term.irPointerValue(builder: builder)
            
            return builder.buildCall(toExternalFunction: .getVariableValue, args: [termIRValue])
        case .use(let term), // MARK: .use
             .resource(let term): // MARK: .resource
            switch term.term.resource {
            case .applicationByName: // MARK: .applicationByName
                let appNameIRValue = builder.module.addGlobalString(name: "app-name", value: term.description).asRTString(builder: builder)
                return builder.buildCall(builder.module.function(named: ".make-application-specifier")!, args: [appNameIRValue])
            case .applicationByID: // MARK: .applicationByID
                let appIDIRValue = builder.module.addGlobalString(name: "app-id", value: term.description).asRTString(builder: builder)
                return builder.buildCall(builder.module.function(named: ".make-application-id-specifier")!, args: [appIDIRValue])
            }
        case .enumerator(let term as Term): // MARK: .enumerator
            if let code = term.ae4Code {
                return builder.buildCall(toExternalFunction: .newConstant, args: [IntType.int32.constant(code)])
            } else {
                return builder.buildCall(toExternalFunction: .newSymbolicConstant, args: [builder.module.addGlobalString(name: "symbolic-constant-uid", value: term.typedUID.normalized).asRTString(builder: builder)])
            }
        case .class_(let term as Term): // MARK: .class_
            return builder.buildCall(toExternalFunction: .newClass, args: [builder.module.addGlobalString(name: "class-uid", value: term.typedUID.normalized).asRTString(builder: builder)])
        case .set(let expression, to: let newValueExpression): // MARK: .set
            if case .variable(let variableTerm) = expression.kind {
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                
                let termIRValue = variableTerm.irPointerValue(builder: builder)
                
                return builder.buildCall(toExternalFunctionReturningVoid: .setVariableValue, args: [termIRValue, newValueIRValue])
            } else {
                let directParameterTermIRValue = rt.termPool.term(forUID: TypedTermUID(ParameterUID.direct))!.irPointerValue(builder: builder)
                let toParameterTermIRValue = rt.termPool.term(forUID: TypedTermUID(ParameterUID.set_to))!.irPointerValue(builder: builder)
                let expressionIRValue = try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
                let newValueIRValue = try newValueExpression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                
                let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [arguments, directParameterTermIRValue, expressionIRValue])
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [arguments, toParameterTermIRValue, newValueIRValue])
                
                let command = rt.command(forUID: TypedTermUID(CommandUID.set))!
                let setCommandIRValue = command.irPointerValue(builder: builder)
                
                return builder.buildCall(toExternalFunction: .call, args: [setCommandIRValue, arguments])
            }
            
        case .command(let term, let parameters): // MARK: .command
            let parameterIRValues: [(term: IRValue, value: IRValue)] = try parameters.map { kv in
                let (parameterTerm, parameterValue) = kv
                let termIRValue = parameterTerm.term.irPointerValue(builder: builder)
                let valueIRValue = try parameterValue.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
                return (termIRValue, valueIRValue)
            }
            
            let arguments = builder.buildCall(toExternalFunction: .newArgumentRecord, args: [])
            for parameter in parameterIRValues {
                builder.buildCall(toExternalFunctionReturningVoid: .addToArgumentRecord, args: [arguments, parameter.term, parameter.value])
            }
            
            if
                let name = term.name,
                let function = stack.function(for: name)
            {
                return builder.buildCall(function, args: [arguments])
            } else {
                let commandIRValue = rt.command(forUID: term.term.typedUID)!.irPointerValue(builder: builder)
                return builder.buildCall(toExternalFunction: .call, args: [commandIRValue, arguments])
            }
            
        case .reference(let expression): // MARK: .reference
            return try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
        case .get(let expression): // MARK: .get
            return try expression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: true)
        case .specifier(let specifier): // MARK: .specifier
            let specifierIRValue = try specifier.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            return evaluateSpecifiers ? specifierIRValue.evaluatingSpecifier(builder: builder) : specifierIRValue
        case .function(let name, let parameters, let arguments, let body): // MARK: .function
            let prevBlock = builder.insertBlock!
            
            let functionLLVMName = llvmify(name.name!)
            let argumentsIRTypes = [PointerType.toVoid]
            
            let function = builder.addFunction(functionLLVMName, type: FunctionType(argumentsIRTypes, PointerType.toVoid))
            let entry = function.appendBasicBlock(named: "entry")
            builder.positionAtEnd(of: entry)
            
            let actualArguments = function.parameter(at: 0)!
            
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
            if
                let firstParam = parameters.first,
                let firstArg = arguments.first
            {
                let firstArgVariableTermIRValue = firstArg.term.irPointerValue(builder: builder)
                let firstArgValueIRValue = builder.buildCall(toExternalFunction: .getFromArgumentRecordWithDirectParamFallback, args: [actualArguments, firstParam.term.irPointerValue(builder: builder)])
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [firstArgVariableTermIRValue, firstArgValueIRValue])
            }
            
            for (parameter, argument) in zip(parameters, arguments).dropFirst() {
                let argumentVariableTermIRValue = argument.term.irPointerValue(builder: builder)
                let argumentValueIRValue = builder.buildCall(toExternalFunction: .getFromArgumentRecord, args: [actualArguments, parameter.term.irPointerValue(builder: builder)])
                builder.buildCall(toExternalFunctionReturningVoid: .newVariable, args: [argumentVariableTermIRValue, argumentValueIRValue])
            }
            
            stack.currentFrame.add(function: function, for: name.name!)
            
            let resultValue = try body.generateLLVMIR(builder, rt, &stack, options: CodeGenOptions(stackIntrospectability: false), lastResult: builder.rtNull)
            builder.buildRet(resultValue)
            
            builder.positionAtEnd(of: prevBlock)
            
            return lastResult
        case .weave(let hashbang, let body): // MARK: .weave
            let hashbangRTString = builder.addGlobalString(name: "weave-hashbang", value: hashbang.invocation).asRTString(builder: builder)
            let bodyRTString = builder.addGlobalString(name: "weave-body", value: body).asRTString(builder: builder)
            
            return builder.buildCall(toExternalFunction: .runWeave, args: [hashbangRTString, bodyRTString, lastResult])
        case .endWeave: // MARK: .endWeave
            return lastResult
        }
    }
    
}

private func llvmify(_ name: TermName) -> String {
    return name.normalized.replacingOccurrences(of: " ", with: "_")
}

extension Sequence {
    
    /// Recursively builds an LLVM IR program out of this expression.
    ///
    /// - Parameters:
    ///   - builder: The `IRBuilder` to use.
    ///   - options: A set of options that control how the code is generated.
    ///   - lastResult: The last result produced by the program. This value
    ///                 is produced by the `that` keyword. Also, if no value
    ///                 is produced by this expression, `lastResult`
    ///                 is returned back.
    /// - Returns: The resultant `IRValue` from building the code for this
    ///            expression.
    public func generateLLVMIR(_ builder: IRBuilder, _ rt: RTInfo, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue) throws -> IRValue {
        return try expressions
            .filter { if case .end = $0.kind { return false } else { return true } }
            .reduce(lastResult, { (lastResult, expression) -> IRValue in
                guard !lastResult.isAReturnInst else {
                    // We've already returned; generating more code can
                    // confuse phi nodes
                    return lastResult
                }
                return try expression
                    .generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            })
    }
    
}

protocol IRPointerConvertible {
}

extension IRPointerConvertible {
    
    func irPointerValue(builder: IRBuilder) -> IRValue {
        return builder.buildIntToPtr(IntType.int64.constant(UInt(bitPattern: BushelRT.toOpaque(self))), type: .toVoid)
    }
    
}

extension Bushel.Term: IRPointerConvertible {}
extension TypeInfo: IRPointerConvertible {}
extension CommandInfo: IRPointerConvertible {}
extension ParameterInfo: IRPointerConvertible {}
extension PropertyInfo: IRPointerConvertible {}

extension Specifier {
    
    public func generateLLVMIR(_ builder: IRBuilder, _ rt: RTInfo, _ stack: inout StaticStack, options: CodeGenOptions, lastResult: IRValue) throws -> IRValue {
        let uidIRValue = builder.buildGlobalString(idTerm.term.typedUID.normalized).asRTString(builder: builder)
        
        let parentIRValue = try parent?.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false) ?? PointerType.toVoid.null()
        
        let dataExpressionIRValues: [IRValue]
        if case .test(let expression) = kind {
            guard
                let (operation, lhs, rhs): (BinaryOperation, Expression, Expression) =
                    {
                        var expression = expression
                        while true {
                            switch expression.kind {
                            case .parentheses(let subexpression):
                                expression = subexpression
                            case let .infixOperator(operation, lhs, rhs):
                                return (operation, lhs, rhs)
                            default:
                                return nil
                            }
                        }
                    }()
            else {
                fatalError("test clause expression improperly validated by the parser")
            }
            
            let lhsIRValue = try lhs.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
            let rhsIRValue = try rhs.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult, evaluateSpecifiers: false)
            
            dataExpressionIRValues = [builder.buildCall(toExternalFunction: .newTestSpecifier, args: [IntType.int32.constant(operation.rawValue), lhsIRValue, rhsIRValue])]
        } else {
            dataExpressionIRValues = try allDataExpressions().map { dataExpression in
                try dataExpression.generateLLVMIR(builder, rt, &stack, options: options, lastResult: lastResult)
            }
        }
        
        switch kind {
        case .simple:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.simple.rawValue), dataExpressionIRValues[0]])
        case .index:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.index.rawValue), dataExpressionIRValues[0]])
        case .name:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.name.rawValue), dataExpressionIRValues[0]])
        case .id:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.id.rawValue), dataExpressionIRValues[0]])
        case .all:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.all.rawValue)])
        case .first:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.first.rawValue)])
        case .middle:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.middle.rawValue)])
        case .last:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.last.rawValue)])
        case .random:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.random.rawValue)])
        case .before:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.before.rawValue), dataExpressionIRValues[0]])
        case .after:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.after.rawValue), dataExpressionIRValues[0]])
        case .range:
            return builder.buildCall(toExternalFunction: .newSpecifier2, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.range.rawValue), dataExpressionIRValues[0], dataExpressionIRValues[1]])
        case .test:
            return builder.buildCall(toExternalFunction: .newSpecifier1, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.test.rawValue), dataExpressionIRValues[0]])
        case .property:
            return builder.buildCall(toExternalFunction: .newSpecifier0, args: [parentIRValue, uidIRValue, IntType.int32.constant(RT_Specifier.Kind.property.rawValue)])
        }
    }
    
}

extension IRValue {
    
    func evaluatingSpecifier(builder: IRBuilder) -> IRValue {
        guard type.asLLVM() == PointerType.toVoid.asLLVM() else {
            return self
        }
        return builder.buildCall(toExternalFunction: .evaluateSpecifier, args: [self])
    }
    
}

extension IRValue {
    
    func asRTReal(builder: IRBuilder) -> IRValue {
        return builder.buildCall(toExternalFunction: .newReal, args: [self])
    }
    
    func asRTInteger(builder: IRBuilder) -> IRValue {
        return builder.buildCall(toExternalFunction: .newInteger, args: [self])
    }
    
    func asRTBoolean(builder: IRBuilder) -> IRValue {
        return builder.buildCall(toExternalFunction: .newBoolean, args: [self])
    }
    
    func asRTString(builder: IRBuilder) -> IRValue {
        let opaquedSelf = builder.buildPointerCast(of: self, to: PointerType.toVoid, name: "opaqued-str")
        return builder.buildCall(toExternalFunction: .newString, args: [opaquedSelf])
    }
    
}
