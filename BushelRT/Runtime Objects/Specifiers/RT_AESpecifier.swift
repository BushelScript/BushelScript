import Bushel
import AEthereal

public protocol RT_AESpecifier: RT_Object, AEEncodable {
    
    func saSpecifier(app: App) throws -> AEthereal.Specifier?
    
}

extension RT_AESpecifier {
    
    public func encodeAEDescriptor(_ app: App) throws -> NSAppleEventDescriptor {
        guard let saSpecifier = try self.saSpecifier(app: app) else {
            throw Unencodable(object: self)
        }
        return try saSpecifier.encodeAEDescriptor(app)
    }
    
    func handleByAppleEvent(_ arguments: RT_Arguments, app: App) throws -> RT_Object {
        // AEthereal's Specifier#sendAppleEvent already adds the "subject"
        // AE attribute for us, so don't attempt to encode the target argument
        // (target parameters aren't supported for AE commands;
        // the target must be specified with 'tell' et al.).
        var arguments = arguments
        arguments.contents.removeValue(forKey: Reflection.Parameter(.target))
        
        let encodedArguments = try aeEncode(arguments, app: app)
        guard let saSpecifier = try self.saSpecifier(app: app) else {
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
            return try RT_Object.fromAEDescriptor(rt, app, resultDescriptor)
        } catch let error as CommandError {
            throw RemoteCommandError(remoteObject: app.target, command: arguments.command, error: error)
        } catch let error as AutomationError {
            if error._code == errAEEventNotPermitted {
                throw RemoteCommandsDisallowed(remoteObject: app.target)
            } else {
                throw RemoteCommandError(remoteObject: app.target, command: arguments.command, error: error)
            }
        } catch let error as DecodeError {
            throw Undecodable(error: error)
        }
    }
    
}
