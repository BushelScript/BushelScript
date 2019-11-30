import Bushel
import SwiftAutomation

public class RT_Application: RT_Object, RT_SASpecifierConvertible {
    
    public let rt: RTInfo
    public let bundle: Bundle
    public let bundleIdentifier: String
    
    public init(_ rt: RTInfo, bundle: Bundle) {
        guard let bundleIdentifier = bundle.bundleIdentifier else {
            preconditionFailure()
        }
        self.rt = rt
        self.bundle = bundle
        self.bundleIdentifier = bundleIdentifier
    }
    
    public convenience init(_ rt: RTInfo, currentApplication: ()) {
        if let bundleID = rt.currentApplicationBundleID {
            self.init(rt, bundle: Bundle(applicationBundleIdentifier: bundleID) ?? Bundle(for: RT_Application.self))
        } else {
            self.init(rt, bundle: Bundle(for: RT_Application.self))
        }
    }
    
    public override var description: String {
        "app id \"\(bundleIdentifier)\""
    }
    
    public override var debugDescription: String {
        super.debugDescription + "[id: \(bundleIdentifier)]"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.application)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public func saSpecifier(appData: AppData) -> SwiftAutomation.Specifier? {
        RootSpecifier(bundleIdentifier: bundleIdentifier)
    }
    
    public override func perform(command: CommandInfo, arguments: [Bushel.ConstantTerm : RT_Object]) -> RT_Object? {
        return performByAppleEvent(command: command, arguments: arguments, targetBundleID: bundleIdentifier)
    }
    
}
