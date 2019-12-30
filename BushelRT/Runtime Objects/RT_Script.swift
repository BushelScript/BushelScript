import Bushel

public class RT_Script: RT_Object {
    
    private static let typeInfo_ = TypeInfo(.script)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "script"
    }
    
    public var dynamicProperties: [PropertyInfo : RT_Object] = [:]
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        try dynamicProperties[property] ?? super.property(property)
    }
    
}

extension RT_Script {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
