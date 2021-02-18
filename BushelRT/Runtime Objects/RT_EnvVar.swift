import Bushel

/// An environment variable.
public class RT_EnvVar: RT_Object {
    
    public var name: String
    
    public init(name: String) {
        self.name = name
    }
    
    // Either RT_String or RT_Null.
    public var value: RT_Object {
        get {
            name.withCString {
                getenv($0).map { RT_String(value: String(cString: $0)) } ?? RT_Null.null
            }
        }
        set {
            name.withCString { name in
                if let newValue = newValue.coerce(to: RT_String.self) {
                    _ = newValue.value.withCString {
                        setenv(name, $0, 1)
                    }
                } else {
                    unsetenv(name)
                }
            }
        }
    }
    
    public override class var propertyKeyPaths: [PropertyInfo : AnyKeyPath] {
        [PropertyInfo(Properties.environmentVariable_value): \RT_EnvVar.value]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func setProperty(_ property: PropertyInfo, to newValue: RT_Object) throws {
        switch Properties(property.uri) {
        case .environmentVariable_value:
            self.value = newValue
        default:
            return try super.setProperty(property, to: newValue)
        }
    }
    
    public override var description: String {
        "env var \"\(name)\""
    }
    
}
