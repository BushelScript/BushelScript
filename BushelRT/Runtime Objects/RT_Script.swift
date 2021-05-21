import Bushel

public class RT_Script: RT_Object, RT_LocalModule {
    
    public var name: String?
    
    public init(_ rt: Runtime, name: String? = nil) {
        self.name = name
        super.init(rt)
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
    
    public var functions = FunctionSet()
    
}
