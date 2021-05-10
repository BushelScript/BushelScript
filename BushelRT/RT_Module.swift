import Bushel

// MARK: Definition

/// A runtime object that acts as a bag of functions.
public protocol RT_Module: RT_Object {
    
    var functions: FunctionSet { get set }
    
}

extension RT_Module {
    
    public func runFunction(for command: CommandInfo, arguments: [ParameterInfo : RT_Object]) throws -> RT_Object? {
        // Find best-matching function and call it.
        try functions
            .bestMatch(for: command, arguments: arguments)?
            .call(arguments: arguments)
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
    
    public func bestMatch(for command: CommandInfo, arguments: [ParameterInfo : RT_Object]) -> RT_Function? {
        let functions = self.functions(for: command)
        guard !functions.isEmpty else {
            return nil
        }
        
        return functions.reduce((typeScore: -1, countScore: Int.min, function: nil as RT_Function?)) { bestSoFar, function in
            let parameters = function.signature.parameters
            
            // Ensure each argument maps to a parameter of suitable type.
            var typeScore = 0
            for (parameter, argument) in arguments {
                guard
                    let parameterType = parameters[parameter],
                    argument.dynamicTypeInfo.isA(parameterType)
                else {
                    return bestSoFar
                }
                
                // +1 point for each exact type match.
                if argument.dynamicTypeInfo == parameterType {
                    typeScore += 1
                }
            }
            
            // -1 point for each additional parameter.
            let countScore = arguments.count - parameters.count
            
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
