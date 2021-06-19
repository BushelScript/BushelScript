// BushelScript Editor application
// © 2019-2021 Ian A. Gregory.
// See file LICENSE.txt for licensing information.

@propertyWrapper
public struct Atomic<Value> {
    
    public var value: Value
    private let queue = DispatchQueue(label: "Atomic access")
    
    public init(wrappedValue: Value) {
        value = wrappedValue
    }
    
    public var wrappedValue: Value {
        get {
            queue.sync { value }
        }
        set {
            queue.sync { value = newValue }
        }
    }
    
}
