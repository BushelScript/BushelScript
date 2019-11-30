import Bushel

public class RT_Global: RT_Object {
    
    public let rt: RTInfo
    
    public init(_ rt: RTInfo) {
        self.rt = rt
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.global.rawValue, [.supertype(RT_Object.typeInfo), .name(TermName("BushelScript global"))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        switch PropertyUID(rawValue: property.uid) {
        case .math_pi:
            return RT_Real(value: Double.pi)
        case .math_e:
            return RT_Real(value: exp(1))
        default:
            return try super.property(property)
        }
    }
    
    public override func perform(command: CommandInfo, arguments: [ConstantTerm : RT_Object]) -> RT_Object? {
        if command.doubleCode?.class == (try! FourCharCode(fourByteString: "syso")) {
            // Run command from StandardAdditions.osax
            return RT_Application(rt, currentApplication: ()).perform(command: command, arguments: arguments)
        }
        
        switch CommandUID(rawValue: command.uid) {
        case .cli_log:
            guard let message = arguments[ParameterTerm(ParameterUID.direct.rawValue, name: TermName(""), code: keyDirectObject)] else {
                // TODO: Throw error
                return RT_Null.null
            }
            print((message.coerce(to: rt.type(forUID: TypeUID.string.rawValue)!) as? RT_String)?.value ?? String(describing: message))
            return RT_Null.null
        default:
            return super.perform(command: command, arguments: arguments)
        }
    }
    
}

extension RT_Global {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
