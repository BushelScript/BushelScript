#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BushelRT_TriviallyCopiable : NSProxy <NSCopying>

- (instancetype)initWithValue:value;

@property(nonatomic) id value;

@end

NS_ASSUME_NONNULL_END
