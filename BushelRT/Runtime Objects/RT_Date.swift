import Bushel
import SwiftAutomation

private let calendar = Calendar(identifier: .gregorian)

/// A date, stored as a Foundation `Date`.
public class RT_Date: RT_Object {
    
    public var value: Date = Date()
    
    public init(_ rt: Runtime, value: Date) {
        self.value = value
        super.init(rt)
    }
    
    public override var description: String {
        value.description(with: nil)
    }
    
    private static let typeInfo_ = TypeInfo(.date)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public var seconds: RT_Integer {
        RT_Integer(rt, value: calendar.component(.second, from: value))
    }
    public var minutes: RT_Integer {
        RT_Integer(rt, value: calendar.component(.minute, from: value))
    }
    public var hours: RT_Integer {
        RT_Integer(rt, value: calendar.component(.hour, from: value))
    }
    public var secondsSinceMidnight: RT_Integer {
        RT_Integer(rt, value: calendar.dateComponents([.second], from: calendar.startOfDay(for: value), to: value).second!)
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [
            PropertyInfo(Properties.date_seconds): \RT_Date.seconds,
            PropertyInfo(Properties.date_minutes): \RT_Date.minutes,
            PropertyInfo(Properties.date_hours): \RT_Date.hours,
            PropertyInfo(Properties.date_secondsSinceMidnight): \RT_Date.secondsSinceMidnight
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func coerce(to type: TypeInfo) -> RT_Object? {
        switch Types(type.id) {
        case .real:
            return RT_Real(rt, value: value.timeIntervalSince1970)
        case .integer:
            return RT_Integer(rt, value: Int64(value.timeIntervalSince1970))
        default:
            return super.coerce(to: type)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        (other as? RT_Date)
            .map { value <=> $0.value }
    }
    
}

// MARK: AEEncodable
extension RT_Date: AEEncodable {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(date: value)
    }
    
}

extension RT_Date {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
