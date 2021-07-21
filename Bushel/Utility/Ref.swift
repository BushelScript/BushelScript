
/// A reference type wrapper for a `T`.
public class Ref<T> {
    public init(_ value: T) {
        self.value = value
    }
    public var value: T
}
