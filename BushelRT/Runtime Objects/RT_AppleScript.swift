import Bushel
import SwiftAutomation
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
    
    private static let typeInfo_ = TypeInfo(.applescript)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        var arguments = arguments
        if arguments[.direct] == nil {
            arguments.contents[ParameterInfo(.direct)] = arguments[.target]
        }
        
        // AppleScript handlers almost certainly do not care about the
        // AE "subject" attribute, so we can safely leave that off.
        arguments.contents.removeValue(forKey: ParameterInfo(.target))
        
        let encodedArguments = try aeEncode(arguments, appData: AppData())
        
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
            throw UnsupportedCommand(object: self, command: arguments.command)
        }
        
        let event = NSAppleEventDescriptor.appleEvent(
            withEventClass: eventClass,
            eventID: eventID,
            targetDescriptor: .null(),
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        if let subroutineName = subroutineName {
            event.setParam(NSAppleEventDescriptor(string: subroutineName), forKeyword: 0x736E616D /* keyASSubroutineName 'snam' */)
        }
        
        for (ae4Code, argumentDescriptor) in encodedArguments {
            event.setParam(argumentDescriptor, forKeyword: ae4Code)
        }
        
        var errorInfo: NSDictionary?
        let resultDescriptor = value.executeAppleEvent(event, error: &errorInfo)
        
        if let errorInfo = errorInfo {
            throw AppleScriptError(number: errorInfo[NSAppleScript.errorNumber as NSString] as? OSStatus, message: errorInfo[NSAppleScript.errorMessage as NSString] as? String)
        }
        
        return try RT_Object.fromAEDescriptor(rt, AppData(), resultDescriptor)
    }
    
}

extension RT_AppleScript {
    
    public override var debugDescription: String {
        super.debugDescription + "[name: \(name)]"
    }
    
}
