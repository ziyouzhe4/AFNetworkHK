//
//  AFViewController.m
//  AFNetworkHK
//
//  Created by majianjie on 11/05/2022.
//  Copyright (c) 2022 majianjie. All rights reserved.
//

#import "AFViewController.h"
#import "Test.h"

@interface AFViewController ()

@end

@implementation AFViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    Test *t = [[Test alloc] init];
    [t eat];
    
}

@end
