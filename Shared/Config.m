//
//  Config.m
//  wwWallet
//
//  Created by Benjamin Erhart on 29.05.25.
//

#import "Config.h"
#import <TargetConditionals.h>

#define MACRO_STRING_(m) #m
#define MACRO_STRING(m) @MACRO_STRING_(m)

@implementation Config

+ (NSString *) extBundleId {
    return MACRO_STRING(EXT_BUNDLE_ID);
}

+ (NSString *) groupId {
    return MACRO_STRING(APP_GROUP);
}

@end
