import Bushel
import SwiftAutomation

public class RT_Application: RT_Object {
    
    public let rt: RTInfo
    
    public let bundle: Bundle?
    public let target: TargetApplication
    
    public init(_ rt: RTInfo, bundle: Bundle) {
        self.rt = rt
        self.bundle = bundle
        self.target = bundle.bundleIdentifier.map { .bundleIdentifier($0, false) } ??
            .url(bundle.bundleURL)
    }
    
    public init(_ rt: RTInfo, target: TargetApplication) {
        self.rt = rt
        self.bundle = nil
        self.target = target
    }
    
    public convenience init(_ rt: RTInfo, currentApplication: ()) {
        if let bundleID = rt.currentApplicationBundleID {
            self.init(rt, target: .bundleIdentifier(bundleID, false))
        } else {
            self.init(rt, target: .current)
        }
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
        RootSpecifier(.application, appData: AppData(target: target))
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
        super.debugDescription + "[bundle: \(String(describing: bundle)), target: \(target)]"
    }
    
}
