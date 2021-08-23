#import "TriviallyCopiable.h"

@implementation BushelRT_TriviallyCopiable

- (instancetype)initWithValue:value {
    _value = value;
    return self;
}

- copyWithZone:(NSZone *)zone {
    return self;
}

- (NSString *)description {
    return [_value description];
}
- (NSString *)debugDescription {
    return [_value debugDescription];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    return [_value methodSignatureForSelector:selector];
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    [invocation invokeWithTarget:_value];
}

- (BOOL)respondsToSelector:(SEL)selector {
    return [_value respondsToSelector:selector];
}

@end
