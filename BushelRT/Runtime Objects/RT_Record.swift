import Bushel
import SwiftAutomation

/// An Apple Event record. Aka: associative array, dictionary, map.
public class RT_Record: RT_Object, AEEncodable {
    
    public var contents: [Bushel.Term : RT_Object] = [:]
    
    public init(contents: [Bushel.Term : RT_Object]) {
        self.contents = contents
    }
    
    public override var description: String {
        "{\(contents.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
    }
    
    private static let typeInfo_ = TypeInfo(.record)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var truthy: Bool {
        !contents.isEmpty
    }
    
    public func add(key: Bushel.Term, value: RT_Object) {
        contents[key] = value
    }
    
    public var length: RT_Integer {
        RT_Integer(value: Int64(contents.count))
    }
    
    public override var properties: [RT_Object] {
        return super.properties + [length]
    }
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        if let key = contents.keys.first(where: { $0.uid == property.uid }) {
            return contents[key]!
        }
        switch PropertyUID(property.uid) {
        case .Sequence_length:
            return length
        default:
            return try super.property(property)
        }
    }
    
    // TODO: Repair or delete
//    public override func compare(with other: RT_Object) -> ComparisonResult? {
//        guard let other = other as? RT_Record else {
//            return nil
//        }
//        let keysCompared = contents.keys <=> other.contents.keys
//        if keysCompared == .orderedSame {
//            return contents.values <=> other.contents.values
//        } else {
//            return keysCompared
//        }
//    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return try contents.reduce(into: NSAppleEventDescriptor.record()) { (descriptor, entry) in
            let (key, value) = entry
            if
                let aeCode = key.ae4Code,
                let value = value as? AEEncodable
            {
                descriptor.setDescriptor(try value.encodeAEDescriptor(appData), forKeyword: aeCode)
            }
        }
    }
    
}

extension RT_Record {
    
    public override var debugDescription: String {
        super.debugDescription + "[contents: \(contents)]"
    }
    
}

