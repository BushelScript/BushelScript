NS_ASSUME_NONNULL_BEGIN

static inline void* toOpaque(id object) {
    return (__bridge void*)object;
}

static inline id fromOpaque(void* opaque) {
    return (__bridge id)opaque;
}

NS_ASSUME_NONNULL_END
