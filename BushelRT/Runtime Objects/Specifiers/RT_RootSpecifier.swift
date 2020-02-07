import Bushel
import SwiftAutomation

public final class RT_RootSpecifier: RT_Object, RT_SASpecifierConvertible {
    
    public typealias Kind = SwiftAutomation.RootSpecifier.Kind
    
    public let rt: RTInfo
    public var kind: Kind
    
    public init(_ rt: RTInfo, kind: Kind) {
        self.rt = rt
        self.kind = kind
    }
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        switch kind {
        case .application:
            return RootSpecifier(.application, appData: appData)
        case .container:
            return RootSpecifier(.container, appData: appData)
        case .specimen:
            return RootSpecifier(.specimen, appData: appData)
        }
    }
    
}

extension RT_RootSpecifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[root \(kind == .application ? "application" : (kind == .container ? "container" : "specimen"))]"
    }
    
}
