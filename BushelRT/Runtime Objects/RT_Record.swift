import Bushel
import SwiftAutomation

/// An Apple Event record. Aka: associative array, dictionary, map.
public class RT_Record: RT_Object, AEEncodable {
    
    public var contents: [RT_Object : RT_Object] = [:]
    
    public init(contents: [RT_Object : RT_Object]) {
        self.contents = contents
    }
    
    public override var description: String {
        contents.isEmpty ? "{:}" : "{\(contents.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
    }
    
    private static let typeInfo_ = TypeInfo(.record)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var truthy: Bool {
        !contents.isEmpty
    }
    
    public func add(key: RT_Object, value: RT_Object) {
        contents[key] = value
    }
    
    public var length: RT_Integer {
        RT_Integer(value: Int64(contents.count))
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [PropertyInfo(Properties.Sequence_length): \RT_Record.length]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        let propertyConstantKey = ConstantInfo(property: property)
        func keyMatchesProperty(key: RT_Object) -> Bool {
            (key as? RT_Constant)?.value == propertyConstantKey
        }
        
        if let key = contents.keys.first(where: keyMatchesProperty) {
            return contents[key]!
        } else {
            return try super.property(property)
        }
    }
    
    public override func compare(with other: RT_Object) -> ComparisonResult? {
        guard let other = other as? RT_Record else {
            return nil
        }
        let keysCompared = contents.keys <=> other.contents.keys
        if keysCompared == .orderedSame {
            return contents.values <=> other.contents.values
        } else {
            return keysCompared
        }
    }
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        return try contents.reduce(into: NSAppleEventDescriptor.record()) { (descriptor, entry) in
            let (key, value) = entry
            guard
                let aeCode: OSType = ({
                    if let key = key as? RT_Specifier {
                        if key.kind == .property {
                            return key.property?.uri.ae4Code
                        } else {
                            return key.type?.uri.ae4Code
                        }
                    } else if let key = key as? RT_Type {
                        return key.value.uri.ae4Code
                    } else {
                        return nil
                    }
                })(),
                let encodedValue = try (value as? AEEncodable)?.encodeAEDescriptor(appData)
            else {
                throw Unencodable(object: self)
            }
            descriptor.setDescriptor(encodedValue, forKeyword: aeCode)
        }
    }
    
}

extension RT_Record {
    
    public override var debugDescription: String {
        super.debugDescription + "[contents: \(contents)]"
    }
    
}

