import Bushel
import SwiftAutomation

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
    
    public func property(_ property: PropertyInfo) -> RT_Object? {
        switch PropertyUID(property.uid) {
        case .topScript:
            return rt.topScript
        case .currentDate:
            return RT_Date(value: Date())
        case .Math_pi:
            return RT_Real(value: Double.pi)
        case .Math_e:
            return RT_Real(value: exp(1))
        default:
            return nil
        }
    }
    
    public override func property(_ property: PropertyInfo) throws -> RT_Object {
        guard let value = self.property(property) else {
            throw NoPropertyExists(type: dynamicTypeInfo, property: property)
        }
        return value
    }
    
    public func element(_ type: TypeInfo, named name: String, originalObject: RT_Object) throws -> RT_Object {
        switch TypeUID(type.uid) {
        case .application:
            guard
                let appBundleID = TargetApplication.name(name).bundleIdentifier,
                let appBundle = Bundle(applicationBundleIdentifier: appBundleID)
            else {
                return RT_Null.null
            }
            return RT_Application(rt, bundle: appBundle)
        case .file:
            return RT_File(value: URL(fileURLWithPath: (name as NSString).expandingTildeInPath))
        default:
            throw UnsupportedIndexForm(indexForm: .name, class: originalObject.dynamicTypeInfo)
        }
    }
    
    public override func element(_ type: TypeInfo, named name: String) throws -> RT_Object {
        try element(type, named: name, originalObject: self)
    }
    
    public func element(_ type: TypeInfo, id: RT_Object, originalObject: RT_Object) throws -> RT_Object {
        switch TypeUID(type.uid) {
        case .application:
            guard
                let appBundleID = (id.coerce() as RT_String?)?.value,
                let appBundle = Bundle(applicationBundleIdentifier: appBundleID)
            else {
                return RT_Null.null
            }
            return RT_Application(rt, bundle: appBundle)
        default:
            throw UnsupportedIndexForm(indexForm: .id, class: originalObject.dynamicTypeInfo)
        }
    }
    
    public override func element(_ type: TypeInfo, id: RT_Object) throws -> RT_Object {
        try element(type, id: id, originalObject: self)
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        if let commandClass = command.typedUID.ae8Code?.class {
            let standardAdditionsCommandClasses =
                ["syso", "gtqp", "misc"].map({ try! FourCharCode(fourByteString: $0) })
            if standardAdditionsCommandClasses.contains(commandClass) {
                // Run command from StandardAdditions.osax
                return try RT_Application(rt, currentApplication: ()).perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            } else if commandClass == (try! FourCharCode(fourByteString: "bShG")) {
                // Run GUIHost command
                guard let guiHostBundle = Bundle(applicationBundleIdentifier: "com.justcheesy.BushelGUIHost") else {
                    throw MissingResource(resourceDescription: "BushelGUIHost application")
                }
                var arguments = arguments
                if
                    arguments[ParameterInfo(.GUI_ask_title)] == nil,
                    let scriptName = rt.topScript.name
                {
                    arguments[ParameterInfo(.GUI_ask_title)] = RT_String(value: scriptName)
                }
                return try RT_Application(rt, bundle: guiHostBundle).perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
            }
        }
        
        switch CommandUID(command.typedUID) {
        case .delay:
            let delaySeconds = (arguments[ParameterInfo(.direct)]?.coerce(to: rt.type(forUID: TypedTermUID(TypeUID.real))) as? RT_Numeric)?.numericValue ?? 1.0
            Thread.sleep(forTimeInterval: delaySeconds)
            return RT_Null.null
        case .CLI_log:
            guard let message = arguments[ParameterInfo(.direct)] else {
                // TODO: Throw error
                return RT_Null.null
            }
            print((message.coerce() as? RT_String)?.value ?? String(describing: message))
            return RT_Null.null
        default:
            return try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
    }
    
    public override func compareEqual(with other: RT_Object) -> Bool {
        other.dynamicTypeInfo.isA(dynamicTypeInfo)
    }
    
    public override var hash: Int {
        dynamicTypeInfo.hashValue
    }
    
}

extension RT_Global {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
