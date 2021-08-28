
public class Cache<Key, Value> where Key: Hashable {
    
    private let accessQueue = DispatchQueue(label: "Cache access")
    private var cache: [Key : Value] = [:]
    
    public init() {
    }
    
    public subscript(_ key: Key) -> Value? {
        get {
            accessQueue.sync {
                cache[key]
            }
        }
        set {
            accessQueue.sync {
                cache[key] = newValue
            }
        }
    }
    
    public func clear() {
        cache.removeAll()
    }
    
}

extension Cache {
    
    public func `for`(_ key: Key, default action: @autoclosure () throws -> Value) rethrows -> Value {
        try self[key] ?? {
            let value = try action()
            self[key] = value
            return value
        }()
    }
    public func `for`(_ key: Key, default action: @autoclosure () throws -> Value?) rethrows -> Value? {
        try self[key] ?? {
            let value = try action()
            if let value = value {
                self[key] = value
            }
            return value
        }()
    }
    
}
