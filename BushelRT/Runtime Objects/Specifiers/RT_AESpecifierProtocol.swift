import Bushel
import SwiftAutomation

public protocol RT_SASpecifierConvertible: AEEncodable {
    
    func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier?
    
    var rt: RTInfo { get }
    
}

public protocol RT_AESpecifierProtocol: RT_SASpecifierConvertible {
    
    func rootApplication() -> (application: RT_Application?, isSelf: Bool)
    
}

extension RT_SASpecifierConvertible {
    
    public func encodeAEDescriptor(_ appData: AppData) throws -> NSAppleEventDescriptor {
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            throw Unpackable()
        }
        return try saSpecifier.encodeAEDescriptor(appData)
    }
    
}

extension RT_SASpecifierConvertible where Self: RT_Object {
    
    public func performByAppleEvent(command: CommandInfo, arguments: [ParameterInfo : RT_Object], targetBundleID: String) -> RT_Object? {
        let appData = SwiftAutomation.RootSpecifier(bundleIdentifier: targetBundleID).appData
        
        // Pack argument values
        let packedArguments: [OSType : NSAppleEventDescriptor]
        do {
            guard !arguments.keys.contains(where: { $0.code == nil }) else {
                throw Unpackable()
            }
            let keys = arguments.keys.map { $0.code! }
            
            let values: [NSAppleEventDescriptor] = try arguments.values.map { (argument: RT_Object) -> NSAppleEventDescriptor in
                guard let selfPacking = argument as? AEEncodable else {
                    throw Unpackable()
                }
                return try selfPacking.encodeAEDescriptor(appData)
            }
            
            packedArguments = [OSType : NSAppleEventDescriptor](uniqueKeysWithValues: zip(keys, values))
        } catch let error as Unpackable {
            fatalError(error.localizedDescription)
        } catch {
            fatalError(error.localizedDescription)
        }
        
        guard let saSpecifier = self.saSpecifier(appData: appData) else {
            print(self)
            fatalError("specifier cannot perform commands")
        }
        return saSpecifier.perform(rt, command: command, arguments: packedArguments)
    }
    
}
