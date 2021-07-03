import Bushel
import AEthereal

/// An Apple Event record. Aka: associative array, dictionary, map.
public class RT_Record: RT_Object, Encodable {
    
    public var contents: [RT_Object : RT_Object] = [:]
    
    public init(_ rt: Runtime, contents: [RT_Object : RT_Object]) {
        self.contents = contents
        super.init(rt)
    }
    
    public override var description: String {
        contents.isEmpty ? "{:}" : "{\(contents.map { "\($0.key): \($0.value)" }.joined(separator: ", "))}"
    }
    
    public override class var staticType: Types {
        .record
    }
    
    public override var truthy: Bool {
        !contents.isEmpty
    }
    
    public func add(key: RT_Object, value: RT_Object) {
        contents[key] = value
    }
    
    public var length: RT_Integer {
        RT_Integer(rt, value: contents.count)
    }
    
    public override class var propertyKeyPaths: [Properties : AnyKeyPath] {
        [.Sequence_length: \RT_Record.length]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func property(_ property: Reflection.Property) throws -> RT_Object? {
        let propertyConstantKey = Reflection.Constant(property: property)
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
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(
            try contents.reduce(into: AEDescriptor.record()) { (descriptor, entry) in
                let (key, value) = entry
                guard
                    let aeCode: OSType = ({
                        if let key = key as? RT_Specifier {
                            switch key.kind {
                            case let .property(property):
                                return property.uri.ae4Code
                            case .element:
                                return nil
                            }
                        } else if let key = key as? RT_Type {
                            return key.value.uri.ae4Code
                        } else {
                            return nil
                        }
                    })(),
                    let encodable = value as? Encodable
                else {
                    throw Unencodable(object: self)
                }
                descriptor[aeCode] = try AEEncoder.encode(encodable)
            }
        )
    }
    
}
