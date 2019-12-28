import Bushel

public class RT_Global: RT_Object {
    
    public let rt: RTInfo
    
    public init(_ rt: RTInfo) {
        self.rt = rt
    }
    
    private static let typeInfo_ = TypeInfo(.global)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "BushelScript"
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(rawValue: property.uid) {
        case .topScript:
            return rt.topScript
        case .currentDate:
            return RT_Date(value: Date())
        case .math_pi:
            return RT_Real(value: Double.pi)
        case .math_e:
            return RT_Real(value: exp(1))
        default:
            return try super.property(property)
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object]) -> RT_Object? {
        let commandClass = command.doubleCode?.class
        if commandClass == (try! FourCharCode(fourByteString: "syso")) || commandClass == (try! FourCharCode(fourByteString: "gtqp")) {
            // Run command from StandardAdditions.osax
            return RT_Application(rt, currentApplication: ()).perform(command: command, arguments: arguments)
        }
        
        switch CommandUID(rawValue: command.uid) {
        case .delay:
            let delaySeconds = (arguments[ParameterInfo(.direct)]?.coerce(to: rt.type(forUID: TypeUID.real.rawValue)!) as? RT_Numeric)?.numericValue ?? 1.0
            Thread.sleep(forTimeInterval: delaySeconds)
            return RT_Null.null
        case .cli_log:
            guard let message = arguments[ParameterInfo(.direct)] else {
                // TODO: Throw error
                return RT_Null.null
            }
            print((message.coerce() as? RT_String)?.value ?? String(describing: message))
            return RT_Null.null
        default:
            return super.perform(command: command, arguments: arguments)
        }
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        other.dynamicTypeInfo.isA(dynamicTypeInfo)
    }
    
}

extension RT_Global {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
