import Bushel
import AEthereal

public protocol RT_AERootSpecifier: RT_AESpecifier, RT_Module {
    
    var saRootSpecifier: AEthereal.RootSpecifier { get }
    
}

extension RT_AERootSpecifier {
    
    // MARK: RT_AESpecifier
    
    public func saSpecifier(app: App) -> AEthereal.Specifier? {
        saRootSpecifier
    }
    
    // MARK: RT_Module
    
    public func handle(_ arguments: RT_Arguments) throws -> RT_Object? {
        try handleByAppleEvent(arguments)
    }
    
    public func handleByAppleEvent(_ arguments: RT_Arguments) throws -> RT_Object {
        try handleByAppleEvent(arguments, app: saRootSpecifier.app)
    }
    
}
