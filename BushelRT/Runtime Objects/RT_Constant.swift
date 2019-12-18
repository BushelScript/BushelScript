import Bushel
import SwiftAutomation

/// A constant with an underlying four-byte code value.
public class RT_Constant: RT_Object, AEEncodable {
    
    public var value: OSType
    
    public init(value: OSType) {
        self.value = value
    }
    
    public override var description: String {
        "'\(String(fourCharCode: value))'"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.constant.rawValue, typeEnumerated, [.supertype(RT_Object.typeInfo), .name(TermName("constant"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        value == (other as? RT_Constant)?.value
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return NSAppleEventDescriptor(typeCode: value)
    }
    
}

extension RT_Constant {
    
    public override var debugDescription: String {
        super.description + "[value: \(value) '\(String(fourCharCode: value))']"
    }
    
}
