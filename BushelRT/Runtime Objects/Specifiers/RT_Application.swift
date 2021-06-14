import Bushel
import SwiftAutomation

public class RT_Application: RT_Object, RT_AERootSpecifier {
    
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
    
    private static let typeInfo_ = TypeInfo(.app)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    // MARK: RT_AERootSpecifier
    
    public var saRootSpecifier: RootSpecifier {
        RootSpecifier(.application, appData: AppData(target: target))
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[bundle: \(String(describing: bundle)), target: \(target)]"
    }
    
}
