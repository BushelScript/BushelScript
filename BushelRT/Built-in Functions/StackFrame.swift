import Bushel

public struct ProgramStack {
    
    private var frames: [StackFrame]
    
    public init(_ rt: RTInfo) {
        self.init(frames: [StackFrame(rt, variables: [:])])
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
    
    init(inheritingFrom other: StackFrame, target: RT_Object? = nil) {
        self.rt = other.rt
        self.variables = other.variables
        self.target = target ?? other.target
    }
    init(_ rt: RTInfo, variables: [Bushel.TermName : RT_Object]) {
        self.rt = rt
        self.variables = variables
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
