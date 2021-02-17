import Bushel
import SwiftAutomation

/// A runtime type reflected as a dynamic object.
public class RT_Type: RT_Object, AEEncodable {
    
    public var value: TypeInfo
    
    public init(value: TypeInfo) {
        self.value = value
    }
    
    private static let typeInfo_ = TypeInfo(.type)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "\(value.name as Any? ?? "«type \(value.uid)»")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Type)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let aeCode = value.uid.ae4Code else {
            throw Unencodable(object: self)
        }
        return NSAppleEventDescriptor(typeCode: aeCode)
    }
    
}

extension RT_Type {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}
