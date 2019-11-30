import Bushel
import LLVMSwift

func isTruthy(_ arg1: Builtin.RTObjectPointer) -> Bool {
    return Builtin.isTruthy(arg1)
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

func evaluateSpecifier(class: OSType, byIndex index: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.evaluateSpecifier(class: `class`, byIndex: index)
}

func evaluateSpecifier(class: OSType, byName name: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.evaluateSpecifier(class: `class`, byName: name)
}

func evaluateSpecifier(class: OSType, byID id: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.evaluateSpecifier(class: `class`, byID: id)
}

func evaluateSpecifier(class: OSType, by key: Builtin.RTObjectPointer) -> Builtin.RTObjectPointer {
    return Builtin.evaluateSpecifier(class: `class`, by: key)
}

extension IRBuilder {
    
    var rtNull: IRValue {
        return buildLoad(module.global(named: "rt_null")!, type: PointerType.toVoid)
    }
    
}

extension IRBuilder {
    
    /// `FnPtr` **must** have `@convention(c)`.
    func addExternalFunctionAsGlobal<FnPtr>(_ fnPtr: FnPtr, name: String, type: FunctionType) {
        let fnAddress = unsafeBitCast(fnPtr, to: UInt.self)
        let pointerType = PointerType(pointee: type)
        let pointerIRValue = buildIntToPtr(IntType.int64.constant(fnAddress), type: pointerType)
        addGlobal(name, type: pointerType).initializer = pointerIRValue
    }
    
}

public func generateLLVMModule(from expression: ExpressionProtocol) -> Module {
    let module = Module(name: "main")
    let builder = IRBuilder(module: module)
    
    let rtObjectIRType = PointerType.toVoid
    
    module.addGlobal("rt_null", type: PointerType.toVoid).initializer = builder.buildIntToPtr(IntType.int64.constant(Int(bitPattern: Builtin.toOpaque(RT_Null.null))), type: .toVoid)
    
    let newReal: @convention(c) (Double) -> Builtin.RTObjectPointer = BushelRT.newReal
    builder.addExternalFunctionAsGlobal(newReal, name: "rt_newReal", type: FunctionType([FloatType.double], rtObjectIRType))
    
    let newInteger: @convention(c) (Int64) -> Builtin.RTObjectPointer = BushelRT.newInteger
    builder.addExternalFunctionAsGlobal(newInteger, name: "rt_newInteger", type: FunctionType([IntType.int64], rtObjectIRType))
    
    let newBoolean: @convention(c) (Bool) -> Builtin.RTObjectPointer = BushelRT.newBoolean
    builder.addExternalFunctionAsGlobal(newBoolean, name: "rt_newBoolean", type: FunctionType([IntType.int1], rtObjectIRType))
    
    let newString: @convention(c) (UnsafePointer<CChar>) -> Builtin.RTObjectPointer = BushelRT.newString
    builder.addExternalFunctionAsGlobal(newString, name: "rt_newString", type: FunctionType([PointerType.toVoid], rtObjectIRType))
    
    let evaluateByIndex: @convention(c) (OSType, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.evaluateSpecifier(class:byIndex:)
    builder.addExternalFunctionAsGlobal(evaluateByIndex, name: "rt_evaluateByIndex", type: FunctionType([IntType.int32, rtObjectIRType], rtObjectIRType))
    
    let evaluateByName: @convention(c) (OSType, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.evaluateSpecifier(class:byName:)
    builder.addExternalFunctionAsGlobal(evaluateByName, name: "rt_evaluateByName", type: FunctionType([IntType.int32, rtObjectIRType], rtObjectIRType))
    
    let evaluateByID: @convention(c) (OSType, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.evaluateSpecifier(class:byID:)
    builder.addExternalFunctionAsGlobal(evaluateByID, name: "rt_evaluateByID", type: FunctionType([IntType.int32, rtObjectIRType], rtObjectIRType))
    
    let evaluateSimple: @convention(c) (OSType, Builtin.RTObjectPointer) -> Builtin.RTObjectPointer = BushelRT.evaluateSpecifier(class:by:)
    builder.addExternalFunctionAsGlobal(evaluateSimple, name: "rt_evaluateSimple", type: FunctionType([IntType.int32, rtObjectIRType], rtObjectIRType))
    
    let main = builder.addFunction("main", type: FunctionType([], rtObjectIRType))
    let entry = main.appendBasicBlock(named: "entry")
    builder.positionAtEnd(of: entry)
    let irValue = expression.generateLLVMIR(builder, context: module.context, lastResult: builder.rtNull)
    builder.buildRet(irValue)
    
    return module
}

// TMP
public func run(_ expression: ExpressionProtocol) {
    let module = generateLLVMModule(from: expression)
    
    let pipeliner = PassPipeliner(module: module)
    pipeliner.addStandardModulePipeline("std_module")
    pipeliner.addStandardFunctionPipeline("std_fn")
    pipeliner.execute()
    
    module.dump()
    
    let jit = try! JIT(machine: TargetMachine())
    typealias FnPtr = @convention(c) () -> UnsafeMutableRawPointer
    _ = try! jit.addEagerlyCompiledIR(module, { (name) -> JIT.TargetAddress in
        return JIT.TargetAddress()
    })
    
    let address = try! jit.address(of: "main")
    let fn = unsafeBitCast(address, to: FnPtr.self)
    print(Unmanaged<RT_Object_ObjC>.fromOpaque(fn()).takeUnretainedValue())
}

extension ExpressionProtocol {
    func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        switch self {
        case let self as Sequence:
            return self.generateLLVMIR(builder, context: context, lastResult: lastResult)
        case let self as Expression:
            return self.generateLLVMIR(builder, context: context, lastResult: lastResult)
        default:
            fatalError()
        }
    }
}

extension Sequence {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        return expressions
            .filter { $0.kind != .end }
            .reduce(lastResult, { (lastResult, expression) -> IRValue in
                return expression.generateLLVMIR(builder, context: context, lastResult: lastResult)
            })
            .asDynamicObject(builder: builder)
    }
}

extension Expression {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        let currentBlock = builder.insertBlock!
        let function = currentBlock.parent!
        
        switch kind {
        case .topLevel:
            fatalError()
        case .parentheses(let expression):
            return expression.generateLLVMIR(builder, context: context, lastResult: lastResult)
        case let .if_(condition, then, else_):
            let conditionValue = condition.generateLLVMIR(builder, context: context, lastResult: lastResult)
            
            var conditionTest: IRValue!
            switch LLVMGetTypeKind(LLVMTypeOf(conditionValue.asLLVM())!) {
            case LLVMIntegerTypeKind:
                conditionTest = builder.buildICmp(conditionValue, IntType.int64.constant(0), .notEqual)
            case LLVMDoubleTypeKind:
                conditionTest = builder.buildFCmp(conditionValue, FloatType.double.constant(0.0), .orderedNotEqual)
            default: // pointer to RT_Object
                let isTruthy: @convention(c) (Builtin.RTObjectPointer) -> Bool = BushelRT.isTruthy
                let fnType = FunctionType([PointerType.toVoid], IntType.int1)
                let fnAddress = unsafeBitCast(isTruthy, to: UInt.self)
                conditionTest = builder.buildCall(builder.buildIntToPtr(IntType.int64.constant(fnAddress), type: PointerType(pointee: fnType)), args: [conditionValue], name: "is_truthy")
            }
            
            var thenBlock = function.appendBasicBlock(named: "then")
            var elseBlock = BasicBlock(context: context, name: "else")
            let mergeBlock = BasicBlock(context: context, name: "merge")
            
            builder.buildCondBr(condition: conditionTest, then: thenBlock, else: elseBlock)
            
            builder.positionAtEnd(of: thenBlock)
            let thenValue = then.generateLLVMIR(builder, context: context, lastResult: lastResult).asDynamicObject(builder: builder)
            builder.buildBr(mergeBlock)
            thenBlock = builder.insertBlock!
            
            function.append(elseBlock)
            builder.positionAtEnd(of: elseBlock)
            var elseValue: IRValue!
            if let else_ = else_ {
                elseValue = else_.generateLLVMIR(builder, context: context, lastResult: lastResult).asDynamicObject(builder: builder)
                elseBlock = builder.insertBlock!
            } else {
                elseValue = builder.rtNull
            }
            builder.buildBr(mergeBlock)
            
            function.append(mergeBlock)
            builder.positionAtEnd(of: mergeBlock)
            
            let phi = builder.buildPhi(PointerType.toVoid, name: else_ == nil ? "if-then" : "if-then-else")
            phi.addIncoming([(thenValue, thenBlock), (elseValue, elseBlock)])
            return phi
        case .tell(let target, let to):
            let toBlock = BasicBlock(context: context, name: "to")
            
            let targetValue = target.generateLLVMIR(builder, context: context, lastResult: lastResult)
            builder.buildBr(toBlock)
            
            function.append(toBlock)
            builder.positionAtEnd(of: toBlock)
            let toValue = to.generateLLVMIR(builder, context: context, lastResult: lastResult)
            return toValue
        case .testExpression(let expression):
            fatalError()
        case .end:
            fatalError()
        case .null:
            return builder.rtNull
        case .that:
            return lastResult
        case .number(let value):
            return FloatType.double.constant(value)
        case .string(let value):
            let globalString = builder.addGlobalString(name: "str", value: value)
            return builder.buildCall(builder.buildLoad(builder.module.global(named: "rt_newString")!, type: PointerType(pointee: FunctionType([PointerType.toVoid], PointerType.toVoid))), args: [globalString], name: "rt_string")
        case .constant(let term), .enumerator(let term), .class_(let term), .property(let term), .command(let term):
            // TODO: rly
            return builder.rtNull
        case .specifier(let specifier):
            return specifier.generateLLVMIR(builder, context: context, lastResult: lastResult)
        }
    }
}

extension Specifier {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        switch self {
        case .simple(let simple):
            return simple.generateLLVMIR(builder, context: context, lastResult: lastResult)
        case .ordinal(let ordinal):
            return ordinal.generateLLVMIR(builder, context: context, lastResult: lastResult)
        case .range(let range):
            return range.generateLLVMIR(builder, context: context, lastResult: lastResult)
        case .test(let test):
            return test.generateLLVMIR(builder, context: context, lastResult: lastResult)
        }
    }
}

