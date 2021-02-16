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
    public var secondsSinceMidnight: RT_Integer {
        RT_Integer(value: calendar.dateComponents([.second], from: calendar.startOfDay(for: value), to: value).second!)
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
