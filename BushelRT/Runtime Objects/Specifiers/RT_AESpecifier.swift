import Bushel
import SwiftAutomation

public protocol RT_AESpecifier: RT_Object, AEEncodable {
    
    func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier?
    
}

extension RT_AESpecifier {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unencodable(object: self)
        }
        return try saSpecifier.encodeAEDescriptor(appData)
    }
    
    func handleByAppleEvent(_ arguments: RT_Arguments, appData: AppData) throws -> RT_Object {
        let encodedArguments = try aeEncode(arguments, appData: appData)
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unencodable(object: self)
        }
        
        guard let (`class`, id) = arguments.command.id.ae8Code else {
            throw Unencodable(object: arguments.command)
        }
        do {
            let wrappedResultDescriptor: ReplyEventDescriptor = try saSpecifier.sendAppleEvent(`class`, id, encodedArguments)
            guard let resultDescriptor = wrappedResultDescriptor.result else {
                if wrappedResultDescriptor.errorNumber == 0 {
                    // Succeeded, but no result returned.
                    return rt.null
                } else {
                    throw AutomationError(code: wrappedResultDescriptor.errorNumber)
                }
            }
            return try RT_Object.fromAEDescriptor(rt, appData, resultDescriptor)
        } catch let error as CommandError {
            throw RemoteCommandError(remoteObject: appData.target, command: arguments.command, error: error)
        } catch let error as AutomationError {
            if error._code == errAEEventNotPermitted {
                throw RemoteCommandsDisallowed(remoteObject: appData.target)
            } else {
                throw RemoteCommandError(remoteObject: appData.target, command: arguments.command, error: error)
            }
        } catch let error as UnpackError {
            throw Undecodable(error: error)
        }
    }
    
}
