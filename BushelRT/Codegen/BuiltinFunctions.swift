import LLVM

// MARK: 0/3 Steps to add a builtin function
// NOTE: Use breadcrumbs bar to see all steps.

enum BuiltinFunction: String {
    
    // MARK: 1/3 Declare enum case
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
        
        // MARK: 2/3 Declare parameter/return types
        // NOTE: The first `Builtin` parameter is implicit. Do not specify it here.
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

/// "Opens" a pointer to a Builtin object so that methods can be called on it.
/// Used as a shorthand in building C-convention builtin function thunks.
private func ø /* ⌥O */(_ builtinPointer: Builtin.Pointer) -> Builtin {
    Builtin.fromOpaque(builtinPointer)
}

// MARK: Function table building
extension BuiltinFunction {
    
    // MARK: 3/3 Add a pointer to the function as an LLVM-accessible global
    static func addFunctions(to builder: IRBuilder) {
        
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
        
    }
    
}
