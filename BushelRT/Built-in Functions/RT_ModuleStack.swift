import Bushel

/// A stack of runtime objects that act as bags of functions (modules).
public typealias RT_ModuleStack = RT_Stack<RT_Module>

public func propagate<Result>(from target: RT_Object, up moduleStack: RT_ModuleStack, _ function: (_ target: RT_Object) throws -> Result?) rethrows -> Result? {
    try function(target) ?? moduleStack.contents.reversed().reduce(nil) { try $0 ?? function($1) }
}
