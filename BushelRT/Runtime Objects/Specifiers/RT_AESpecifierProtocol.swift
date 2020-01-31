import Bushel
import SwiftAutomation

public protocol RT_SASpecifierConvertible: RT_Object, AEEncodable {
    
    func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier?
    
    var rt: RTInfo { get }
    
}

extension RT_SASpecifierConvertible {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unpackable(object: self)
        }
        return try saSpecifier.encodeAEDescriptor(appData)
    }
    
}

extension RT_SASpecifierConvertible where Self: RT_Object {
    
    public func performByAppleEvent(command: CommandInfo, arguments: [ParameterInfo : RT_Object], targetBundleID: String) throws -> RT_Object {
        let appData = SwiftAutomation.RootSpecifier(bundleIdentifier: targetBundleID).appData
        
        // Pack argument values
        let packedArguments: [OSType : NSAppleEventDescriptor]
        guard !arguments.keys.contains(where: { $0.typedUID.ae4Code == nil }) else {
            throw Unpackable(object: self)
        }
        let keys = arguments.keys.map { $0.typedUID.ae4Code! }
        
        let values: [NSAppleEventDescriptor] = try arguments.values.map { (argument: RT_Object) -> NSAppleEventDescriptor in
            guard let selfPacking = argument as? AEEncodable else {
                throw Unpackable(object: argument)
            }
            return try selfPacking.encodeAEDescriptor(appData)
        }
        
        packedArguments = [OSType : NSAppleEventDescriptor](uniqueKeysWithValues: zip(keys, values))
        
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unpackable(object: self)
        }
        return try saSpecifier.perform(rt, command: command, arguments: packedArguments)
    }
    
}
