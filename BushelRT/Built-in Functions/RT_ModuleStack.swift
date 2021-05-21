import Bushel

/// A stack of runtime objects that act as bags of functions (modules).
public typealias RT_ModuleStack = RT_Stack<RT_Module>

extension RT_ModuleStack {
    
    public mutating func add(function: RT_Function) {
        if let top = top as? RT_LocalModule {
            top.functions.add(function)
        } else {
            let script = RT_Script(function.rt)
            script.functions.add(function)
            push(script)
        }
    }
    
}

public func propagate<Result>(from target: RT_Module? = nil, up moduleStack: RT_ModuleStack, _ function: (_ target: RT_Module) throws -> Result?) rethrows -> Result? {
    try target.flatMap { try function($0) } ?? moduleStack.contents.reversed().reduce(nil) { try $0 ?? function($1) }
}
public func propagate<Result>(from target: RT_Object, up moduleStack: RT_ModuleStack, _ function: (_ target: RT_Object) throws -> Result?) rethrows -> Result? {
    try function(target) ?? propagate(up: moduleStack, function)
}
