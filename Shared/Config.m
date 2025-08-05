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

+ (NSString *) groupId {
    return MACRO_STRING(APP_GROUP);
}

+ (NSString *) baseDomain1 {
    return MACRO_STRING(BASE_DOMAIN1);
}

+ (NSString *) baseDomain2 {
    return MACRO_STRING(BASE_DOMAIN2);
}

+ (NSString *) baseDomain3 {
    return MACRO_STRING(BASE_DOMAIN3);
}

@end
