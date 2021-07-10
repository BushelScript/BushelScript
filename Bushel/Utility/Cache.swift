
class Cache<Key, Value> where Key: Hashable {
    
    private let accessQueue = DispatchQueue(label: "Cache access")
    private var cache: [Key : Value] = [:]
    
    subscript(_ key: Key) -> Value? {
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
    
    func clear() {
        cache.removeAll()
    }
    
}

extension Cache {
    
    func `for`(_ key: Key, default action: @autoclosure () throws -> Value) rethrows -> Value {
        try self[key] ?? {
            let value = try action()
            self[key] = value
            return value
        }()
    }
    func `for`(_ key: Key, default action: @autoclosure () throws -> Value?) rethrows -> Value? {
        try self[key] ?? {
            let value = try action()
            if let value = value {
                self[key] = value
            }
            return value
        }()
    }
    
}
