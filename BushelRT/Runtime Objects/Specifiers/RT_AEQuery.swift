import Bushel
import AEthereal

public protocol RT_AEQuery: RT_Object, Encodable {
    
    func appleEventQuery() throws -> AEthereal.Query?
    
}

extension RT_AEQuery {
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        guard let query = try appleEventQuery() else {
            throw Unencodable(object: self)
        }
        try container.encode(query)
    }
    
    func handleByAppleEvent(_ arguments: RT_Arguments, app: App) throws -> RT_Object {
        // AEthereal's App#sendAppleEvent already sets the "subject"
        // AE attribute to the "target query" that we provide.
        var arguments = arguments
        let targetQuery = (arguments.contents.removeValue(forKey: Reflection.Parameter(.target)) as? RT_AEQuery) ?? self
        let aeParameters = try makeAEParameters(arguments, app: app)
        guard let (`class`, id) = arguments.command.id.ae8Code else {
            throw Unencodable(object: arguments.command)
        }
        do {
            let result = try app.sendAppleEvent(
                eventClass: `class`,
                eventID: `id`,
                targetQuery: try targetQuery.appleEventQuery() ?? .rootSpecifier(.application),
                parameters: aeParameters
            )
            return try RT_Object.decode(rt, app: app, aeDescriptor: result)
        } catch let error as SendFailure {
            throw RemoteCommandError(remoteObject: RT_Application(rt, target: app.target), command: arguments.command, error: error.cause ?? error)
        } catch let error as AutomationError {
            if error._code == errAEEventNotPermitted {
                throw RemoteCommandsDisallowed(remoteObject: RT_Application(rt, target: app.target))
            } else {
                throw RemoteCommandError(remoteObject: RT_Application(rt, target: app.target), command: arguments.command, error: error)
            }
        } catch let error as DecodingError {
            throw Undecodable(reason: error.localizedDescription)
        }
    }
    
}
