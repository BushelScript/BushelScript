#import "NSXPCConnection+BushelLanguageService.h"
#import "BushelLanguageServiceProtocol.h"

static NSString *const serviceBundleID = @"com.justcheesy.BushelLanguageService";

@implementation NSXPCConnection (BushelLanguageService)

+ (instancetype)bushelLanguageServiceConnectionWithInterruptionHandler:(void (^)(void))interruptionHandler invalidationHandler:(void (^)(void))invalidationHandler {
    NSXPCConnection *connection = [[self alloc] initWithServiceName:serviceBundleID];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(BushelLanguageServiceProtocol)];
    connection.interruptionHandler = interruptionHandler;
    connection.invalidationHandler = invalidationHandler;
    [connection resume];
    return connection;
}

@end
