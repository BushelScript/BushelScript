import Bushel

public typealias RT_FrameStack = RT_Stack<[Term.SemanticURI : Ref<RT_Object>]>

public class Ref<T: AnyObject> {
    public init(_ value: T) {
        self.value = value
    }
    public var value: T
}
