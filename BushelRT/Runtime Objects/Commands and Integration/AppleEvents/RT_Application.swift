import Bushel
import AEthereal

public class RT_Application: RT_Object, RT_AEQuery, RT_Module {
    
    public let bundle: Bundle?
    public let app: App
    public var target: AETarget {
        app.target
    }
    
    public init(_ rt: Runtime, bundle: Bundle) {
        self.bundle = bundle
        self.app = App(target: bundle.bundleIdentifier.map { .bundleIdentifier($0) } ??
            .url(bundle.bundleURL))
        super.init(rt)
    }
    
    public init(_ rt: Runtime, target: AETarget) {
        self.bundle = nil
        self.app = App(target: target)
        super.init(rt)
    }
    
    public convenience init?(_ rt: Runtime, named name: String) {
        guard let id = AETarget.name(name).bundleIdentifier else {
            return nil
        }
        self.init(rt, id: id)
    }
    public convenience init?(_ rt: Runtime, id: String) {
        guard let appBundle = Bundle(applicationBundleIdentifier: id) else {
            return nil
        }
        self.init(rt, bundle: appBundle)
    }
    
    public override var description: String {
        switch target {
        case .current:
            return "current app"
        case .name(let name):
            return "app \"\(name)\""
        case .url(let url):
            return "app at \"\(url)\""
        case .bundleIdentifier(let bundleID):
            return "app id \"\(bundleID)\""
        case .processIdentifier(let pid):
            return "app with pid \(pid)"
        case .descriptor(let descriptor):
            return "app by descriptor \(descriptor)"
        case .none:
            return "invalid app"
        }
    }
    
    public override class var staticType: Types {
        .app
    }
    
    public var id: RT_Object {
        target.bundleIdentifier.map { RT_String(rt, value: $0) } ?? rt.missing
    }
    
    public var isRunning: RT_Boolean {
        RT_Boolean.withValue(rt, target.isRunning)
    }
    
    public override class var propertyKeyPaths: [Properties : AnyKeyPath] {
        [
            .id: \RT_Application.id,
            .app_running_Q: \RT_Application.isRunning
        ]
    }
    public override func evaluateStaticProperty(_ keyPath: AnyKeyPath) -> RT_Object? {
        keyPath.evaluate(on: self)
    }
    
    public override func evaluateSpecifierRootedAtSelf(_ specifier: RT_HierarchicalSpecifier) throws -> RT_Object {
        do {
            return try super.evaluateSpecifierRootedAtSelf(specifier)
        } catch {
            let get = rt.reflection.commands[.get]
            return try specifier.handleByAppleEvent(
                RT_Arguments(rt, get, [:]),
                app: app
            )
        }
    }
    
    // MARK: RT_AEQuery
    
    public func appleEventQuery() throws -> Query? {
        .rootSpecifier(.application)
    }
    
    // MARK: RT_Module
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        try handleByAppleEvent(arguments)
    }
    
    public func handleByAppleEvent(_ arguments: RT_Arguments) throws -> RT_Object {
        try handleByAppleEvent(arguments, app: App(target: target))
    }
    
}

extension RT_Application {
    
    public override var debugDescription: String {
        super.debugDescription + "[bundle: \(String(describing: bundle)), target: \(target)]"
    }
    
}
