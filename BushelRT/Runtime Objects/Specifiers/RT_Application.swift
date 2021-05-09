import Bushel
import SwiftAutomation

public class RT_Application: RT_Object {
    
    public let bundle: Bundle?
    public let target: TargetApplication
    
    public init(_ rt: Runtime, bundle: Bundle) {
        self.bundle = bundle
        self.target = bundle.bundleIdentifier.map { .bundleIdentifier($0, false) } ??
            .url(bundle.bundleURL)
        super.init(rt)
    }
    
    public init(_ rt: Runtime, target: TargetApplication) {
        self.bundle = nil
        self.target = target
        super.init(rt)
    }
    
    public convenience init(_ rt: Runtime, currentApplication: ()) {
        if let bundleID = rt.currentApplicationBundleID {
            self.init(rt, target: .bundleIdentifier(bundleID, false))
        } else {
            self.init(rt, target: .current)
        }
    }
    
    public convenience init?(_ rt: Runtime, named name: String) {
        guard
            let appBundleID = TargetApplication.name(name).bundleIdentifier,
            let appBundle = Bundle(applicationBundleIdentifier: appBundleID)
        else {
            return nil
        }
        self.init(rt, bundle: appBundle)
    }
    
    public override var description: String {
        switch target {
        case .current:
            return "current application"
        case .name(let name):
            return "application \"\(name)\""
        case .url(let url):
            return "application at \"\(url)\""
        case .bundleIdentifier(let bundleID, _):
            return "application id \"\(bundleID)\""
        case .processIdentifier(let pid):
            return "application with pid \(pid)"
        case .Descriptor(let descriptor):
            return "application by descriptor \(descriptor)"
        case .none:
            return "not-an-application"
        }
    }
    
    private static let typeInfo_ = TypeInfo(.application)
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
        RootSpecifier(.application, appData: AppData(target: target))
    }
    
}

// MARK: RT_SpecifierRemoteRoot
extension RT_Application: RT_SpecifierRemoteRoot {
    
    public func evaluate(specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        return try specifier.performByAppleEvent(command: CommandInfo(Commands.get), arguments: [ParameterInfo(.direct): specifier], implicitDirect: nil, target: saSpecifier())
    }
    
    public func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?, for specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        try specifier.performByAppleEvent(command: command, arguments: arguments, implicitDirect: implicitDirect, target: saSpecifier())
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[bundle: \(String(describing: bundle)), target: \(target)]"
    }
    
}
