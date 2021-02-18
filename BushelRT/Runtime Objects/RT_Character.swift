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
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.uri) {
        case .string:
            return RT_String(value: String(value))
        case .integer:
            return value.unicodeScalars.count == 1 ? RT_Integer(value: Int64(value.unicodeScalars.first!.value)) : nil
        default:
            return super.coerce(to: type)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        String(value).withCString(encodedAs: UTF32.self) { cString in
            NSAppleEventDescriptor(descriptorType: cChar, bytes: cString, length: 1)! as NSAppleEventDescriptor
        }
    }
    
}

extension RT_Character {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
