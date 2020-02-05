import Bushel
import SwiftAutomation

public protocol RT_SASpecifierConvertible: RT_Object, AEEncodable {
    
    func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier?
    
    var rt: RTInfo { get }
    
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
    
    public func performByAppleEvent(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, targetBundleID: String) throws -> RT_Object {
        let appData = SwiftAutomation.RootSpecifier(bundleIdentifier: targetBundleID).appData
        
        // Pack argument values
        
        guard !arguments.keys.contains(where: { $0.typedUID.ae4Code == nil }) else {
            throw Unencodable(object: self)
        }
        let keys = arguments.keys.map { $0.typedUID.ae4Code! }
        
        let values: [NSAppleEventDescriptor] = try arguments.values.map { (argument: RT_Object) -> NSAppleEventDescriptor in
            guard let encodable = argument as? AEEncodable else {
                throw Unencodable(object: argument)
            }
            return try encodable.encodeAEDescriptor(appData)
        }
        
        var packedArguments = [OSType : NSAppleEventDescriptor](uniqueKeysWithValues: zip(keys, values))
        
        // This is so that unencodable implicit direct objects don't cause an
        // unnecessary command failure (since the user didn't expressly intend
        // to send the object with the event, anyway).
        if
            let implicitDirect = implicitDirect,
            let encodable = implicitDirect as? AEEncodable
        {
            do {
                packedArguments[keyDirectObject] = try encodable.encodeAEDescriptor(appData)
            } catch {
            }
        }
        
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unencodable(object: self)
        }
        return try saSpecifier.perform(rt, command: command, arguments: packedArguments)
    }
    
}
