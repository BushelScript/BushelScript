import Bushel

private let systemEventsBundleID = "com.apple.systemevents"

public final class RT_System: RT_Application {
    
    public init(_ rt: Runtime) {
        super.init(rt, target: .bundleIdentifier(systemEventsBundleID, false))
    }
    
    public override var description: String {
        "system"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.system, [.supertype(TypeInfo(TypeUID.application))])
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
}

extension RT_System {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
