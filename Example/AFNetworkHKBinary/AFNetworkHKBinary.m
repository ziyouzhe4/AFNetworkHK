//
//  AFNetworkHKBinary.m
//  AFNetworkHKBinary
//
//  Created by majianjie on 2022/11/15.
//  Copyright © 2022 majianjie. All rights reserved.
//

#import "AFNetworkHKBinary.h"

@implementation AFNetworkHKBinary

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self test];
    }
    return self;
}

- (void)test{
    NSLog(@"%s",__func__);
}

@end
