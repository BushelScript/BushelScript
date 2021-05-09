import Bushel

// MARK: Definition

/// A runtime function.
public class RT_Function: RT_Object {
    
    public typealias ParameterSignature = [ParameterInfo : TypeInfo]
    
    public struct Signature: Hashable {
        
        var command: CommandInfo
        var parameters: ParameterSignature
        
    }
    
    public var signature: Signature
    
    var implementation: RT_Implementation
    
    init(_ rt: Runtime, signature: Signature, implementation: RT_Implementation) {
        self.signature = signature
        self.implementation = implementation
        super.init(rt)
    }
    
    private static let typeInfo_ = TypeInfo(.function)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "function"
    }
    
    public func call(arguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        try implementation.run(arguments: arguments)
    }
    
}

public protocol RT_Implementation {
    
    func run(arguments: [ParameterInfo : RT_Object]) throws -> RT_Object
    
}

public struct RT_SwiftImplementation: RT_Implementation {
    
    public typealias Function = (_ arguments: [ParameterInfo : RT_Object]) throws -> RT_Object
    
    var function: Function
    
    public init(function: @escaping Function) {
        self.function = function
    }
    
    public func run(arguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        try function(arguments)
    }
    
}

public struct RT_ExpressionImplementation: RT_Implementation {
    
    var rt: Runtime
    var functionExpression: Expression
    
    public init(rt: Runtime, functionExpression: Expression) {
        self.rt = rt
        self.functionExpression = functionExpression
    }
    
    public func run(arguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        try rt.runFunction(functionExpression, actualArguments: arguments)
    }
    
}
