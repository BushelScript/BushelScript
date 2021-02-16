import Bushel
import SwiftAutomation

public class RT_Global: RT_Object {
    
    private static let typeInfo_ = TypeInfo(.global)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override var description: String {
        "builtin"
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        if
            let commandClass = command.typedUID.ae8Code?.class,
            commandClass == (try! FourCharCode(fourByteString: "bShG"))
        {
            // Run GUIHost command
            guard let guiHostBundle = Bundle(applicationBundleIdentifier: "com.justcheesy.BushelGUIHost") else {
                throw MissingResource(resourceDescription: "BushelGUIHost application")
            }
            
            var arguments = arguments
            if
                arguments.first(where: { $0.key.uid.ae4Code == Parameters.GUI_ask_title.ae12Code!.code }) == nil,
                let scriptName = Optional("")//rt.topScript.name
            // FIXME: fix
            {
                arguments[ParameterInfo(.GUI_ask_title)] = RT_String(value: scriptName)
            }
            
            return try RT_Application(bundle: guiHostBundle).perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
        }
        
        switch CommandURI(command.typedUID) {
        case .delay:
            let delaySeconds = arguments[ParameterInfo(.direct)]?.coerce(to: RT_Real.self)?.value ?? 1.0
            Thread.sleep(forTimeInterval: delaySeconds)
            return RT_Null.null
        case .CLI_log:
            guard let message = arguments[ParameterInfo(.direct)] else {
                // TODO: Throw error
                return RT_Null.null
            }
            print(message.coerce(to: RT_String.self)?.value ?? String(describing: message))
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
