import Bushel
import SwiftAutomation
import Carbon.OpenScripting

public class RT_AppleScript: RT_Object {
    
    public let name: String
    private let value: NSAppleScript
    
    public init(name: String, value: NSAppleScript) {
        self.name = name
        self.value = value
    }
    
    public override var description: String {
        "AppleScript \"\(name)\""
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.application)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        let encodedArguments = try encode(arguments: arguments, implicitDirect: implicitDirect, for: self, appData: AppData())
        
        let eventClass: AEEventClass
        let eventID: AEEventID
        var subroutineName: String?
        if let asidName = command.uid.asidName {
            eventClass = 0x61736372 /* kASAppleScriptSuite 'ascr' */
            eventID = 0x70736272 /* kASSubroutineEvent 'psbr' */
            subroutineName = asidName
        } else if let (class: classAE4Code, id: idAE4Code) = command.uid.ae8Code {
            eventClass = classAE4Code
            eventID = idAE4Code
        } else {
            throw UnsupportedCommand(object: self, command: command)
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
        
        return try RT_Object.fromAEDescriptor(AppData(), resultDescriptor)
    }
    
}

extension RT_AppleScript {
    
    public override var debugDescription: String {
        super.debugDescription + "[name: \(name)]"
    }
    
}
