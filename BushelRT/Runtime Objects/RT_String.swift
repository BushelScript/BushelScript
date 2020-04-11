import Bushel
import SwiftAutomation

/// A string stored as a Swift `String`.
public class RT_String: RT_Object, AEEncodable {
    
    public var value: String = ""
    
    public init(value: String) {
        self.value = value
    }
    
    public override var description: String {
        "\"\(value)\""
    }
    
    private static let typeInfo_ = TypeInfo(.string)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    public override var truthy: Bool {
        !value.isEmpty
    }
    
    public override func concatenating(_ other: RT_Object) -> RT_Object? {
        if let other = other.coerce(to: RT_String.self) {
            return RT_String(value: self.value + other.value)
        } else {
            return nil
        }
    }
    
    public var length: RT_Integer {
        RT_Integer(value: Int64(value.count))
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [
            PropertyInfo(PropertyUID.Sequence_length): \RT_String.length
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object {
        let zeroBasedIndex = index - 1
        if type.isA(RT_Character.typeInfo) {
            return RT_Character(value: value[value.index(value.startIndex, offsetBy: Int(zeroBasedIndex))])
        } else {
            return try super.element(type, at: index)
        }
    }
    
    public override func element(_ type: TypeInfo, at positioning: AbsolutePositioning) throws -> RT_Object {
        switch positioning {
        case .first:
            return try element(type, at: 0)
        case .middle:
            return try element(type, at: Int64(value.count / 2))
        case .last:
            return try element(type, at: Int64(value.count - 1))
        case .random:
            return try element(type, at: Int64(arc4random_uniform(UInt32(value.count))))
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
        switch TypeUID(type.typedUID) {
        case .character:
            guard value.count == 1 else {
                return nil
            }
            return RT_Character(value: value.first!)
        case .integer:
            return Int64(value).map { RT_Integer(value: $0) }
        case .real:
            return Double(value).map { RT_Real(value: $0) }
        case .date:
            return DateFormatter().date(from: value).map { RT_Date(value: $0) }
        default:
            return super.coerce(to: type)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_String)
            .map { value <=> $0.value }
    }
    
    public override func startsWith(_ other: RT_Object) -> RT_Object? {
        other.coerce(to: RT_String.self)
            .map { RT_Boolean.withValue(value.hasPrefix($0.value)) }
    }
    
    public override func endsWith(_ other: RT_Object) -> RT_Object? {
        other.coerce(to: RT_String.self)
            .map { RT_Boolean.withValue(value.hasSuffix($0.value)) }
    }
    
    public override func contains(_ other: RT_Object) -> RT_Object? {
        other.coerce(to: RT_String.self)
            .map { RT_Boolean.withValue(value.contains($0.value)) }
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        switch CommandUID(command.typedUID) {
        case .String_split:
            guard let separator = arguments[ParameterInfo(.String_split_by)]?.coerce(to: RT_String.self) else {
                // TODO: Throw error
                return nil
            }
            return RT_List(contents: value.components(separatedBy: separator.value).map { RT_String(value: $0) })
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(string: value)
    }
    
}

extension RT_String {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
