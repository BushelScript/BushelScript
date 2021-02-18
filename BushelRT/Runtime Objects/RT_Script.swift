import Bushel

public class RT_Function: RT_Object {
    
    var rt: Runtime
    var functionExpression: Expression
    
    init(_ rt: Runtime, _ functionExpression: Expression) {
        guard case .function = functionExpression.kind else {
            preconditionFailure()
        }
        self.rt = rt
        self.functionExpression = functionExpression
    }
    
    private static let typeInfo_ = TypeInfo(.function)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "function"
    }
    
    public func call(arguments: [ParameterInfo : RT_Object]) throws -> RT_Object {
        try rt.runFunction(functionExpression, actualArguments: arguments)
    }
    
}

public class RT_Script: RT_Object {
    
    public var name: String?
    
    public init(name: String? = nil) {
        self.name = name
    }
    
    private static let typeInfo_ = TypeInfo(.script)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "script\(name.map { " \"\($0)\"" } ?? "")"
    }
    
    public var dynamicProperties: [PropertyInfo : RT_Object] = [:]
    
    public override var properties: [PropertyInfo : RT_Object] {
        super.properties.merging(dynamicProperties, uniquingKeysWith: { old, new in new })
    }
    
    var dynamicFunctions: [CommandInfo : RT_Function] = [:]
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        try dynamicFunctions[command]?.call(arguments: arguments) ??
            super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
    }
    
}

extension RT_Script {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
