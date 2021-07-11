
public struct BushelCache {
    
    public init(dictionaryCache: TermDictionaryCache, resourceCache: ResourceCache) {
        self.dictionaryCache = dictionaryCache
        self.resourceCache = resourceCache
    }
    
    public var dictionaryCache: TermDictionaryCache
    public var resourceCache: ResourceCache
    
    public func clearCache() {
        dictionaryCache.clearCache()
        resourceCache.clearCache()
    }
    
}
