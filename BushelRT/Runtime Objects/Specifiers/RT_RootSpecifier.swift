import Bushel
import SwiftAutomation

public final class RT_RootSpecifier: RT_Object, RT_AESpecifierProtocol {
    
    public enum Kind {
        case application, container, specimen
    }
    
    public let rt: RTInfo
    public var kind: Kind
    
    public init(_ rt: RTInfo, kind: Kind) {
        self.rt = rt
        self.kind = kind
    }
    
    public func rootApplication() -> (application: RT_Application?, isSelf: Bool) {
        // If we got here, a non-application RT_Specifier called us
        // and thus there is no application root
        return (application: nil, isSelf: false)
    }
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        switch kind {
        case .application:
            return RootSpecifier(rootObject: AppRootDesc, appData: appData)
        case .container:
            return RootSpecifier(rootObject: ConRootDesc, appData: appData)
        case .specimen:
            return RootSpecifier(rootObject: ItsRootDesc, appData: appData)
        }
    }
    
    public convenience init?(_ rt: RTInfo, saSpecifier: SwiftAutomation.RootSpecifier) {
        if saSpecifier === AEApp {
            self.init(rt, kind: .application)
        } else if saSpecifier === AECon {
            self.init(rt, kind: .container)
        } else if saSpecifier === AEIts {
            self.init(rt, kind: .specimen)
        } else {
            return nil
        }
    }
    
    public override var debugDescription: String {
        return "(root \(kind == .application ? "application" : (kind == .container ? "container" : "specimen")))"
    }
    
}
