import Bushel
import SwiftAutomation

/// A date, stored as a Foundation `Date`.
public class RT_Date: RT_Object {
    
    public var value: Date = Date()
    
    public init(value: Date) {
        self.value = value
    }
    
    public override var description: String {
        return super.description + "[value: \(value)]"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.date.rawValue, TypeUID.date.aeCode, [.supertype(RT_Object.typeInfo), .name(TermName("date"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
}

extension RT_Date {
    
    public override var debugDescription: String {
        super.debugDescription + "[value: \(value)]"
    }
    
}
