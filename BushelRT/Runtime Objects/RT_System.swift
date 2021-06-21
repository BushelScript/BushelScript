import Bushel

private let systemEventsBundleID = "com.apple.systemevents"

public final class RT_System: RT_Application {
    
    public init(_ rt: Runtime) {
        super.init(rt, target: .bundleIdentifier(systemEventsBundleID, false))
    }
    
    public override var description: String {
        "system"
    }
    
    public override class var staticType: Types {
        .system
    }
    
}

extension RT_System {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
