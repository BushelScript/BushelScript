import Bushel
import AEthereal

public class RT_Application: RT_Object, RT_AERootSpecifier {
    
    public let bundle: Bundle?
    public let target: AETarget
    
    public init(_ rt: Runtime, bundle: Bundle) {
        self.bundle = bundle
        self.target = bundle.bundleIdentifier.map { .bundleIdentifier($0) } ??
            .url(bundle.bundleURL)
        super.init(rt)
    }
    
    public init(_ rt: Runtime, target: AETarget) {
        self.bundle = nil
        self.target = target
        super.init(rt)
    }
    
    public convenience init?(_ rt: Runtime, named name: String) {
        guard
            let appBundleID = AETarget.name(name).bundleIdentifier,
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
        case .bundleIdentifier(let bundleID):
            return "application id \"\(bundleID)\""
        case .processIdentifier(let pid):
            return "application with pid \(pid)"
        case .descriptor(let descriptor):
            return "application by descriptor \(descriptor)"
        case .none:
            return "not-an-application"
        }
    }
    
    public override class var staticType: Types {
        .app
    }
    
    // MARK: RT_AERootSpecifier
    
    public var saRootSpecifier: RootSpecifier {
        RootSpecifier(.application, app: App(target: target))
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[bundle: \(String(describing: bundle)), target: \(target)]"
    }
    
}
