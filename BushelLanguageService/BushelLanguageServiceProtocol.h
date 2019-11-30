#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id LanguageModuleToken;
typedef id ProgramToken;
typedef id RTObjectToken;
typedef id ErrorToken;
typedef id SourceFixToken;

@protocol BushelLanguageServiceProtocol <NSObject>

- (void)loadLanguageModuleWithIdentifier:(NSString *)moduleIdentifier reply:(void (^)(_Nullable LanguageModuleToken))reply;
- (void)unloadLanguageModule:(LanguageModuleToken)module reply:(void(^)(BOOL))reply;

- (void)parseSource:(NSString *)source usingLanguageModule:(LanguageModuleToken)module reply:(void (^)(_Nullable ProgramToken, _Nullable ErrorToken))reply;
- (void)releaseProgram:(ProgramToken)program reply:(void(^)(BOOL))reply;

- (void)prettyPrintProgram:(ProgramToken)program reply:(void(^)(NSString *_Nullable))reply;
- (void)reformatProgram:(ProgramToken)program usingLanguageModule:(LanguageModuleToken)module reply:(void(^)(NSString *_Nullable))reply;

- (void)runProgram:(ProgramToken)program currentApplicationID:(NSString *)currentApplicationID reply:(void(^)(_Nullable RTObjectToken))reply;

- (void)copyDescriptionForObject:(RTObjectToken)object reply:(void(^)(NSString *_Nullable))reply;

- (void)copyNSErrorFromError:(ErrorToken)error reply:(void(^)(NSError *))reply;
- (void)releaseError:(ErrorToken)error reply:(void(^)(BOOL))reply;

- (void)getSourceFixesFromError:(ErrorToken)error reply:(void(^)(NSArray<SourceFixToken> *))reply;
- (void)copyContextualDescriptionsInSource:(NSString *)source fromFixes:(NSArray<SourceFixToken> *)fix reply:(void(^)(NSArray<NSString*> *))reply;
- (void)copySimpleDescriptionsInSource:(NSString *)source fromFixes:(NSArray<SourceFixToken> *)fix reply:(void(^)(NSArray<NSString*> *))reply;
- (void)applyFix:(SourceFixToken)fix toSource:(NSString *)source reply:(void(^)(NSString *_Nullable))reply;

@end

NS_ASSUME_NONNULL_END
