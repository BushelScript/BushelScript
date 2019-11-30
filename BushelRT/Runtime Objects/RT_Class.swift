import Bushel

/// A runtime class reflected as a dynamic object.
public class RT_Class: RT_Object {
    
    public var value: TypeInfo
    
    public init(value: TypeInfo) {
        self.value = value
    }
    
    private static let typeInfo_ = TypeInfo(.class, [.supertype(RT_Object.typeInfo), .name(TermName("class"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        return String(describing: value.name)
    }
    
    public override var debugDescription: String {
        return super.description + "[value: \(value)]"
    }
    
}
