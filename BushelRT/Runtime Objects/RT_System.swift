import Bushel

public class RT_System: RT_Object {
    
    public let rt: RTInfo
    
    public init(_ rt: RTInfo) {
        self.rt = rt
    }
    
    public override var description: String {
        "system"
    }
    
    private static let typeInfo_ = TypeInfo(TypeUID.system)
    public override class var typeInfo: TypeInfo {
        typeInfo_
    }
    
    public override func perform(command: CommandInfo, arguments: [ParameterInfo : RT_Object], implicitDirect: RT_Object?) throws -> RT_Object? {
        // FIXME: fix
        try super.perform(command: command, arguments: arguments, implicitDirect: implicitDirect)
    }
    
}

extension RT_System {
    
    public override var debugDescription: String {
        super.debugDescription
    }
    
}
