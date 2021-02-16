import Bushel

public struct ProgramStack {
    
    private var frames = Stack<StackFrame>()
    
    public init(_ rt: Runtime) {
        frames.push(StackFrame(rt, variables: [:], script: rt.topScript))
    }
    
    public var currentFrame: StackFrame {
        get {
            frames.top!
        }
        set {
            frames.top = newValue
        }
    }
    
    public var variables: [Bushel.Term.Name : RT_Object] {
        get {
            currentFrame.variables
        }
        set {
            currentFrame.variables = newValue
        }
    }
    
    public mutating func pushFrame() {
        frames.push(StackFrame(inheritingFrom: currentFrame))
    }
    public mutating func popFrame() {
        frames.popIfNotLast()
    }
    
}

public struct Stack<Element> {
    
    public private(set) var elements: [Element] = []
    
    public var top: Element? {
        get {
            elements.last
        }
        set {
            guard let newValue = newValue else {
                preconditionFailure("Cannot set top of Stack to nil")
            }
            elements[elements.endIndex - 1] = newValue
        }
    }
    
    public mutating func push(_ newElement: Element) {
        elements.append(newElement)
    }
    
    public mutating func pop() {
        _ = elements.popLast()
    }
    
}

extension Stack {
    
    public mutating func popIfNotLast() {
        if elements.count > 1 {
            pop()
        }
    }
    
}

public struct StackFrame {
    
    public let rt: Runtime
    public var variables: [Bushel.Term.Name : RT_Object] = [:]
    public var script: RT_Script
    
    init(inheritingFrom other: StackFrame) {
        self.rt = other.rt
        self.variables = other.variables
        self.script = other.script
    }
    init(_ rt: Runtime, variables: [Bushel.Term.Name : RT_Object], script: RT_Script) {
        self.rt = rt
        self.variables = variables
        self.script = script
    }
    
}
