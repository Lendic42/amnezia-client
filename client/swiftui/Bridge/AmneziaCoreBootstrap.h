#import <Foundation/Foundation.h>

@class AmneziaCoreBridge;

NS_ASSUME_NONNULL_BEGIN

@interface AmneziaCoreBootstrap : NSObject

+ (nullable AmneziaCoreBridge *)createBridge;

@end

NS_ASSUME_NONNULL_END
