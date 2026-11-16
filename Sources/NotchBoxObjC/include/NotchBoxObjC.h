#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Runs `block` and hands back the Objective-C exception it raised, or nil.
///
/// Swift cannot catch one by itself, and one that nobody catches ends the app. The camera frameworks
/// raise them for things that depend on the Mac at hand (a picture size its camera cannot deliver), so
/// what NotchBox asks of the camera is asked through this.
FOUNDATION_EXPORT NSException *_Nullable NBCatchException(NS_NOESCAPE void (^block)(void));

NS_ASSUME_NONNULL_END