extension IRBuilder {
    
    func buildCallToExternalFunction(named fnName: String, _ parameterTypes: [IRType], _ returnType: IRType = PointerType.toVoid, args: [IRValue]) -> Call {
        let fnType = FunctionType(parameterTypes, returnType)
        let fnPointerValue = buildLoad(module.global(named: fnName)!, type: PointerType(pointee: fnType))
        return buildCall(fnPointerValue, args: args)
    }
    
}

extension SimpleSpecifier {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        let dataExpressionIRValue = dataExpression
            .generateLLVMIR(builder, context: context, lastResult: lastResult)
            .asDynamicObject(builder: builder)
        
        guard case .class_(let typeCode?) = class_.definition else {
            fatalError("for now, must have a typecode to evaluate")
        }
        let typeCodeConstant = IntType.int32.constant(typeCode)
        
        if let kind = kind {
            switch kind {
            case .index:
                return builder.buildCallToExternalFunction(named: "rt_evaluateByIndex", [IntType.int32, PointerType.toVoid], args: [typeCodeConstant, dataExpressionIRValue])
            case .name:
                return builder.buildCallToExternalFunction(named: "rt_evaluateByName", [IntType.int32, PointerType.toVoid], args: [typeCodeConstant, dataExpressionIRValue])
            case .id:
                return builder.buildCallToExternalFunction(named: "rt_evaluateByID", [IntType.int32, PointerType.toVoid], args: [typeCodeConstant, dataExpressionIRValue])
            case .relative:
                return builder.rtNull // TODO: rly
            }
        } else {
            return builder.buildCallToExternalFunction(named: "rt_evaluateSimple", [IntType.int32, PointerType.toVoid], args: [typeCodeConstant, dataExpressionIRValue])
        }
    }
}

