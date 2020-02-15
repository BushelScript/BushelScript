import Bushel
import SwiftAutomation

public class RT_Application: RT_Object {
    
    public let rt: RTInfo
    public let bundle: Bundle
    public let bundleIdentifier: String?
    
    public init(_ rt: RTInfo, bundle: Bundle) {
        self.rt = rt
        self.bundle = bundle
        self.bundleIdentifier = bundle.bundleIdentifier
    }
    
    public convenience init(_ rt: RTInfo, currentApplication: ()) {
        if let bundleID = rt.currentApplicationBundleID {
            self.init(rt, bundle: Bundle(applicationBundleIdentifier: bundleID) ?? Bundle(for: RT_Application.self))
        } else {
            self.init(rt, bundle: Bundle(for: RT_Application.self))
        }
    }
    
    public override var description: String {
        if let bundleIdentifier = bundleIdentifier {
            return "application id \"\(bundleIdentifier)\""
        } else {
            return "application \"\(bundle.bundleURL.deletingPathExtension().lastPathComponent)\""
        }
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.application)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        try performByAppleEvent(command: command, arguments: arguments, implicitDirect: implicitDirect, target: saSpecifier())
    }
    
}

// MARK: RT_SASpecifierConvertible
extension RT_Application: RT_SASpecifierConvertible {
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        saSpecifier()
    }

    public func saSpecifier() -> RootSpecifier {
        bundleIdentifier.map { RootSpecifier(bundleIdentifier: $0) } ??
            RootSpecifier(url: bundle.bundleURL)
    }
    
}

// MARK: RT_SpecifierRemoteRoot
extension RT_Application: RT_SpecifierRemoteRoot {
    
    public func evaluate(specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        return try specifier.performByAppleEvent(command: rt.command(forUID: TypedTermUID(CommandUID.get)), arguments: [ParameterInfo(.direct): specifier], implicitDirect: nil, target: saSpecifier())
    }
    
    public func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, for specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        try specifier.performByAppleEvent(command: command, arguments: arguments, implicitDirect: implicitDirect, target: saSpecifier())
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[bundle: \(bundle)]"
    }
    
}
