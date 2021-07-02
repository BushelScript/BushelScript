import Bushel

// MARK: Definition

/// A runtime function.
public class RT_Function: RT_Object {
    
    public typealias ParameterSignature = [Reflection.Parameter : Reflection.`Type`]
    
    public struct Signature: Hashable {
        
        var command: Reflection.Command
        var parameters: ParameterSignature
        
    }
    
    public var signature: Signature
    
    var implementation: RT_Implementation
    
    init(_ rt: Runtime, signature: Signature, implementation: RT_Implementation) {
        self.signature = signature
        self.implementation = implementation
        super.init(rt)
    }
    
    public override class var staticType: Types {
        .function
    }
    
    public override var description: String {
        "function"
    }
    
}

public protocol RT_Implementation {
    
    func run(arguments: RT_Arguments) throws -> RT_Object
    
}

public struct RT_Arguments {
    
    public var command: Reflection.Command
    public var contents: [Reflection.Parameter : RT_Object]
    
    public init(_ command: Reflection.Command, _ contents: [Reflection.Parameter : RT_Object]) {
        self.command = command
        self.contents = contents
    }
    
    public func `for`<Argument: RT_Object>(_ predefined: Parameters, _: Argument.Type? = nil) throws -> Argument {
        try `for`(command.parameters[predefined])
    }
    public func `for`<Argument: RT_Object>(_ parameter: Reflection.Parameter, _: Argument.Type? = nil) throws -> Argument {
        guard let someArgument = contents[parameter] else {
            throw MissingParameter(command: command, parameter: parameter)
        }
        guard let argument = someArgument.coerce(to: Argument.self) else {
            throw WrongParameterType(command: command, parameter: parameter, expected: someArgument.rt.reflection.types[Argument.staticType], actual: someArgument.type)
        }
        return argument
    }
    
    public subscript<Argument: RT_Object>(_ predefined: Parameters, _: Argument.Type? = nil) -> Argument? {
        self[Reflection.Parameter(predefined)]
    }
    public subscript<Argument: RT_Object>(_ parameter: Reflection.Parameter, _: Argument.Type? = nil) -> Argument? {
        contents[parameter]?.coerce(to: Argument.self)
    }
    
}

public struct RT_SwiftImplementation: RT_Implementation {
    
    public typealias Function = (_ arguments: RT_Arguments) throws -> RT_Object
    
    var function: Function
    
    public init(function: @escaping Function) {
        self.function = function
    }
    
    public func run(arguments: RT_Arguments) throws -> RT_Object {
        try function(arguments)
    }
    
}

public struct RT_ExpressionImplementation: RT_Implementation {
    
    var rt: Runtime
    var formalParameters: [Term]
    var formalArguments: [Term]
    var body: Expression
    
    public init(_ rt: Runtime, formalParameters: [Term], formalArguments: [Term], body: Expression) {
        self.rt = rt
        self.formalParameters = formalParameters
        self.formalArguments = formalArguments
        self.body = body
    }
    
    public func run(arguments: RT_Arguments) throws -> RT_Object {
        rt.context.frameStack.repush()
        defer {
            rt.context.frameStack.pop()
        }
        
        // Create variables for each of the function's parameters.
        for (parameter, argumentVariable) in zip(formalParameters, formalArguments) {
            let argument = arguments[Reflection.Parameter(parameter.uri)]
            rt.context[variable: argumentVariable] = argument ?? rt.unspecified
        }
        
        do {
            rt.lastResult = rt.null
            return try rt.runPrimary(body)
        } catch let earlyReturn as Runtime.EarlyReturn {
            return earlyReturn.value
        }
    }
    
}

public struct RT_BlockImplementation: RT_Implementation {
    
    var rt: Runtime
    var formalArguments: [Term]
    var body: Expression
    
    public init(_ rt: Runtime, formalArguments: [Term], body: Expression) {
        self.rt = rt
        self.formalArguments = formalArguments
        self.body = body
    }
    
    public func run(arguments: RT_Arguments) throws -> RT_Object {
        rt.context.frameStack.repush()
        defer {
            rt.context.frameStack.pop()
        }
        
        // Push exactly what we're given as direct argument.
        rt.context.targetStack.push(arguments[.direct, RT_Object.self] ?? rt.unspecified)
        defer {
            rt.context.targetStack.pop()
        }
        
        // Convert direct argument to list to do variable binding.
        let directArgumentList =
            arguments[.direct, RT_List.self] ??
            RT_List(rt, contents: arguments[.direct].map { [$0] } ?? [])
        
        // Bind the items to variables.
        let directArguments = directArgumentList.contents
        for (index, formalArgument) in formalArguments.enumerated() {
            rt.context[variable: formalArgument] =
                (index < directArguments.count) ?
                directArguments[index] :
                rt.null
        }
        
        do {
            rt.lastResult = rt.null
            return try rt.runPrimary(body)
        } catch let earlyReturn as Runtime.EarlyReturn {
            return earlyReturn.value
        }
    }
    
}
