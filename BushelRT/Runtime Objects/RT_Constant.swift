import Bushel
import SwiftAutomation

/// A symbolic constant.
public class RT_Constant: RT_Object, AEEncodable {
    
    public var value: ConstantInfo
    
    public init(_ rt: Runtime, value: ConstantInfo) {
        self.value = value
        super.init(rt)
    }
    
    private static let typeInfo_ = TypeInfo(.constant)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        return "\(value.name as Any? ?? "«constant \(value.uri)»")"
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Constant)?.value
    }
    
    public override var hash: Int {
        value.hashValue
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let aeCode = value.uri.ae4Code else {
            throw Unencodable(object: self)
        }
        return NSAppleEventDescriptor(enumCode: aeCode)
    }
    
}

extension RT_Constant {
    
    public override var debugDescription: String {
        super.description + "[value: \(value)]"
    }
    
}
