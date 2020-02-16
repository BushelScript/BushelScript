import Bushel

public struct ProgramStack {
    
    var frames: [StackFrame]
    
    public init(_ rt: RTInfo) {
        self.init(frames: [StackFrame(rt, variables: [:], target: RT_Global(rt), script: rt.topScript)])
    }
    
    public init(frames: [StackFrame]) {
        self.frames = frames
    }
    
    public var currentFrame: StackFrame {
        get {
            frames.last!
        }
        set {
            frames[frames.endIndex - 1] = newValue
        }
    }
    
    public var variables: [Bushel.TermName : RT_Object] {
        currentFrame.variables
    }
    public var target: RT_Object? {
        currentFrame.target
    }
    public var script: RT_Script {
        currentFrame.script
    }
    
    mutating func push(newTarget: RT_Object? = nil) {
        frames.append(StackFrame(inheritingFrom: currentFrame, target: newTarget))
    }
    mutating func pop() {
        if frames.count > 1 {
            frames.removeLast()
        }
    }
    
    public func qualify(specifier: RT_Specifier) -> RT_Specifier {
        currentFrame.qualify(specifier: specifier)
    }
    
}

public struct StackFrame {
    
    public let rt: RTInfo
    public var variables: [Bushel.TermName : RT_Object] = [:]
    public var target: RT_Object?
    public var script: RT_Script
    
    init(inheritingFrom other: StackFrame, target: RT_Object? = nil) {
        self.rt = other.rt
        self.variables = other.variables
        self.target = target ?? other.target
        self.script = other.script
    }
    init(_ rt: RTInfo, variables: [Bushel.TermName : RT_Object], target: RT_Object?, script: RT_Script) {
        self.rt = rt
        self.variables = variables
        self.target = target
        self.script = script
    }
    
    /// Adds this stack frame's target object, if any, as the topmost parent
    /// of the given specifier.
    ///
    /// - Parameter specifier: The specifier to qualify. Modifications, if any,
    ///                        are made on a copy of the specifier to avoid
    ///                        modifying any user-accessible objects.
    ///
    /// - Returns: The more qualified version of `specifier`. If no
    ///            modifications were necessary, simply returns `specifier`.
    public func qualify(specifier: RT_Specifier) -> RT_Specifier {
        guard let target = target else {
            return specifier
        }
        let newSpecifier = specifier.clone()
        newSpecifier.setRootAncestor(target)
        return newSpecifier
    }
    
}
