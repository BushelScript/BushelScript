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
    
    var byCommand: [CommandInfo : [RT_Function.ParameterSignature : RT_Function]] = [:]
    
    public mutating func add(_ function: RT_Function) {
        if byCommand[function.signature.command] == nil {
            byCommand[function.signature.command] = [:]
        }
        byCommand[function.signature.command]![function.signature.parameters] = function
    }
    
    public func functions(for command: CommandInfo) -> [RT_Function.ParameterSignature : RT_Function] {
        byCommand[command] ?? [:]
    }
    
    public func function(for signature: RT_Function.Signature) -> RT_Function? {
        byCommand[signature.command]?[signature.parameters]
    }
    
    public func bestMatch(for command: CommandInfo, arguments: [ParameterInfo : RT_Object]) -> RT_Function? {
        let functions = self.functions(for: command)
        guard !functions.isEmpty else {
            return nil
        }
        
        // For now, only deal with exact match.
        let exactMatchSignature = RT_Function.ParameterSignature(arguments.map { ($0.key, $0.value.dynamicTypeInfo) }, uniquingKeysWith: { l, r in l })
        return functions[exactMatchSignature]
    }
    
}

// MARK: Add convenience
extension FunctionSet {
    
    public mutating func add(_ command: Commands, parameters: [Parameters : Types], implementation: @escaping RT_SwiftImplementation.Function) {
        add(RT_Function(
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
