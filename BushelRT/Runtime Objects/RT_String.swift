import Bushel
import SwiftAutomation

/// A string stored as a Swift `String`.
public class RT_String: RT_Object, AEEncodable {
    
    public var value: String = ""
    
    public init(_ rt: Runtime, value: String) {
        self.value = value
        super.init(rt)
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
            return RT_String(rt, value: self.value + other.value)
        } else {
            return nil
        }
    }
    
    public var length: RT_Integer {
        RT_Integer(rt, value: value.count)
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [
            PropertyInfo(Properties.Sequence_length): \RT_String.length
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func element(_ type: TypeInfo, at index: Int64) throws -> RT_Object? {
        let zeroBasedIndex = index - 1
        if RT_Character.typeInfo.isA(type) {
            return RT_Character(rt, value: value[value.index(value.startIndex, offsetBy: Int(zeroBasedIndex))])
        } else {
            return try super.element(type, at: index)
        }
    }
    
    public override func element(_ type: TypeInfo, at positioning: AbsolutePositioning) throws -> RT_Object? {
        switch positioning {
        case .first:
            return try element(type, at: 1)
        case .middle:
            return try element(type, at: Int64(value.count / 2) + 1)
        case .last:
            return try element(type, at: Int64(value.count))
        case .random:
            return try element(type, at: Int64(arc4random_uniform(UInt32(value.count))) + 1)
        }
    }
    
    public override func elements(_ type: TypeInfo) throws -> RT_Object {
        if RT_Character.typeInfo.isA(type) {
            return self
        } else {
            return try super.elements(type)
        }
    }
    
    public override func elements(_ type: TypeInfo, from: RT_Object, thru: RT_Object) throws -> RT_Object {
        if RT_Character.typeInfo.isA(type) {
            let from = try Int(from.coerceOrThrow(to: RT_Integer.self).value)
            let thru = try Int(thru.coerceOrThrow(to: RT_Integer.self).value)
            guard from >= 1, thru <= value.count else {
                throw RangeOutOfBounds(rangeStart: from, rangeEnd: thru, container: self)
            }
            if from > thru {
                return RT_String(rt, value: "")
            }
            let substring = value[
                value.index(value.startIndex, offsetBy: from - 1)...value.index(value.startIndex, offsetBy: thru - 1)
            ]
            return RT_String(rt, value: String(substring))
        } else {
            return try super.elements(type, from: from, thru: thru)
        }
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.id) {
        case .character:
            guard value.count == 1 else {
                return nil
            }
            return RT_Character(rt, value: value.first!)
        case .integer:
            return Int64(value).map { RT_Integer(rt, value: $0) }
        case .real:
            return Double(value).map { RT_Real(rt, value: $0) }
        case .date:
            return DateFormatter().date(from: value).map { RT_Date(rt, value: $0) }
        case .file:
            return RT_File(rt, value: URL(fileURLWithPath: value))
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
            .map { RT_Boolean.withValue(rt, value.hasPrefix($0.value)) }
    }
    
    public override func endsWith(_ other: RT_Object) -> RT_Object? {
        other.coerce(to: RT_String.self)
            .map { RT_Boolean.withValue(rt, value.hasSuffix($0.value)) }
    }
    
    public override func contains(_ other: RT_Object) -> RT_Object? {
        other.coerce(to: RT_String.self)
            .map { RT_Boolean.withValue(rt, value.contains($0.value)) }
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
