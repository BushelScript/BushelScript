#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef id LanguageModuleToken;
typedef id ProgramToken;
typedef id ExpressionToken;
typedef id RTObjectToken;
typedef id ErrorToken;
typedef id SourceFixToken;

@protocol BushelLanguageServiceProtocol <NSObject>

- (void)loadLanguageModuleWithIdentifier:(NSString *)moduleIdentifier reply:(void (^)(_Nullable LanguageModuleToken))reply;
- (void)unloadLanguageModule:(LanguageModuleToken)module reply:(void(^)(BOOL))reply;

- (void)parseSource:(NSString *)source atURL:(NSURL *_Nullable)url usingLanguageModule:(LanguageModuleToken)module reply:(void (^)(_Nullable ProgramToken, _Nullable ErrorToken))reply;
- (void)releaseProgram:(ProgramToken)program reply:(void(^)(BOOL))reply;

- (void)highlightProgram:(ProgramToken)program reply:(void(^)(NSData *_Nullable /* NSAttributedString rtf data */))reply;
- (void)prettyPrintProgram:(ProgramToken)program reply:(void(^)(NSString *_Nullable))reply;
- (void)reformatProgram:(ProgramToken)program usingLanguageModule:(LanguageModuleToken)module reply:(void(^)(NSString *_Nullable))reply;

- (void)getExpressionAtLocation:(NSInteger)index inSourceOfProgram:(ProgramToken)program reply:(void(^)(_Nullable ExpressionToken))reply;

- (void)copyKindNameForExpression:(ExpressionToken)expression reply:(void(^)(NSString *_Nullable))reply;
- (void)copyKindDescriptionForExpression:(ExpressionToken)expression reply:(void(^)(NSString *_Nullable))reply;
- (void)releaseExpression:(ExpressionToken)expression reply:(void(^)(BOOL))reply;

- (void)runProgram:(ProgramToken)program scriptName:(NSString *_Nullable)scriptName currentApplicationID:(NSString *_Nullable)currentApplicationID reply:(void(^)(_Nullable RTObjectToken, _Nullable ErrorToken))reply;

- (void)copyDescriptionForObject:(RTObjectToken)object reply:(void(^)(NSString *_Nullable))reply;

- (void)copyNSErrorFromError:(ErrorToken)error reply:(void(^)(NSError *))reply;
- (void)releaseError:(ErrorToken)error reply:(void(^)(BOOL))reply;

- (void)copyLineRangeFromError:(ErrorToken)error forSource:(NSString *)source reply:(void(^)(NSValue *_Nullable))reply;
- (void)copyColumnRangeFromError:(ErrorToken)error forSource:(NSString *)source reply:(void(^)(NSValue *_Nullable))reply;
- (void)copySourceCharacterRangeFromError:(ErrorToken)error forSource:(NSString *)source reply:(void(^)(NSValue *_Nullable))reply;

- (void)getSourceFixesFromError:(ErrorToken)error reply:(void(^)(NSArray<SourceFixToken> *))reply;
- (void)copyContextualDescriptionsInSource:(NSString *)source fromFixes:(NSArray<SourceFixToken> *)fix reply:(void(^)(NSArray<NSString*> *))reply;
- (void)copySimpleDescriptionsInSource:(NSString *)source fromFixes:(NSArray<SourceFixToken> *)fix reply:(void(^)(NSArray<NSString*> *))reply;
- (void)applyFix:(SourceFixToken)fix toSource:(NSString *)source reply:(void(^)(NSString *_Nullable))reply;

@end

NS_ASSUME_NONNULL_END
