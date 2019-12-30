import Bushel
import SwiftAutomation

private let calendar = Calendar(identifier: .gregorian)

/// A date, stored as a Foundation `Date`.
public class RT_Date: RT_Object {
    
    public var value: Date = Date()
    
    public init(value: Date) {
        self.value = value
    }
    
    public override var description: String {
        String(describing: value)
    }
    
    private static let typeInfo_ = TypeInfo(.date)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public var seconds: RT_Integer {
        RT_Integer(value: calendar.component(.second, from: value))
    }
    public var minutes: RT_Integer {
        RT_Integer(value: calendar.component(.minute, from: value))
    }
    public var hours: RT_Integer {
        RT_Integer(value: calendar.component(.hour, from: value))
    }
    
    public override var properties: [RT_Object] {
        super.properties + [seconds, minutes, hours]
    }
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(property.uid) {
        case .date_seconds:
            return seconds
        case .date_minutes:
            return minutes
        case .date_hours:
            return hours
        default:
            return try super.property(property)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_Date)
            .map { value <=> $0.value }
    }
    
}

extension RT_Date {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
