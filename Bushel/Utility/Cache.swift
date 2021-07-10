
class Cache<Key, Value> where Key: Hashable {
    
    private let accessQueue = DispatchQueue(label: "Cache access")
    private var cache: [Key : Value] = [:]
    
    func cached(for key: Key, orElse action: () throws -> Value) rethrows -> Value {
        try accessQueue.sync {
            cache[key]
        } ?? {
            let value = try action()
            accessQueue.sync {
                cache[key] = value
            }
            return value
        }()
    }
    func cached(for key: Key, orElse action: () throws -> Value?) rethrows -> Value? {
        try accessQueue.sync {
            cache[key]
        } ?? {
            let value = try action()
            if let value = value {
                accessQueue.sync {
                    cache[key] = value
                }
            }
            return value
        }()
    }
    
    subscript(_ key: Key) -> Value? {
        get {
            cache[key]
        }
        set {
            cache[key] = newValue
        }
    }
    
    func clear() {
        cache.removeAll()
    }
    
}
