import Bushel
import SwiftAutomation

public protocol RT_SASpecifierConvertible: RT_Object, AEEncodable {
    
    func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier?
    
    var rt: Runtime { get }
    
}

extension RT_SASpecifierConvertible {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unencodable(object: self)
        }
        return try saSpecifier.encodeAEDescriptor(appData)
    }
    
}

extension RT_SASpecifierConvertible where Self: RT_Object {
    
    public func performByAppleEvent(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, target: RootSpecifier) throws -> RT_Object {
        let appData = target.appData
        
        let encodedArguments = try encode(arguments: arguments, implicitDirect: implicitDirect, for: self, appData: appData)
        
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unencodable(object: self)
        }
        return try saSpecifier.perform(rt, command: command, arguments: encodedArguments)
    }
    
}

internal func encode(arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, for object: RT_Object, appData: AppData) throws -> [OSType : NSAppleEventDescriptor] {
    if let unencodableKey = arguments.keys.first(where: { $0.typedUID.ae4Code == nil }) {
        throw Unencodable(object: unencodableKey)
    }
    let keys = arguments.keys.map { $0.typedUID.ae4Code! }
    
    let values: [NSAppleEventDescriptor] = try arguments.values.map { (argument: RT_Object) -> NSAppleEventDescriptor in
        guard let encodable = argument as? AEEncodable else {
            throw Unencodable(object: argument)
        }
        return try encodable.encodeAEDescriptor(appData)
    }

    var encoded = [OSType : NSAppleEventDescriptor](uniqueKeysWithValues: zip(keys, values))
    
    // This is so that unencodable implicit direct objects don't cause an
    // unnecessary command failure (since the user didn't expressly intend
    // to send the object with the event, anyway).
    if
        let implicitDirect = implicitDirect,
        let encodable = implicitDirect as? AEEncodable
    {
        do {
            encoded[keyDirectObject] = try encodable.encodeAEDescriptor(appData)
        } catch {
        }
    }
    
    return encoded
}
