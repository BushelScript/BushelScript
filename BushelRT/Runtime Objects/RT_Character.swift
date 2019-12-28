import Bushel
import SwiftAutomation

/// A Unicode "character", stored as a Swift `Character`.
public class RT_Character: RT_Object, AEEncodable {
    
    public var value: Character
    
    public init(value: Character) {
        self.value = value
    }
    
    public override var description: String {
        "(\"\(value)\" as character)"
    }
    
    private static let typeInfo_ = TypeInfo(.character)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_Character)
            .map { value <=> $0.value }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return withUnsafeBytes(of: value, { valuePointer in
            return NSAppleEventDescriptor(descriptorType: cChar, bytes: valuePointer.baseAddress!, length: valuePointer.count)!
        })
    }
    
}

extension RT_Character {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
