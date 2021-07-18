import Bushel

/// A stack of substacks of runtime objects that can perform commands (modules).
public typealias RT_ModuleStack = Stack<RT_ModuleSubstack>

/// A stack of runtime objects that can perform commands (modules).
public typealias RT_ModuleSubstack = Stack<RT_Module>

extension RT_ModuleStack {
    
    public mutating func addFunction(_ function: RT_Function) {
        if let targetedModule = top.bottom as? RT_LocalModule {
            targetedModule.functions.add(function)
        } else {
            let script = RT_Script(function.rt)
            script.functions.add(function)
            push(Stack<RT_Module>(bottom: script))
        }
    }
    
}

public func propagate<Result>(from target: RT_Module? = nil, up moduleStack: RT_ModuleStack, _ function: (_ target: RT_Module) throws -> Result?) rethrows -> Result? {
    try target.flatMap { try function($0) } ??
        moduleStack.contents
        .reversed()
        .firstNonnil {
            try $0.contents
                .reversed()
                .reduce(nil) { try $0 ?? function($1) }
        }
}
public func propagate<Result>(from target: RT_Object, up moduleStack: RT_ModuleStack, _ function: (_ target: RT_Object) throws -> Result?) rethrows -> Result? {
    try function(target) ?? propagate(up: moduleStack, function)
}

extension Sequence {
    
    fileprivate func firstNonnil<Result>(_ transform: (Element) throws -> Result?) rethrows -> Result? {
        for item in self {
            if let result = try transform(item) {
                return result
            }
        }
        return nil
    }
    
}
