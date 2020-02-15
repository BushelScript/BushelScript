import Bushel

typealias Callable = @convention(c) (Builtin.RTObjectPointer) -> Builtin.RTObjectPointer

class RT_Function: RT_Object {
    
    var callable: Callable
    
    init(callable: @escaping Callable) {
        self.callable = callable
    }
    
    func call(arguments: [ParameterInfo : RT_Object]) -> RT_Object {
        let argumentRecord = RT_Private_ArgumentRecord()
        argumentRecord.contents = [TypedTermUID : RT_Object](uniqueKeysWithValues:
            arguments.map { (key: $0.key.typedUID, value: $0.value) }
        )
        return Builtin.fromOpaque(callable(Builtin.toOpaque(argumentRecord)))
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
        "script"
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
