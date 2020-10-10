import LLVM

// MARK: 0/3 Steps to add a builtin function
// NOTE: Use breadcrumbs bar to see all steps.

enum BuiltinFunction: String {
    
    // MARK: 1/3 Declare enum case
    case release
    case pushFrame, popFrame
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
    case newScript
    case newFunction
    case runCommand
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
        case .qualifySpecifier: return ([object, object], object)
        case .evaluateSpecifier: return ([object], object)
        case .newScript: return ([object], object)
        case .newFunction: return ([object, PointerType.toVoid, object], object)
        case .runCommand: return ([object, object, object], object)
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
    
}
