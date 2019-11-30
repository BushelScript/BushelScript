import Bushel
import LLVM

public struct StaticStack {
    
    private var frames: [StaticStackFrame] = [StaticStackFrame()]
    
    public var currentFrame: StaticStackFrame {
        get {
            return frames.last!
        }
        set {
            frames[frames.endIndex - 1] = newValue
        }
    }
    
    public var currentTarget: IRValue? {
        get {
            return frames.last { $0.target != nil }?.target
        }
        set {
            currentFrame.target = newValue
        }
    }
    
    public func variable(for name: TermName) -> IRValue? {
        for frame in frames.reversed() {
            if let variable = frame.variables[name] {
                return variable
            }
        }
        return nil
    }
    
    public func function(for name: TermName) -> Function? {
        for frame in frames.reversed() {
            if let function = frame.functions[name] {
                return function
            }
        }
        return nil
    }
    
    public mutating func push() {
        frames.append(StaticStackFrame())
    }
    
    public mutating func pop() {
        if frames.count > 1 {
            frames.removeLast()
        }
    }
    
}

public struct StaticStackFrame {
    
    public private(set) var variables: [TermName : IRValue] = [:]
    public private(set) var functions: [TermName : Function] = [:] {
        didSet {
            let newKeys = Set(functions.keys).subtracting(Set(oldValue.keys))
            for newKey in newKeys {
                variables[newKey] = functions[newKey]
            }
        }
    }
    public var target: IRValue?
    
    public mutating func add(variable: IRValue, for name: TermName) {
        variables[name] = variable
    }
    
    public mutating func add(function: Function, for name: TermName) {
        functions[name] = function
    }
    
}
