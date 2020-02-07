import Bushel
import SwiftAutomation

public class RT_Application: RT_Object, RT_SASpecifierConvertible, RT_SpecifierRemoteRoot {
    
    public let rt: RTInfo
    public let bundle: Bundle
    public let bundleIdentifier: String
    
    public init(_ rt: RTInfo, bundle: Bundle) {
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            preconditionFailure()
        }
        self.rt = rt
        self.bundle = bundle
        self.bundleIdentifier = bundleIdentifier
    }
    
    public convenience init(_ rt: RTInfo, currentApplication: ()) {
        if let bundleID = rt.currentApplicationBundleID {
            self.init(rt, bundle: Bundle(applicationBundleIdentifier: bundleID) ?? Bundle(for: RT_Application.self))
        } else {
            self.init(rt, bundle: Bundle(for: RT_Application.self))
        }
    }
    
    public override var description: String {
        "app id \"\(bundleIdentifier)\""
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.application)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        try performByAppleEvent(command: command, arguments: arguments, implicitDirect: implicitDirect, targetBundleID: bundleIdentifier)
    }
    
}

// MARK: RT_SASpecifierConvertible
extension RT_Application {
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        RootSpecifier(bundleIdentifier: bundleIdentifier)
    }
    
}

// MARK: RT_SpecifierRemoteRoot
extension RT_Application {
    
    public func evaluate(specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        return try specifier.performByAppleEvent(command: rt.command(forUID: TypedTermUID(CommandUID.get)), arguments: [ParameterInfo(.direct): specifier], implicitDirect: nil, targetBundleID: bundleIdentifier)
    }
    
    public func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, for specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        try specifier.performByAppleEvent(command: command, arguments: arguments, implicitDirect: implicitDirect, targetBundleID: bundleIdentifier)
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[id: \(bundleIdentifier)]"
    }
    
}
