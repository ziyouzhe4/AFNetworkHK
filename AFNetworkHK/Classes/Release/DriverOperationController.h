//
//  DriverOperationController.h
//  DiSpecialDriver
//
//  Created by huji on 21/4/15.
//  Copyright (c) 2015 huji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <DPlatform_Model/DSDriver.h>
#import "UNINotifyDriverStatusTextParamsModel.h"

@class ListenModel, UNIDriverStatusModel;

@protocol DriverOperationControllerViewDelegate <NSObject>

@required
- (void)loadViews;
- (void)unloadViews;
- (void)setViewForOnlineStatus:(BOOL)isOn;
- (void)updateAnimateText:(NSString *)text;
- (void)updateListenState:(NSNumber *)state textParams:(UNINotifyDriverStatusTextParamsModel *)textParams color:(UIColor *)color;
- (BOOL)stateShowOnScreen;
- (void)showModeSettingUI;

@optional
// global回调 非必须
- (void)startSetOnlineStatus:(DriverOnlineStatus)toStatus;
- (void)endSetOnlineStatus:(DriverOnlineStatus)status result:(BOOL)result;
- (void)didFetchListenModeData:(id)responseObject;
- (void)didSetListenModelFrom:(ListenModel *)originalModel to:(ListenModel *)model;

- (void)driverOperationController:(id)controller didUpdateStatusModel:(UNIDriverStatusModel *)statusModel;
@end

/*
 首页收出车逻辑观察者
 */
@interface DriverOperationStateObserver : NSObject

@property (nonatomic, copy) NSString *key;
@property (nonatomic, weak) UIViewController<DriverOperationControllerViewDelegate> *delegate;

@end

typedef void(^DriverOperationBlock)(BOOL success);

/**
 * An abstract view layer for bottom buttons
 */
@interface DriverOperationController : NSObject
@property (nonatomic, weak) UIViewController<DriverOperationControllerViewDelegate> *showOnScreenDelegate;
@property (nonatomic, strong) NSMutableArray<DriverOperationStateObserver *> *delegates;

+ (instancetype)sharedInstance;

- (void)loadViews;
- (void)unloadViews;

- (void)addDriverOperationStateObserver:(DriverOperationStateObserver *)observer;
- (void)removeDriverOperationStateObserverForKey:(NSString *)key;

/**
 *  @abstract 出车接口
 *
 *  @param force 不判断是否已经出车，强制调用setOnlineStatus
 *  @param isShowLoading 是否在window上显示loading
 *  @param block 请求成功后的回调，会在处理完本层的内部逻辑之后调用
 */
- (void)goInRunningIfForce:(BOOL)force showLoding:(BOOL)isShowLoading complete:(DriverOperationBlock)block;

/**
 *  @call [self goInRunningIfForce:force showLoding:YES complete:block]
 */
- (void)goInRunningIfForce:(BOOL)force complete:(DriverOperationBlock)block;


/**
 *  @abstract 收车接口
 *
 *  @param force 不判断是否已经收车，强制调用setOnlineStatus
 *  @param isShowLoading 是否在window上显示loading
 *  @param block 请求成功后的回调，会在处理完本层的内部逻辑之后调用
 */
- (void)goOffRunningIfForce:(BOOL)force showLaoding:(BOOL)isShowLoading complete:(DriverOperationBlock)block;

/**
 *  @call [self goOffRunningIfForce:force showLaoding:YES complete:block]
 */
- (void)goOffRunningIfForce:(BOOL)force complete:(DriverOperationBlock)block;

/**
 *  @abstract 清空顺路目的地
 *@param isCheck 是否需要校验当前距离与目的地距离
 *  @param block 请求成功后的回调，会在处理完本层的内部逻辑之后调用
 */
-(void)clearDestinationWithCheck:(BOOL)isCheck complete:(DriverOperationBlock)block;

- (void)leftFloatClick;
- (void)chucheClick;


- (void)chucheClickWithCompletion:(DriverOperationBlock)completion;

- (void)readyToServeWithExtendParams:(NSDictionary *)params failure:(dispatch_block_t)failure success:(dispatch_block_t)success;
@end