extension OrdinalSpecifier {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        guard case .class_(let typeCode?) = class_.definition else {
            fatalError("for now, must have a typecode to evaluate")
        }
        let typeCodeConstant = IntType.int32.constant(typeCode)
        
        switch kind {
        case .first:
            return builder.buildCallToExternalFunction(named: "rt_evaluateOrdinalFirst", [IntType.int32], args: [typeCodeConstant])
        case .middle:
            return builder.buildCallToExternalFunction(named: "rt_evaluateOrdinalMiddle", [IntType.int32], args: [typeCodeConstant])
        case .last:
            return builder.buildCallToExternalFunction(named: "rt_evaluateOrdinalLast", [IntType.int32], args: [typeCodeConstant])
        case .random:
            return builder.buildCallToExternalFunction(named: "rt_evaluateOrdinalRandom", [IntType.int32], args: [typeCodeConstant])
        }
    }
}

extension RangeSpecifier {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        return builder.rtNull
    }
}

extension TestSpecifier {
    public func generateLLVMIR(_ builder: IRBuilder, context: Context, lastResult: IRValue) -> IRValue {
        return builder.rtNull
    }
}

/// Returns the common IRType of `l` and `r` for the purposes of BushelScript
/// compilation, and returns the input values promoted as necessary.
private func commonizeType(_ l: IRValue, _ r: IRValue, builder: IRBuilder) -> (IRType, IRValue, IRValue) {
    switch (l.kind, r.kind) {
    case (.constantInt, .constantInt):
        return (IntType.int64, l, r)
    case (.constantInt, .constantFloat):
        return (FloatType.double, builder.buildCast(.fpToSI, value: l, type: FloatType.double), r)
    case (.constantFloat, .constantInt):
        return (FloatType.double, l, builder.buildCast(.fpToSI, value: r, type: FloatType.double))
    case (.constantFloat, .constantFloat):
        return (FloatType.double, builder.buildCast(.fpToSI, value: l, type: FloatType.double), r)
    case (.constantInt, _):
        return (PointerType.toVoid, l.asRTInteger(builder: builder), r)
    case (_, .constantInt):
        return (PointerType.toVoid, l, r.asRTInteger(builder: builder))
    case (.constantFloat, _):
        return (PointerType.toVoid, l.asRTReal(builder: builder), r)
    case (_, .constantFloat):
        return (PointerType.toVoid, l, r.asRTReal(builder: builder))
    default:
        return (PointerType.toVoid, l, r)
    }
}

