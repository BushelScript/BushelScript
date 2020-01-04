import Bushel

/// A runtime class reflected as a dynamic object.
public class RT_Class: RT_Object {
    
    public var value: TypeInfo
    
    public init(value: TypeInfo) {
        self.value = value
    }
    
    private static let typeInfo_ = TypeInfo(.class)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        return "\(value.name as Any? ?? "«type \(value.uid)»")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Class)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
}

extension RT_Class {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}
