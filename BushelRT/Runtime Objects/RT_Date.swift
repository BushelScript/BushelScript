import Bushel
import SwiftAutomation

/// A date, stored as a Foundation `Date`.
public class RT_Date: RT_Object {
    
    public var value: Date = Date()
    
    public init(value: Date) {
        self.value = value
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.date.rawValue, TypeUID.date.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("date"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        let calendar = Calendar(identifier: .gregorian)
        switch PropertyUID(rawValue: property.uid) {
        case .date_seconds:
            return RT_Integer(value: calendar.component(.second, from: value))
        case .date_minutes:
            return RT_Integer(value: calendar.component(.minute, from: value))
        case .date_hours:
            return RT_Integer(value: calendar.component(.hour, from: value))
        default:
            return try super.property(property)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other as? RT_Date else {
            return nil
        }
        return value <=> other.value
    }
    
}

extension RT_Date {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