extension IRValue {
    
    func asDynamicObject(builder: IRBuilder) -> IRValue {
        switch LLVMGetTypeKind(LLVMTypeOf(asLLVM())!) {
        case LLVMIntegerTypeKind:
            return LLVMTypeOf(asLLVM())! == LLVMInt1Type()! ? asRTBoolean(builder: builder) : asRTInteger(builder: builder)
        case LLVMDoubleTypeKind:
            return asRTReal(builder: builder)
        default:
            return self
        }
    }
    
    func asRTReal(builder: IRBuilder) -> IRValue {
        return builder.buildCall(builder.buildLoad(builder.module.global(named: "rt_newReal")!, type: PointerType(pointee: FunctionType([FloatType.double], PointerType.toVoid))), args: [self], name: "rt_real")
    }
    
    func asRTInteger(builder: IRBuilder) -> IRValue {
        return builder.buildCall(builder.buildLoad(builder.module.global(named: "rt_newInteger")!, type: PointerType(pointee: FunctionType([IntType.int64], PointerType.toVoid))), args: [self], name: "rt_integer")
    }
    
    func asRTBoolean(builder: IRBuilder) -> IRValue {
        return builder.buildCall(builder.buildLoad(builder.module.global(named: "rt_newBoolean")!, type: PointerType(pointee: FunctionType([IntType.int1], PointerType.toVoid))), args: [self], name: "rt_boolean")
    }
    
}
