import Bushel
import AEthereal
import Carbon.OpenScripting

public class RT_AppleScript: RT_Object, RT_Module {
    
    public let name: String
    private let value: NSAppleScript
    
    public init(_ rt: Runtime, name: String, value: NSAppleScript) {
        self.name = name
        self.value = value
        super.init(rt)
    }
    
    public override var description: String {
        "AppleScript \"\(name)\""
    }
    
    public override class var staticType: Types {
        .applescript
    }
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        var arguments = arguments
        if arguments[.direct] == nil {
            arguments.contents[Reflection.Parameter(.direct)] = arguments[.target]
        }
        
        // AppleScript handlers almost certainly do not care about the
        // AE "subject" attribute, so we can safely leave that off.
        arguments.contents.removeValue(forKey: Reflection.Parameter(.target))
        
        let eventClass: AEEventClass
        let eventID: AEEventID
        var subroutineName: String?
        if let asidName = arguments.command.uri.asidName {
            eventClass = 0x61736372 /* kASAppleScriptSuite 'ascr' */
            eventID = 0x70736272 /* kASSubroutineEvent 'psbr' */
            subroutineName = asidName
        } else if let (class: classAE4Code, id: idAE4Code) = arguments.command.uri.ae8Code {
            eventClass = classAE4Code
            eventID = idAE4Code
        } else {
            return nil
        }
        
        let event = AEDescriptor(
            eventClass: eventClass,
            eventID: eventID,
            target: .appRoot
        )
        if let subroutineName = subroutineName {
            event.setParam(AEDescriptor(string: subroutineName), forKeyword: 0x736E616D /* keyASSubroutineName 'snam' */)
        }
        
        for (parameter, argument) in arguments.contents {
            guard let parameterAE4Code = parameter.uri.ae4Code else {
                throw Unencodable(object: parameter)
            }
            guard let encodableArgument = argument as? Encodable else {
                throw Unencodable(object: argument)
            }
            event[parameterAE4Code] = try AEEncoder.encode(encodableArgument)
        }
        
        var errorInfo: NSDictionary?
        let resultDescriptor = AEDescriptor(value.executeAppleEvent(event, error: &errorInfo))
        
        if let errorInfo = errorInfo {
            throw AppleScriptError(number: errorInfo[NSAppleScript.errorNumber as NSString] as? OSStatus, message: errorInfo[NSAppleScript.errorMessage as NSString] as? String)
        }
        
        return try RT_Object.decode(rt, app: App(), aeDescriptor: resultDescriptor)
    }
    
}

extension RT_AppleScript {
    
    public override var debugDescription: String {
        super.debugDescription + "[name: \(name)]"
    }
    
}
