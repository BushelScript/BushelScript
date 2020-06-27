import Bushel
import SwiftAutomation

public final class RT_RootSpecifier: RT_Object, RT_SASpecifierConvertible {
    
    public enum Kind {
        /// Root of all absolute object specifiers.
        /// e.g., `document 1 of «application»`.
        case application
        /// Root of an object specifier specifying the start or end of a range of
        /// elements in a by-range specifier.
        /// e.g., `folders (folder 2 of «container») thru (folder -1 of «container»)`.
        case container
        /// Root of an object specifier specifying an element whose state is being
        /// compared in a by-test specifier.
        /// e.g., `every track where (rating of «specimen» > 50)`.
        case specimen
    }
    
    public let rt: RTInfo
    public var kind: Kind
    
    public init(_ rt: RTInfo, kind: Kind) {
        self.rt = rt
        self.kind = kind
    }
    
    public static func fromSARootSpecifier(_ rt: RTInfo, _ specifier: SwiftAutomation.RootSpecifier) throws -> RT_Object {
        switch specifier.kind {
        case .application:
            return RT_RootSpecifier(rt, kind: .application)
        case .container:
            return RT_RootSpecifier(rt, kind: .container)
        case .specimen:
            return RT_RootSpecifier(rt, kind: .specimen)
        case let .object(descriptor):
            return try RT_Object.fromAEDescriptor(rt, specifier.appData, descriptor)
        }
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
    
    var rootDescription: String? {
        switch kind {
        case .application:
            return nil
        case .container:
            return "container"
        case .specimen:
            return "specimen"
        }
    }
    
}

extension RT_RootSpecifier {
    
    public override var debugDescription: String {
        super.debugDescription + "[root " + {
            switch kind {
            case .application:
                return "application"
            case .container:
                return "container"
            case .specimen:
                return "specimen"
            }
        }() + "]"
    }
    
}
