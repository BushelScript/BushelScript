import Bushel
import AEthereal

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
    
    public override class var staticType: Types {
        .date
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
    
    public override class var propertyKeyPaths: [Properties : AnyKeyPath] {
        [
            .date_seconds: \RT_Date.seconds,
            .date_minutes: \RT_Date.minutes,
            .date_hours: \RT_Date.hours,
            .date_secondsSinceMidnight: \RT_Date.secondsSinceMidnight
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func coerce(to type: Reflection.`Type`) -> RT_Object? {
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
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        NSAppleEventDescriptor(date: value)
    }
    
}

extension RT_Date {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
