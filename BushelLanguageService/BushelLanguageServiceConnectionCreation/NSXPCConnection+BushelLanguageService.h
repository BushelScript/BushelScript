#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSXPCConnection (BushelLanguageService)

/**
 Creates and returns a connection to the Bushel Language Service.
 The connection is pre-resumed, but is not guaranteed to be valid.

 @param interruptionHandler The interruption handler to attach to the connection.
 @param invalidationHandler The invalidation handler to attach to the connection.
 @return The new connection.
 */
+ (instancetype)bushelLanguageServiceConnectionWithInterruptionHandler:(void(^)(void))interruptionHandler invalidationHandler:(void(^)(void))invalidationHandler;

@end

NS_ASSUME_NONNULL_END
