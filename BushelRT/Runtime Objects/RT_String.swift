import Bushel
import SwiftAutomation

/// A string stored as a Swift `String`.
public class RT_String: RT_Object, AEEncodable {
    
    public var value: String = ""
    
    public init(value: String) {
        self.value = value
    }
    
    public override var description: String {
        return "\"\(value)\""
    }
    
    public override var debugDescription: String {
        return super.debugDescription + "[value: \(value)]"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.string.rawValue, TypeUID.string.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("string"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        return !value.isEmpty
    }
    
    public override func concatenating(_ other: RT_Object) -> RT_Object? {
        if let other = other as? RT_String {
            return RT_String(value: self.value + other.value)
        } else {
            return nil
        }
    }
    
    public var length: RT_Integer {
        return RT_Integer(value: Int64(value.count))
    }
    
    public override var properties: [RT_Object] {
        return super.properties + [length]
    }
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(rawValue: property.uid) {
        case .sequence_length:
            return length
        default:
            return try super.property(property)
        }
    }
    
    public override func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object {
        if type.isA(RT_Character.typeInfo) {
            return RT_Character(value: value[value.index(value.startIndex, offsetBy: Int(index))])
        } else {
            return try super.element(type, at: index)
        }
    }
    
    public override func elements(_ type: TypeInfo) throws -> RT_Object {
        if type.isA(RT_Character.typeInfo) {
            return RT_List(contents: value.map { RT_Character(value: $0) })
        } else {
            return try super.elements(type)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch type.code {
        case cChar:
            guard value.count == 1 else {
                return nil
            }
            return RT_Character(value: value.first!)
        default:
            return super.coerce(to: type)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other as? RT_String else {
            return nil
        }
        return value <=> other.value
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return NSAppleEventDescriptor(string: value)
    }
    
}
