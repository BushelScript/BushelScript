import Bushel
import AEthereal

public final class RT_RootSpecifier: RT_Object, RT_AEQuery {
    
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
    
    public var kind: Kind
    
    public init(_ rt: Runtime, kind: Kind) {
        self.kind = kind
        super.init(rt)
    }
    
    public func appleEventQuery() -> AEthereal.Query? {
        switch kind {
        case .application:
            return .rootSpecifier(.application)
        case .container:
            return .rootSpecifier(.container)
        case .specimen:
            return .rootSpecifier(.specimen)
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
