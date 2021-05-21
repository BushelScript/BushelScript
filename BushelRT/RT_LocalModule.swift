import Bushel

/// A runtime object that acts as a bag of locally defined functions.
public protocol RT_LocalModule: RT_Module {
    
    var functions: FunctionSet { get set }
    
}

extension RT_LocalModule {
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        try handleByLocalFunction(arguments)
    }
    
    public func handleByLocalFunction(_ arguments: RT_Arguments) throws -> RT_Object? {
        guard let function = functions.bestMatch(for: arguments) else {
            return nil
        }
        
        var arguments = arguments
        if
            arguments[.direct] == nil,
            function.signature.parameters[ParameterInfo(.target)] == nil,
            function.signature.parameters[ParameterInfo(.direct)] != nil
        {
            arguments.contents[ParameterInfo(.direct)] = arguments[.target]
        }
        
        return try function.implementation.run(arguments: arguments)
    }
    
}

public struct FunctionSet {
    
    var byCommand: [CommandInfo : [RT_Function]] = [:]
    
    public mutating func add(_ function: RT_Function) {
        if byCommand[function.signature.command] == nil {
            byCommand[function.signature.command] = []
        }
        byCommand[function.signature.command]!.append(function)
    }
    
    public func functions(for command: CommandInfo) -> [RT_Function] {
        byCommand[command] ?? []
    }
    
    public func bestMatch(for arguments: RT_Arguments) -> RT_Function? {
        let functions = self.functions(for: arguments.command)
        guard !functions.isEmpty else {
            return nil
        }
        
        return functions.reduce((typeScore: -1, countScore: Int.min, function: nil as RT_Function?)) { bestSoFar, function in
            var parameters = function.signature.parameters
            
            if parameters[ParameterInfo(.target)] == nil {
                // Add target parameter that (weakly) matches every invocation.
                parameters[ParameterInfo(.target)] = TypeInfo(.item)
            }
            
            // Ensure each argument maps to a parameter of suitable type.
            var typeScore = 0
            for (parameter, argument) in arguments.contents {
                guard
                    let parameterType = parameters[parameter],
                    argument.dynamicTypeInfo.isA(parameterType) ||
                        argument.dynamicTypeInfo.uri == Term.SemanticURI(Types.null)
                else {
                    return bestSoFar
                }
                
                // +1 point for each exact type match.
                if argument.dynamicTypeInfo == parameterType {
                    typeScore += 1
                }
            }
            
            // -1 point for each additional parameter.
            let countScore = arguments.contents.count - parameters.count
            
            if
                typeScore >= bestSoFar.typeScore ||
                typeScore == bestSoFar.typeScore && countScore >= bestSoFar.countScore
            {
                return (typeScore: typeScore, countScore: countScore, function: function)
            } else {
                return bestSoFar
            }
        }.function
    }
    
}

// MARK: Add convenience
extension FunctionSet {
    
    public mutating func add(_ rt: Runtime, _ command: Commands, parameters: [Parameters : Types], implementation: @escaping RT_SwiftImplementation.Function) {
        add(RT_Function(
            rt,
            signature: RT_Function.Signature(
                command: CommandInfo(command),
                parameters: RT_Function.ParameterSignature(
                    uniqueKeysWithValues: parameters.map { (ParameterInfo($0.key), TypeInfo($0.value)) }
                )
            ),
            implementation: RT_SwiftImplementation(function: implementation)
        ))
    }
    
}
