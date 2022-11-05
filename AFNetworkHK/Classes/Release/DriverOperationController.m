//
//  DriverOperationController.m
//  DiSpecialDriver
//
//  Created by huji on 21/4/15.
//  Copyright (c) 2015 huji. All rights reserved.
//

#import "DriverOperationController.h"
#import <DComponent_LongLink/DSRequest.h>
#import <DPlatform_Network/DSHTTPParamsBuilder.h>
#import <DPlatform_Network/DSHTTPRequestOperationManager.h>
#import <DPlatform_Model/ListenModel.h>
#import <DPlatform_URLManager/DSUrls.h>
#import <DSUIComponents/DSToastUtils.h>
#import <DPlatform_Model/DSDriver.h>
#import <DComponent_Audio/DSAudioService.h>
#import <DComponent_Common/UIView+Convenient.h>
#import <DSUIComponents/DSAlertView.h>
#import <DSUIComponents/MBProgressHUD+UNI.h>
#import <DComponent_Common/DSConfig.h>
#import <DComponent_Common/DSCommonConstant.h>
#import <DComponent_Tools/ExcuteTimesCache.h>
#import <DPlatform_OrderFilter/DSOrderFilter.h>
#import <DComponent_Common/UIButton+CommonAppearane.h>
#import <DComponent_Common/UIImage+FileName.h>
#import <DBusiness/DSAppUpdateManager.h>
#import <DComponent_Location/DSLocationManager.h>
#import <DSBuriedPoint/StatisticsUtil.h>
#import <DComponent_Web/DSWebViewController.h>
#import <DPlatform_ServerConfig/DSServerConfig.h>
#import <DComponent_OpenCenter/OpenCenter.h>
#import <libextobjc/EXTScope.h>
#import <DPlatform_PushConnector/UNIPushConnectorNotifications.h>
#import <DComponent_Audio/DDAudio.h>
#import <DComponent_Common/NSString+HighlightBraceContent.h>
#import <DComponent_Common/UNIModeSettingNotificationKeys.h>
#import "UNIInterveneModel.h"
#import <DComponent_Map/DSJSInnerNavigationViewController.h>
#import <DComponent_OpenEnv/OpenEnv.h>
#import <DComponent_Common/OpenEnvKeys.h>
#import <DComponent_DSPriorityNotification/DSPriorityNotification.h>
#import <DComponent_Common/RecvMsgNotificationKeys.h>
#import <DPlatform_RecordEvidence/DSRecordPermissionModule.h>
#import <DPlatform_Model/UNIfaceRecognizeModel.h>
#import <ApolloSDK/ApolloSDK.h>
#import "UNIModeSettingController.h"
#import <DSUIComponents/UNIAlertView.h>
#import <SDWebImage/UIImageView+WebCache.h>
#import "UNINewInterveneModel.h"
//#import <DMKFLPInfoCollect/DDMFLPCollectAdapter.h>
#import <DPlatform_NewServingBusiness/UNIExceptionalBoard.h>
#import <DComponent_Web/DSWebContainer.h>
#import <DPlatform_Model/UNIDriverStatusModel.h>
#import <ONEUIKit/UIColor+ONEExtends.h>
#import <DComponent_Common/DSUIConstraints.h>
#import <ApolloSDK/ApolloSDKManager.h>
#import <DComponent_Map/UNIMapManager.h>
#import <DBusiness/UNIXSwitchEditionCenter.h>
#import <DPlatform_Login/DSLoginManager.h>
#import <DComponent_OpenEnv/OpenEnv.h>
#import <DComponent_Common/OpenEnvKeys.h>
#import <DComponent_Common/OfflineScene.h>
#import <DPlatform_NewServingBusiness/DServingKeys.h>
#import <DPlatform_NewServingBusiness/UNIOrderCompleteDetailModel.h>
#import <DBusiness/DriverApiCommandCenter.h>
#import <DBusiness/UNITaxiPrinterManager.h>
#import <ONEFoundation/NSDictionary+ONEExtends.h>
#import <AVFoundation/AVCaptureDevice.h>
#import <DSBuriedPoint/UNITrackEventsCenter.h>
#import <GreatWall/GreatWall.h>

@interface DSAlertConfigModel : JSONModel
@property (nonatomic, copy) NSString<Optional> *btn_left;
@property (nonatomic, copy) NSString<Optional> *left_url;
@property (nonatomic, copy) NSString<Optional> *btn_right;
@property (nonatomic, copy) NSString<Optional> *right_url;
@property (nonatomic, copy) NSString *msg;
@end

@implementation DSAlertConfigModel

@end

@implementation DriverOperationStateObserver

@end

@interface DriverOperationController ()

@property (nonatomic,strong) DSURLSessionDataTask *getLisModelRequest;
@property (nonatomic,assign) BOOL isOffRunningIntervene;
@property (nonatomic,assign) BOOL newAlertToggle;
@property (nonatomic,strong) UNIAlertView *halfAlertView;
@property (nonatomic,strong) NSTimer *queryTimer;
@end

static DriverOperationController *_sharedInstance = nil;

@implementation DriverOperationController

+ (instancetype)sharedInstance {
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        _sharedInstance = [[DriverOperationController alloc] init];
    });
    return _sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.delegates = [NSMutableArray new];
        UNIXEditionStateObsever *editionObserver = [[UNIXEditionStateObsever alloc] init];
        editionObserver.key = NSStringFromClass([self class]);
        editionObserver.callBack = ^(UNIXEdition state) {
            if ([[DSLoginManager manager] isLogin]) {
                [[DriverOperationController sharedInstance] loadViews];
            }
        };
        [[UNIXSwitchEditionCenter editionCenter] addStateChangedCallBacks:editionObserver];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(goOffRunning:) name:DSShouCheNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(goInRunningIfNot) name:DSChuCheNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getListenMode) name:DSGetListenModeNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogin) name:DSDidLogInNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willLogout) name:DSWillLogOutNotification object:nil];
    }
    _isOffRunningIntervene = NO;
    
    APOExperiment * alertExperiment = [ApolloSDKManager experimentWithName:@"driver_onlineStatus_toggle" withDefaultBool:NO];
    _newAlertToggle = alertExperiment.enabled;
    return self;
}

- (void)dealloc{
    [self.queryTimer invalidate];
    self.queryTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addDriverOperationStateObserver:(DriverOperationStateObserver *)observer {
    if (observer && observer.key && observer.delegate) {
        __block BOOL same = NO;
        [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.key == observer.key) {
                same = YES;
            }
        }];
        if (!same) {
            [self.delegates addObject:observer];
            [[UNIModeSettingController sharedInstance].delegates addObject:observer];
        }
        
    }
}

- (void)removeDriverOperationStateObserverForKey:(NSString *)key {
    __block NSInteger index = 0;
    [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.key == key) {
            index = idx;
        }
    }];
    if (index <= self.delegates.count - 1) {
        [self.delegates removeObjectAtIndex:index];
    }
}


#pragma mark - public UI
- (void)loadViews{
    [[UNIModeSettingController sharedInstance] loadViews];
    [[DSLocationManager manager] addFirstLocationLoadBlock:^(CLLocation *location) {
        DSLogInfo(@"Will get listen mode and online status.");
        // 获取出收车状态
        [self getOnlineStatus];
    }];
}

- (void)unloadViews{
    [[UNIModeSettingController sharedInstance] unloadViews];
}

#pragma mark - private

- (void)setViewForOnlineStatus:(DriverOnlineStatus)onlineStatus {
    if (onlineStatus == DriverOnlineStatusOffRunning) {
        [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.delegate && [obj.delegate respondsToSelector:@selector(setViewForOnlineStatus:)]) {
                [obj.delegate setViewForOnlineStatus:NO];
            }
        }];
    } else {
        [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.delegate && [obj.delegate respondsToSelector:@selector(setViewForOnlineStatus:)]) {
                [obj.delegate setViewForOnlineStatus:YES];
            }
        }];
    }
}

- (void)leftFloatClick {
    [[UNIModeSettingController sharedInstance] leftFloatClick];
}

- (void)chucheClick {
    [self chucheClickWithCompletion:nil];
}

- (void)chucheClickWithCompletion:(DriverOperationBlock)completion {
    BOOL result = [[DSLocationManager manager] checkIsLocationFullAccuracy:YES];
    if (result) {
        [self setOnineStatus:DriverOnlineStatusInRunning complete:completion];
    }
    else {
        DSLogInfo(@"定位权限或者精确定位没有打开，不能出车");
        if (completion) {
            completion(NO);
        }
    }
}

- (void)readyToServeWithExtendParams:(NSDictionary *)params failure:(dispatch_block_t)failure success:(dispatch_block_t)success {
    BOOL result = [[DSLocationManager manager] checkIsLocationFullAccuracy:YES];
    if (!result) {
        !failure ?: failure();
        return;
    }
    
    NSMutableDictionary *mutableParams = [NSMutableDictionary dictionaryWithDictionary:params];
    [mutableParams setValue:@0 forKey:@"GoOffRunningShowLoadingParamKey"]; // 不展示loading
    
    [self setOnineStatus:DriverOnlineStatusInRunning isNeedBlock:YES withNotiParams:mutableParams.copy beforeInterceptor:failure complete:^(BOOL suc) {
        if (suc) {
            !success ?: success();
        }
    }];
}


- (void)goInRunning {
    [self setOnineStatus:DriverOnlineStatusInRunning];
}

- (void)goOffRunning:(NSNotification *)noti {
    NSDictionary *notiParams = nil;
//    BOOL isShowLoading = YES;
//    int forceOfflineScene = 0;
    if (noti != nil) {
        if (noti.object && [noti.object isKindOfClass:[NSDictionary class]]) {
            notiParams = noti.object;
//            _isOffRunningIntervene = [noti.object objectForKey:@"isOffRunningIntervene"];
//            // 后加参数，如果外面没有传这个参数，则不影响原有逻辑
//            NSNumber *showLoadingNumber = [noti.object objectForKey:@"GoOffRunningShowLoadingParamKey"];
//            if (showLoadingNumber) {
//                isShowLoading = [showLoadingNumber boolValue];
//            }
//            // 是否人脸识别失败导致强制收车场景
//            NSNumber *forceOfflineSceneNum = [noti.object objectForKey:@"force_offline_scene"];
//            if (forceOfflineSceneNum) {
//                forceOfflineScene = [forceOfflineSceneNum intValue];
//            }
        }
    }
    /* http://omega.xiaojukeji.com/app/quality/crash/detail?app_id=6#?msgid=47D5E33B-A9DA-472B-B0ED-B31D2BAF6CD0&server_time=1590377073008&err_tag_title=%2B%5BMBProgressHUD%20showHUDAddedTo%3Aanimated%3A%5D%09MBProgressHUD.m%3A118&begin_time=1589817600000&end_time=1590382800000&func_enum=1&version_num=5.3.14.2005151439
        5.3.14 因子线程中实现 导致UI布局时 crash ，增加线程判定5.3.16修复
     */
    APOExperiment *experiment = [ApolloSDKManager experimentWithName:@"driver_iOS_operation_goOffRunning" withDefaultBool:NO];
    if (experiment.enabled) {
        DSLogInfo(@"goOffRunning enabled yes");
        if ([NSThread isMainThread]) {
            [self setOnineStatus:DriverOnlineStatusOffRunning isNeedBlock:0 withNotiParams:notiParams complete:nil];
        }else{
            DSLogInfo(@"goOffRunning enabled dispatch_async");
            dispatch_async(dispatch_get_main_queue(), ^{
                [self setOnineStatus:DriverOnlineStatusOffRunning isNeedBlock:0 withNotiParams:notiParams complete:nil];
            });
        }
    }else{
        DSLogInfo(@"goOffRunning nomal enabled no");
        [self setOnineStatus:DriverOnlineStatusOffRunning isNeedBlock:0 withNotiParams:notiParams complete:nil];
    }
}

#pragma mark - public 出车 收车 模式设置

- (void)goInRunningIfForce:(BOOL)force complete:(DriverOperationBlock)block {
    [self goInRunningIfForce:force showLoding:YES complete:block];
}

- (void)goInRunningIfForce:(BOOL)force showLoding:(BOOL)isShowLoading complete:(DriverOperationBlock)block {
    if (force || [DSDriver currentDriver].is_online == DriverOnlineStatusOffRunning) {
        [self setOnineStatus:DriverOnlineStatusInRunning isNeedBlock:0 withNotiParams:@{@"GoOffRunningShowLoadingParamKey":[NSNumber numberWithBool:isShowLoading]} complete:block];
        DSLogInfo(@"DriverOperationController goInRunningIfForce.");
    }
    else {
        if (block) block(NO);
        DSLogWarn(@"The online status is already in running.");
    }
}

- (void)goOffRunningIfForce:(BOOL)force complete:(DriverOperationBlock)block {
    [self goOffRunningIfForce:force showLaoding:YES complete:block];
}

- (void)goOffRunningIfForce:(BOOL)force showLaoding:(BOOL)isShowLoading complete:(DriverOperationBlock)block {
    if (force || [DSDriver currentDriver].is_online == DriverOnlineStatusInRunning) {
        [self setOnineStatus:DriverOnlineStatusOffRunning isNeedBlock:0 withNotiParams:@{@"GoOffRunningShowLoadingParamKey":[NSNumber numberWithBool:isShowLoading]} complete:block];
        DSLogInfo(@"DriverOperationController goOffRunningIfForce.");
    }
    else {
        if (block) block(NO);
        DSLogWarn(@"The online status is already off running.");
    }
}

-(void)clearDestinationWithCheck:(BOOL)isCheck complete:(DriverOperationBlock)block {
    [[UNIModeSettingController sharedInstance] clearDestinationWithCheck:isCheck complete:block];
}

#pragma mark - Notifications
- (void)goInRunningIfNot{
    if ([DSDriver currentDriver].is_online == DriverOnlineStatusOffRunning) {
        /// 如果没有定位权限 不让出车
        BOOL result = [[DSLocationManager manager] checkIsLocationFullAccuracy:YES];
        if(result){
            [self setOnineStatus:DriverOnlineStatusInRunning isNeedBlock:0 withNotiParams:nil  complete:nil];
        }
    }
}

//- (void)microTips{
//    
//    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
//        DSAlertView * alerView = [[DSAlertView alloc]initWithTitle:DSYSAudioExcuse message:@"设置开启麦克风权限后可以出车接单，禁用麦克风会导致无法出车"];
//        [alerView addButtonWithTitle:@"取消" type:DSAlertViewButtonDefault];
//        [alerView addButtonWithTitle:@"去设置" type:DSAlertViewButtonCancel];
//        
//        [alerView setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
//            if (buttonIndex == 1) {
//                DSLogInfo(@"点击了去设置");
//                [StatisticsUtil driver_chuche_microphone_ck:@"set"];
//                [DSRecordPermissionModule jumpToAppSetting];
//            }
//            else{
//                [StatisticsUtil driver_chuche_microphone_ck:@"cancel"];
//            }
//        }];
//        [alerView show];
//    });
//    
//}

#pragma mark - 出车收车相关 dGetOnlineStatus dSetOnlineStatus

- (void)getOnlineStatus {
    [[DSOrderFilter filter] addFilter:DSOrderFilterKey_iGnore];
    
    //MBProgressHUD *loadingHUD = [MBProgressHUD uni_showHUDAddedTo:[[UIApplication sharedApplication].delegate window].rootViewController.view animated:YES];
    NSString *url = [NSString stringWithFormat:@"%@dGetOnlineStatus",DS_BASE_URL];
    DSHTTPParamsBuilder *builder = [DSHTTPParamsBuilder builder];
    NSDictionary *params = [builder build];
    
    DSHTTPRequestOperationManager *manager = [DSHTTPRequestOperationManager manager];
    
    
    [manager POST:url parameters:params success:^(DSURLSessionDataTask *operation, id responseObject) {
        // 必须remove！！
        [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
        
        //[loadingHUD hide:YES];
        
        NSNumber * record_permission = [responseObject objectForKey:@"is_record_permission"];
        if (record_permission) {
            [DSDriver currentDriver].is_record_permission = record_permission;
            [DSDriver synchronize];
            DSLogInfo(@"服务器返回is_record_permission值为：%@",record_permission);
        }
        else{
            DSLogInfo(@"服务器未返is_record_permission");
        }
        NSNumber *derrno = [responseObject objectForKey:@"errno"];
        if (derrno && derrno.integerValue == 0) {
            [DSDriver currentDriver].is_online = ((NSNumber *)[responseObject objectForKey:@"is_online"]).integerValue;
            [DSDriver synchronize];
            
            if([DSDriver currentDriver].is_online == DriverOnlineStatusInRunning){
                OpenCenterEventMark(@"DriverOnlineStatusRunning", nil, @"监测出车状态", nil);
            }
            else if([DSDriver currentDriver].is_online == DriverOnlineStatusOffRunning){
                OpenCenterEventMark(@"DriverOnlineStatusOffRunning", nil, @"监测收车状态", nil);
            }
        }
        else if (derrno.integerValue == 2112){
            // ticket失效  添加登录退出时的原因 短链鉴权失败导致登出（短链请求鉴权失败）
            NSDictionary *notiDict = @{@"signOffReason": @"5", @"message": @"登录失效，请重新登录"};
            [[NSNotificationCenter defaultCenter] postNotificationName:DSExitNotification object:notiDict];
            DSLogWarn(@"dGetOnlineStatus ticket invalid.");
            
            [DSDriver currentDriver].is_online = DriverOnlineStatusOffRunning;
        }
        else {
            NSString *errmsg = [responseObject objectForKey:@"errmsg"];
            if (!errmsg.length) {
                errmsg = @"网络错误\n请稍后再试";
            }
            if (self.newAlertToggle) {
                UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:errmsg];
                [alert addActionButtonWithTitle:@"确定" andButtonType:UNIAlertViewButtonHighlight];
                [alert show];
            }
            else{
                DSAlertView *alert = [[DSAlertView alloc]initWithTitle:errmsg];
                [alert addButtonWithTitle:@"确定"];
                [alert show];
            }
            DSLogError(@"dGetOnlineStatus errno %@, errmsg %@", derrno, errmsg);
            
            [DSDriver currentDriver].is_online = DriverOnlineStatusOffRunning;
        }
        
        OpenCenterEventMark(@"GetOnlineStatus", nil, @"获取online状态", @"nil");
        [self onlineStatusChanged:[DSDriver currentDriver].is_online ifPlayAudio:NO response:nil];
        
    } failure:^(DSURLSessionDataTask *operation, NSError *error) {
        // 必须remove！！
        [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
        
        //[loadingHUD hide:YES];
        DSLogError(@"dGetOnlineStatus failed, get again.");
        [DSToastUtils showToast:@"网络异常，获取出收车状态失败。"];
        
        
        [DSDriver currentDriver].is_online = DriverOnlineStatusOffRunning;
        [self onlineStatusChanged:[DSDriver currentDriver].is_online ifPlayAudio:NO response:nil];
    }];
}

- (void)setOnineStatus:(DriverOnlineStatus)is_online {
    [self setOnineStatus:is_online complete:nil];
}

- (void)setOnineStatus:(DriverOnlineStatus)is_online complete:(DriverOperationBlock)complete {
    BOOL isNeedBlock = 0;
    if (is_online == DriverOnlineStatusInRunning) {
        isNeedBlock = 1;
    }
    [self setOnineStatus:is_online isNeedBlock:isNeedBlock withNotiParams:nil complete:complete];
}

- (void)setOnineStatus:(DriverOnlineStatus)is_online isNeedBlock:(NSInteger)isNeedBlock withNotiParams:(NSDictionary *)notiParams complete:(DriverOperationBlock)complete {
    [self setOnineStatus:is_online isNeedBlock:isNeedBlock withNotiParams:notiParams beforeInterceptor:nil complete:complete];
}

- (void)setOnineStatus:(DriverOnlineStatus)is_online isNeedBlock:(NSInteger)isNeedBlock withNotiParams:(NSDictionary *)notiParams beforeInterceptor:(dispatch_block_t)before complete:(DriverOperationBlock)complete {
    [[DSOrderFilter filter] addFilter:DSOrderFilterKey_iGnore];
    
    NSNumber *isOffRunningIntervene = [notiParams objectForKey:@"isOffRunningIntervene"];
    if ([isOffRunningIntervene isKindOfClass:[NSNumber class]]) {
        _isOffRunningIntervene = isOffRunningIntervene.boolValue;
    } else {
        _isOffRunningIntervene = NO;
    }
    
    // 后加参数，如果外面没有传这个参数，则不影响原有逻辑
    BOOL isShowLoading = YES;
    NSNumber *showLoadingNumber = [notiParams objectForKey:@"GoOffRunningShowLoadingParamKey"];
    if ([showLoadingNumber isKindOfClass:[NSNumber class]]) {
        isShowLoading = [showLoadingNumber boolValue];
    }
    int forceOfflineScene = 0;
    // 是否人脸识别失败导致强制收车场景
    NSNumber *forceOfflineSceneNum = [notiParams objectForKey:@"force_offline_scene"];
    if ([forceOfflineSceneNum isKindOfClass:[NSNumber class]]) {
        forceOfflineScene = [forceOfflineSceneNum intValue];
    }
    
    //是否是主动收车:1是被动收车，0是主动收车
    int isAuto = 1;
    NSNumber *isAutoNum = [notiParams objectForKey:@"isAuto"];
    if([isAutoNum isKindOfClass:[NSNumber class]]){
        isAuto = [isAutoNum intValue];
    }
    
    
    NSNumber *event_type = nil;//收车场景梳理新增字段
    //四类收车大场景分类 1.端上发起 2.DMC消息触发 3.接口返回收车 4.H5通过bridge发起收车
    //小场景见http://wiki.intra.xiaojukeji.com/pages/viewpage.action?pageId=289156786
    //通知中传递参数逻辑：小场景发通知key为OfflineSceneKey,大场景发通知key为OfflineMainSceneKey
    //接口请求参数获取逻辑：优先获取小场景、其次大场景、最后默认type兜底
    NSNumber *eventTypeFromNotiParam = [notiParams objectForKey:OfflineSceneKey];
    NSNumber *eventMainTypeFromNotiParam = [notiParams objectForKey:OfflineMainSceneKey];
    if ([eventTypeFromNotiParam isKindOfClass:[NSNumber class]] && eventTypeFromNotiParam.integerValue > 0) {
        event_type = eventTypeFromNotiParam;
    } else if ([eventMainTypeFromNotiParam isKindOfClass:[NSNumber class]] && eventMainTypeFromNotiParam.integerValue > 0) {
        event_type = eventMainTypeFromNotiParam;
    } else {
        event_type = @(OfflineMainSceneType_UnknownOthers);
    }
    
    __block MBProgressHUD *loadingHUD = nil;
    if (isShowLoading) {
        dispatch_block_t loadHudBlock = ^() {
            loadingHUD = [MBProgressHUD uni_showHUDAddedTo:[[UIApplication sharedApplication].delegate window] animated:YES];
        };
        if (![NSThread isMainThread]) {
            dispatch_async(dispatch_get_main_queue(), loadHudBlock);
        } else {
            loadHudBlock();
        }
    }
    
    NSString *url = [NSString stringWithFormat:@"%@dSetOnlineStatus",DS_BASE_URL];
    DSHTTPParamsBuilder *builder = [DSHTTPParamsBuilder builder];
    [builder add:@(is_online) key:@"online_status"];
    [builder add:@(isNeedBlock) key:@"is_need_block"];
    [builder add:@(forceOfflineScene) key:@"force_offline_scene"];
    [builder add:[NSNumber numberWithBool:_isOffRunningIntervene] key:@"operation_type"];
    [builder add:@([DSRecordPermissionModule shareInstance].permission) key:@"mic_status"];
    [builder add:@(isAuto) key:@"is_auto"];
    [builder add:event_type key:@"event_type"];//收车场景需求新增收车场景类型参数
    //上报蓝牙打票机状态
    NSInteger connectedStatus = ([UNITaxiPrinterManager isConnected]) ? 1 : 0;
    [builder add:@(connectedStatus) key:@"bluetooth_print_ticket_status"];
    
    NSDictionary *params = [builder build];
    DSLogInfo(@"dSetOnlineStatus, params:%@", params);
    
    DSHTTPRequestOperationManager *manager = [DSHTTPRequestOperationManager manager];
    manager.randomFailDispatch = YES;
    
    [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.delegate && [obj.delegate respondsToSelector:@selector(startSetOnlineStatus:)]) {
            [obj.delegate startSetOnlineStatus:is_online];
        }
    }];
    __weak DriverOperationController *ws = self;
    [manager POST:url parameters:params success:^(DSURLSessionDataTask *operation, id responseObject) {
        // 必须remove！！
        [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
        ws.isOffRunningIntervene = NO;
        [loadingHUD hide:YES];

        NSNumber *derrno = [responseObject objectForKey:@"errno"];
        [DSPC postNotification:RecvNotificaitionKey_AssistantCheIntention object:derrno];
        if (derrno && derrno.integerValue == 0) {
            
            [DSDriver currentDriver].is_online = is_online;
            [DSDriver synchronize];
            
            if(is_online == DriverOnlineStatusInRunning){
                OpenCenterEventMark(@"DriverOnlineStatusRunning", nil, @"监测出车状态", nil);
                [StatisticsUtil dirver_begin_ck:@"0"];
            }
            else if(is_online == DriverOnlineStatusOffRunning){
                //地图传感器数据采集结束时机 -- 收车成功
//                [[DDMFLPCollectAdapter mainAdapter] flpLocationCollectEvent:FLPCollectStopRecevingOrder];
                OpenCenterEventMark(@"DriverOnlineStatusOffRunning", nil, @"监测收车状态", nil);
                [UNITrackEventsCenter wyc_end_online_ck:@"" cause:@"0" source:@""]; // ios只要上传cause即可
            }
            
            [self onlineStatusChanged:is_online ifPlayAudio:YES response:responseObject];
            
            if(complete) complete(YES);
            [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.delegate && [obj.delegate respondsToSelector:@selector(endSetOnlineStatus:result:)]) {
                       [obj.delegate endSetOnlineStatus:is_online result:YES];
                   }
            }];
            if (forceOfflineScene == 1 && [responseObject objectForKey:@"data"] != nil) {
                DSLogInfo(@"命中出收车接口错误码新结构");
                [self handleNewInterveneStructure:responseObject is_online:is_online];
            }
        } else {
            if (is_online == DriverOnlineStatusInRunning){
                [StatisticsUtil dirver_begin_ck:[NSString stringWithFormat:@"%@", derrno]];
                !before ?: before();
            } else if(is_online == DriverOnlineStatusOffRunning){
                [UNITrackEventsCenter wyc_end_online_ck:@"" cause:[NSString stringWithFormat:@"%@", derrno] source:@""]; // ios只要上传cause即可
            }
            
            if ([responseObject objectForKey:@"data"] != nil) {
                DSLogInfo(@"命中出收车接口错误码新结构");
                [self handleNewInterveneStructure:responseObject is_online:is_online];
            } else if(derrno.integerValue == 2212){
                //收车干预
                DSLogInfo(@"收车时有收车干预，remind_data：%@",responseObject[@"remind_data"]);
                UNIInterveneModel *intervene = [[UNIInterveneModel alloc] initWithDictionary:responseObject[@"remind_data"] error:nil];
                if (intervene.content.length > 0) {
                    DDAudioText(intervene.content, DSVoicePlayerPriorityPushMsg);
                }
                [self offRunningIntervene:intervene];
            } else if (derrno.integerValue == 2112){
                // ticket失效   添加登录退出时的原因 短链鉴权失败导致登出（短链请求鉴权失败）
                NSDictionary *notiDict = @{@"signOffReason": @"5", @"message": @"登录失效，请重新登录"};
                [[NSNotificationCenter defaultCenter] postNotificationName:DSExitNotification object:notiDict];
                DSLogWarn(@"dSetOnlineStatus ticket invalid.");
            } else if (derrno.integerValue == 22222) {
                DSLogInfo(@"dSetOnlineStatus 22222 抢单已达上限");
                if (self.newAlertToggle) {
                    UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:@"今日抢单量已达上限，请先切换指派模式奖励不停歇。" andContent:nil];
                    [alert addActionButtonWithTitle:@"我知道了" andButtonType:UNIAlertViewButtonHighlight];
                    [alert show];
                } else{
                    DSAlertView *alert = [[DSAlertView alloc] initWithTitle:@"今日抢单量已达上限，请先切换指派模式奖励不停歇。" message:nil];
                    [alert addButtonWithTitle:@"我知道了"];
                    [alert show];
                }
            } else if (derrno.integerValue == 22252) {
                // 强制更新
                [DSToastUtils showToast:UNOLocalizedString(@"App需要更新")];
                DSLogInfo(@"dSetOnlineStatus 22252 强制更新");
                [[DSAppUpdateManager manager] fetchAppUpdate];
            } else if (derrno.integerValue == 2181){
                UNIPromptDataModel *prompt = [[UNIPromptDataModel alloc] initWithDictionary:responseObject[@"prompt_data"] error:nil];
                if (prompt.msg.length > 0) {
                    DDAudioText(prompt.msg, DSVoicePlayerPriorityPushMsg);
                }
                DSLogInfo(@"dSetOnlineStatus 2181 半屏弹框 出车干预");
                [self showAlertWithPromptData:prompt andOnlineStatus:is_online complete:complete];
            } else if (derrno.integerValue == 2182){
                DSWebViewController * webView = [[DSWebViewController alloc]init];
                webView.url = [NSURL URLWithString:(NSString *)[responseObject objectForKey:@"prompt_url"]];
                
                [[OPEV getID:OpenEnvKey_NavigationController defaultValue:nil] pushViewController:webView animated:YES];
                
                DSLogWarn(@"法律未授权,弹出法律授权H5");
            } else if (derrno.integerValue == 2188){
                DSLogInfo(@"没有录音权限，首次出车会被阻断，出现系统弹窗，申请权限");
                
                [[DSRecordPermissionModule shareInstance] checkAudioRecorderAuthorizationGrand:^(BOOL isSystem) {
                   
                    DSLogInfo(@"有权限，再次点击出车即可");
                    
                } noPression:^(BOOL isSystem) {
                    
                    if(!isSystem){
                        
                        DSLogInfo(@"没有权限，弹出本地弹窗");
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            DSAlertView * alerView = [[DSAlertView alloc]initWithTitle:DSYSAudioExcuse message:@"设置开启麦克风权限后可以出车接单，禁用麦克风会导致无法出车"];
                            [alerView addButtonWithTitle:@"取消" type:DSAlertViewButtonDefault];
                            [alerView addButtonWithTitle:@"去设置" type:DSAlertViewButtonCancel];

                            [alerView setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
                                if (buttonIndex == 1) {
                                    DSLogInfo(@"点击了去设置");
                                    [StatisticsUtil driver_chuche_microphone_ck:@"set"];
                                    [DSRecordPermissionModule jumpToAppSetting];
                                }
                                else{
                                    [StatisticsUtil driver_chuche_microphone_ck:@"cancel"];
                                }
                            }];
                            [alerView show];
                        });
                        
                    }
                    
                }];

            } else if (derrno.integerValue == 22256 || derrno.integerValue == 5711) {
                // 三证补齐等需求，服务器配置弹框显示
                DSAlertConfigModel *model = [[DSAlertConfigModel alloc] initWithDictionary:responseObject[@"auth_data"] error:nil];
                if (!model) {
                    DSLogError(@"DSAlertConfigModel is nil when set online status.");
                    NSString *errmsg = [responseObject objectForKey:@"errmsg"];
                    UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                    [DSToastUtils showToast:errmsg inView:nav.view];
                }
                else {
                    [self showServerConfigedAlert:model];
                }
            }
            else if (derrno.integerValue == 22261){
                // 人像识别
                NSDictionary *auth_data = responseObject[@"auth_data"];
                NSInteger need_verify = [auth_data[@"need_verify"] integerValue];
                NSString *sessionId = auth_data[@"face_session"];
                if (need_verify == 1) {
                    UNIfaceRecognizeModel *model = [[UNIfaceRecognizeModel alloc] init];
                    model.sessionId = sessionId;
                    model.bizCode = @"80000";
                    OpenCenterEventMark(@"startFaceDetection", model, @"进入人脸识别", nil);
                }else if (need_verify == 0){
                    [DSToastUtils showToast:auth_data[@"msg"]];
                }
            }
            else if (derrno.integerValue == 22254) {
                // 新政需求，没有设置实时目的地或区域不能出车
                if (self.newAlertToggle) {
                    UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:@"设置顺路接单" andContent:[responseObject objectForKey:@"errmsg"]];
                    [alert addActionButtonWithTitle:@"现在设置" andButtonType:UNIAlertViewButtonHighlight];
                    [alert addActionButtonWithTitle:@"稍后" andButtonType:UNIAlertViewButtonDefault];
                    [alert setHandlerBlock:^(NSInteger buttonIndex, InterceptPageModelItem *buttonItem, UNIAlertView *alertView) {
                        if (buttonIndex == 0) {
                            [self leftFloatClick];
                        }
                    }];
                    [alert show];
                }
                else{
                    DSAlertView *alert = [[DSAlertView alloc]initWithTitle:@"设置顺路接单" message:[responseObject objectForKey:@"errmsg"]];
                    [alert addButtonWithTitle:@"稍后" type:DSAlertViewButtonCancel];
                    [alert addButtonWithTitle:@"现在设置"];
                    [alert setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
                        if (buttonIndex == 1) {
                            [self leftFloatClick];
                        }
                    }];
                    [alert show];
                }
               
            }
            else {
                NSString *errmsg = [responseObject objectForKey:@"errmsg"];
                if (!errmsg.length) {
                    errmsg = @"网络错误\n请稍后再试";
                }
                DSAlertView *alert = [[DSAlertView alloc]initWithTitle:errmsg];
                [alert addButtonWithTitle:@"确定"];
                [alert show];
                //p0模块拉齐 22.5.31 不能确定服务端是否下发errmsg 存在crash风险 只打日志
                if (derrno.integerValue == 2003) {
                    DSLogInfo(@"dSetOnlineStatus 2003 账号改派封禁");
                } else if (derrno.integerValue == 22213) {
                    DSLogInfo(@"dSetOnlineStatus 22213 备班司机");
                }
                
                DSLogError(@"dSetOnlineStatus errno %@, errmsg %@", derrno, errmsg);
            }
            
            if(complete) complete(NO);
            [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.delegate && [obj.delegate respondsToSelector:@selector(endSetOnlineStatus:result:)]) {
                       [obj.delegate endSetOnlineStatus:is_online result:NO];
                   }
            }];
        }
    } failure:^(DSURLSessionDataTask *operation, NSError *error) {
        // 必须remove！！
        if(is_online == DriverOnlineStatusInRunning){
            [StatisticsUtil dirver_begin_ck:@"-1"];
            !before ?: before();
        } else if (is_online == DriverOnlineStatusOffRunning) {
            [UNITrackEventsCenter wyc_end_online_ck:@"" cause:@"-1" source:@""];
        }
        [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
        
        [loadingHUD hide:YES];
        DSLogError(@"dSetOnlineStatus request failed");
        [DSToastUtils showToast:(is_online == DriverOnlineStatusOffRunning) ? @"收车失败" : @"出车失败"];
        
        if(complete) complete(NO);
        [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.delegate && [obj.delegate respondsToSelector:@selector(endSetOnlineStatus:result:)]) {
                   [obj.delegate endSetOnlineStatus:is_online result:NO];
               }
        }];
    }];
}

static NSNumber *queryStateConfig = nil;// 启动后是否成功同步了模式设置ListenMode的配置
static int delayTime = 300; //默认延时时间

- (BOOL)canQueryDriverState{
    if (!queryStateConfig) {
        APOExperiment *pollingConfig = [ApolloSDKManager experimentWithName:@"DiDriver_Listen_State_Polling_Config"];
        if (pollingConfig.enabled) {
            queryStateConfig = [NSNumber numberWithBool:YES];
            delayTime = (int)[pollingConfig integerOfParamWithKey:@"delay" defaultValue:300];
        }else{
            queryStateConfig = [NSNumber numberWithBool:NO];
        }
    }
    return queryStateConfig.boolValue;
}

- (void)setDafaultTimeQuery{
    [self setUpQueryDriverStatus:delayTime];
}

-(void)setUpQueryDriverStatus:(int)delay{
        if ([self canQueryDriverState]) {
            if([DSDriver currentDriver].is_online == DriverOnlineStatusOffRunning){
                [self.queryTimer invalidate];
                self.queryTimer = nil;
                return;
            }else if([DSDriver currentDriver].is_online == DriverOnlineStatusInRunning){
                if (self.queryTimer) {
                    [self.queryTimer invalidate];
                    self.queryTimer = nil;
                }
                if ([self.showOnScreenDelegate stateShowOnScreen]) {
                    self.queryTimer =  [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(queryDriverStatus) userInfo:nil repeats:NO];
                }else{
                    self.queryTimer =  [NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(setDafaultTimeQuery) userInfo:nil repeats:NO];
                }
            }
        }
}

-(void)queryDriverStatus{
    if ([DSDriver currentDriver].is_online != DriverOnlineStatusInRunning) return; //未出车状态下，不会拉接口
    NSString *url = [NSString stringWithFormat:@"%@other/dNotifyDriverStatus",DS_BASE_URL_V2];
    DSHTTPParamsBuilder *builder = [DSHTTPParamsBuilder builder];
    [builder add:[UNIXSwitchEditionCenter editionCenter].serverKeyForEnter key:@"xtype"];
    
    DSHTTPRequestOperationManager *manager = [DSHTTPRequestOperationManager manager];
    
    [manager POST:url parameters:[builder build]  success:^(DSURLSessionDataTask *operation, id responseObject) {
        UNIDriverStatusModel *model = [[UNIDriverStatusModel alloc] initWithDictionary:responseObject error:nil];
        
        DSLogInfo(@"dNotifyDriverStatus model:%@",model);
        
        if(model.derrno != nil && model.derrno.integerValue == 0) {
            if(model.data.polling_interval.intValue > 0){
                [self setUpQueryDriverStatus:model.data.polling_interval.intValue];
            }
            if(model.data.listen_order_status){
                UIColor *backColor = [UIColor one_colorWithHexString:model.data.color_value];
                UNINotifyDriverStatusTextParamsModel *textParams = [[UNINotifyDriverStatusTextParamsModel alloc] init];
                textParams.text = (model.data.text.length > 0) ? model.data.text : @"";
                textParams.text_color = (model.data.text_color.length > 0) ? model.data.text_color : @"";
                [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if (obj.delegate && [obj.delegate respondsToSelector:@selector(updateListenState:textParams:color:)]) {
                           [obj.delegate updateListenState:model.data.listen_order_status textParams:textParams color:backColor];
                       }
                }];
            }
            
            //向delegate发送model的更新回调，5.4.0全调度需求增加，用于x版本首页刷新流水
            [self.delegates enumerateObjectsUsingBlock:^(DriverOperationStateObserver * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if (obj.delegate && [obj.delegate respondsToSelector:@selector(driverOperationController:didUpdateStatusModel:)]) {
                    [obj.delegate driverOperationController:self didUpdateStatusModel:model];
                }
            }];
        }else{
            [self setDafaultTimeQuery];
        }
    } failure:^(DSURLSessionDataTask *operation, NSError *error) {
        DSLogInfo(@"查询司机状态网络错误，继续查.");
        [self setDafaultTimeQuery];
    }];
    
}

#pragma mark - new struture intervene
- (void)handleNewInterveneStructure:(id)responseObject is_online:(DriverOnlineStatus)online_status{
    DSLogInfo(@"New Intervene structure:%@",responseObject);
    
    NSString *errmsg = [responseObject objectForKey:@"errmsg"];
    NSNumber *errorno = [responseObject objectForKey:@"errno"];
    UNINewInterveneModel *newInterveneModel = [[UNINewInterveneModel alloc] initWithDictionary:[responseObject objectForKey:@"data"] error:nil];
    
    if (errorno.integerValue == 2212) {
        //[[DSOrderFilter filter] addFilter:DSOrderFilterKey_iGnore];
        DDAudioText(newInterveneModel.hook_info.content, DSVoicePlayerPriorityPushMsg);
    }
    
    //type: //0不拦截，1 dialog(alertview), 2 半屏拦截，3 全屏拦截，4 走interrupt_url 配置直接跳转h5,5 跳转人脸
    //服务端wiki:http://wiki.intra.xiaojukeji.com/pages/viewpage.action?pageId=177345269
    __weak typeof(self) weakSelf = self;
    switch (newInterveneModel.type.integerValue) {
        case 0:
        {
            errmsg = !errmsg.length ? @"网络错误\n请稍后再试" : errmsg;
            DSAlertView *alert = [[DSAlertView alloc]initWithTitle:errmsg];
            [alert addButtonWithTitle:@"确定"];
            [alert show];
        }
            break;
        case 1:
        {
            [self newInterveneLoggging:newInterveneModel.hook_info.page_show_event];
            
            DSAlertView *alert = [[DSAlertView alloc] initWithTitle:newInterveneModel.hook_info.title message:newInterveneModel.hook_info.content];
//            NSInteger btnCount = newInterveneModel.hook_info.button.count > 2 ? 2 : newInterveneModel.hook_info.button.count;
            for (NSInteger i = 0; i < newInterveneModel.hook_info.button.count; i ++) {
                InterceptPageModelItem *btnItem = [newInterveneModel.hook_info.button objectAtIndex:i];
                DSAlertViewButtonType btnType = btnItem.is_highlight ? DSAlertViewButtonDefault : DSAlertViewButtonCancel;
                [alert addButtonWithTitle:btnItem.text type:btnType];
            }
            [alert setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
                if (buttonIndex < newInterveneModel.hook_info.button.count) {
                    InterceptPageModelItem *btnItem = [newInterveneModel.hook_info.button objectAtIndex:buttonIndex];
                    [weakSelf handleOriginCenterAlertIntervene:newInterveneModel clickBtn:btnItem onlineStatus:online_status errNo:errorno];
                } else {
                    DSLogInfo(@"alertview方式拦截方式点击btn下标越界异常!");
                }
            }];
            [alert show];
        }
            break;
        case 2:
        {
            [self newInterveneLoggging:newInterveneModel.hook_info.page_show_event];
            
            UNIAlertViewUIConfigModel *uiConfig = [[UNIAlertViewUIConfigModel alloc] initForDefaultAlertViewConfig];
            uiConfig.buttonDirection = newInterveneModel.hook_info.button_layout.integerValue == 1 ? UNIAlertViewButtonDirectionHorizontal : UNIAlertViewButtonDirectionVertical;
            if(self.halfAlertView){
                [self.halfAlertView hide];
                self.halfAlertView = nil;
            }
            self.halfAlertView = [[UNIAlertView alloc] initWithUIConfigModel:uiConfig andDataModel:newInterveneModel.hook_info];
            [self.halfAlertView configAttributedTitle:[newInterveneModel.hook_info.title highlightBraceContent]];
            [self.halfAlertView configAttributedContent:[newInterveneModel.hook_info.content highlightBraceContent]];
            self.halfAlertView.autoHideAlert = NO;
            [self.halfAlertView setHandlerBlock:^(NSInteger buttonIndex, InterceptPageModelItem *buttonItem, UNIAlertView *alertView) {
                [weakSelf handleHalfScreenIntervene:newInterveneModel clickButtonItem:buttonItem clickButtonIndex:buttonIndex errNo:errorno online_status:online_status];
            }];
            [self.halfAlertView show];
        }
            break;
        case 3:
        {
            [self newInterveneLoggging:newInterveneModel.hook_info.page_show_event];
            
            UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
            [[UNIExceptionalBoard shareInstance] showWithData:newInterveneModel.hook_info withViewController:nav];
            [UNIExceptionalBoard shareInstance].doAction = ^(InterceptPageModelItem *item) {
                [weakSelf handleFullScreenIntervene:newInterveneModel clickBtn:item onlineStatus:online_status errNo:errorno];
            };
        }
            break;
        case 4:
        {
            [DSWebContainer jumpToWebContainerWithUrl:newInterveneModel.other_data.interrupt_url withParams:nil withTitle:nil];
            //[DSSkipCenter jumpToWebView:newInterveneModel.other_data.interrupt_url param:nil];
        }
            break;
        case 5:
        {
            UNIfaceRecognizeModel *model = [[UNIfaceRecognizeModel alloc] init];
            model.sessionId = newInterveneModel.other_data.face_session;
            model.bizCode = newInterveneModel.other_data.biz_code;
            model.check_type = newInterveneModel.other_data.check_type;
            OpenCenterEventMark(@"startFaceDetection", model, @"进入人脸识别", nil);
        }
            break;
        case 6:
        {
            //唤起长城
            [GreatWall setNetType:GreatWallNetTypeNormal];
            NSMutableDictionary *params = @{}.mutableCopy;
            [params one_setValue:newInterveneModel.other_data.great_id forKey:@"greatId"];
            [params one_setValue:DSDriver.currentDriver.ticket forKey:@"token"];
            [GreatWall startGreatWallWithParams:params.copy callback:^(GWCode code, NSDictionary *resDictionay) {
                //code == 0表示流程成功，其他回调参数含义见下方详解
                DSLogInfo(@"Native调用车脸SDK回调结果~~~~~~~%ld~~~~~~%@", code, resDictionay);
            }];
        }
            break;
        default:
        {
            [DSToastUtils showToast:errmsg];
        }
            break;
    }
}

//5.1.58开始埋点数据由服务端下发，下发两个字段埋点名字和埋点参数
- (void)newInterveneLoggging:(InterceptPageLoggingModel *)loggingModel {
    if (loggingModel.logId && ![loggingModel.logId isEqualToString:@""]) {
        NSMutableDictionary * params = nil;
        if (loggingModel.params && [loggingModel.params isKindOfClass:[NSDictionary class]]) {
            params = [NSMutableDictionary dictionaryWithDictionary:loggingModel.params];
        } else {
            params = [NSMutableDictionary dictionary];
        }
        [StatisticsUtil writeEventModel:loggingModel.logId Params:params];
    }
}

//原始中间弹框点击btn后续操作
- (void)handleOriginCenterAlertIntervene:(UNINewInterveneModel *)model clickBtn:(InterceptPageModelItem *)clickBtnModel onlineStatus:(DriverOnlineStatus)onlineStatus errNo:(NSNumber *)errorNo {
    //埋点数据由服务端下发
    [self newInterveneLoggging:clickBtnModel.click_event];
    //老的端上写死的埋点，现在下不掉。。。。
    [self newStrutureIntervenLogging:model clickButtonItem:clickBtnModel errNo:errorNo];
    [self handleInterveneSchemetype:onlineStatus clickButtonItem:clickBtnModel interveneModel:model errorNo:errorNo isHalfScreenIntervene:YES];
}

//全屏干预新结构点击btn后续操作
- (void)handleFullScreenIntervene:(UNINewInterveneModel *)model clickBtn:(InterceptPageModelItem *)clickBtnModel onlineStatus:(DriverOnlineStatus)onlineStatus errNo:(NSNumber *)errorNo {
    //埋点数据由服务端下发
    [self newInterveneLoggging:clickBtnModel.click_event];
    //老的端上写死的埋点，现在下不掉。。。。
    [self newStrutureIntervenLogging:model clickButtonItem:clickBtnModel errNo:errorNo];
    [self handleInterveneSchemetype:onlineStatus clickButtonItem:clickBtnModel interveneModel:model errorNo:errorNo isHalfScreenIntervene:NO];
}

//半屏干预新结构点击btn后续操作
- (void)handleHalfScreenIntervene:(UNINewInterveneModel *)newInterveneModel clickButtonItem:(InterceptPageModelItem *)buttonItem clickButtonIndex:(NSInteger)index errNo:(NSNumber *)errorNo online_status:(DriverOnlineStatus)onlineStatus{
    //埋点数据由服务端下发
    [self newInterveneLoggging:buttonItem.click_event];
    //老的端上写死的埋点，现在下不掉。。。。
    [self newStrutureIntervenLogging:newInterveneModel clickButtonItem:buttonItem errNo:errorNo];
    [self handleInterveneSchemetype:onlineStatus clickButtonItem:buttonItem interveneModel:newInterveneModel errorNo:errorNo isHalfScreenIntervene:YES];
    
    NSInteger btn_type = buttonItem.type.integerValue;//点击btn后弹框是否关闭、继续后续操作还是无操作
    //btn_type:1表示继续并关闭，2表示返回并关闭，3表示不关闭（配合跳转H5、本地页面用的）
    DSLogInfo(@"干预弹框点击的按钮,操作type为:%zd",btn_type);
    switch (btn_type) {
        case 1:
        case 2:
        {
            [self.halfAlertView hide];
        }
            break;
        case 3:
        {
            DSLogInfo(@"干预弹窗点击btn type为3,不做关闭弹窗关闭逻辑");
        }
            break;
        default:
        {
            [self.halfAlertView hide];
        }
            break;
    }
    
}

- (void)handleInterveneSchemetype:(DriverOnlineStatus)onlineStatus clickButtonItem:(InterceptPageModelItem *)buttonItem interveneModel:(UNINewInterveneModel *)newInterveneModel errorNo:(NSNumber *)errorNo isHalfScreenIntervene:(BOOL)isHalfScreenIntervene {
    NSInteger scheme_type = buttonItem.scheme_type.integerValue;//点击btn后调用哪个功能
    
    [self handleExtraOperation:newInterveneModel errorNo:errorNo clickButtonItem:buttonItem];
    
    //全屏拦截在内部处理了点击btn跳转h5逻辑
    if (buttonItem.url && buttonItem.url.length > 0 && isHalfScreenIntervene) {
        scheme_type = -1;
    }
    
    //scheme_type:1 一键报警,2 行程分享,3 仅出车, 4 收车,5 模式设置
    switch (scheme_type) {
        case -1:
        {
            //[DSSkipCenter jumpToWebView:buttonItem.url param:nil];
            [DSWebContainer jumpToWebContainerWithUrl:buttonItem.url withParams:nil withTitle:nil];
        }
            break;
        case 3:
        {
            [self setOnineStatus:DriverOnlineStatusInRunning isNeedBlock:0 withNotiParams:nil complete:nil];
        }
            break;
        case 4:
        {
            //[self setOnineStatus:DriverOnlineStatusOffRunning];
            NSMutableDictionary *param = [NSMutableDictionary dictionary];
            if (buttonItem.key) {
                [param setObject:@(buttonItem.key.integerValue) forKey:OfflineSceneKey];
            }
            [param setObject:@(OfflineMainSceneType_UnknownOthers) forKey:OfflineMainSceneKey];
            [self setOnineStatus:DriverOnlineStatusOffRunning isNeedBlock:0 withNotiParams:param complete:nil];
        }
            break;
        case 5:
        {
            [self leftFloatClick];
        }
            break;
        default:
            break;
    }
}

- (void)handleExtraOperation:(UNINewInterveneModel *)newInterveneModel errorNo:(NSNumber *)errorNo clickButtonItem:(InterceptPageModelItem *)buttonItem {
    switch (errorNo.integerValue) {
        case 2212:
        {
            //[[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
            if (buttonItem.type.integerValue == 2) {
                [self handleShoucheInterveneClickContinueWork:newInterveneModel];
            }
        }
            break;
            
        default:
            break;
    }
}

- (void)handleShoucheInterveneClickContinueWork:(UNINewInterveneModel *)model {
    if(model.other_data.displayType.integerValue == 1){
        //导航到热区
        [StatisticsUtil driver_influback_ck:@"3" interveneName:model.other_data.interveneName];
        DSLogInfo(@"司机接受干预，导航到热区");
        CLLocationDegrees lat = [model.other_data.desLocation.lat doubleValue];
        CLLocationDegrees lng = [model.other_data.desLocation.lng doubleValue];
        CLLocationCoordinate2D to = CLLocationCoordinate2DMake(lat, lng);
        if([[UNIMapManager shareManager] isSelfNaviEnable]){
            [[UNIMapManager shareManager] startNaviation:to scene:4 extraInfo:nil];
        }
        else {
            DSJSInnerNavigationViewController *naviViewController = [[DSJSInnerNavigationViewController alloc] initWithToCoordinate:to andScene:DSInnerNavigationSceneDispatchCard];
            
            UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
            nav.navigationBarHidden = YES;
            [nav pushViewController:naviViewController animated:YES];
        }
    }else if (model.other_data.displayType.integerValue == 2){
        //继续出车
        DSLogInfo(@"司机接受干预，继续出车");
        [StatisticsUtil driver_influback_ck:@"2" interveneName:model.other_data.interveneName];
    }
}

//出车/收车拦截新结构埋点处理
- (void)newStrutureIntervenLogging:(UNINewInterveneModel *)newInterveneModel clickButtonItem:(InterceptPageModelItem *)buttonItem errNo:(NSNumber *)errorNo {
    //buttonItem.type:1表示继续并关闭，2表示返回并关闭，3表示不关闭（配合跳转H5、本地页面用的）
    switch (buttonItem.type.integerValue) {
        case 1:
        {
            switch (errorNo.integerValue) {
                case 2212:
                {
                    [StatisticsUtil driver_influback_ck:@"1" interveneName:newInterveneModel.other_data.interveneName];
                }
                    break;
                case 2181:
                {
                    [StatisticsUtil gulf_d_x_workingblocker_working_ck];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 2:
        {
            switch (errorNo.integerValue) {
                case 2181:
                {
                    [StatisticsUtil gulf_d_x_workblocking_block_ck];
                }
                    break;
                default:
                    break;
            }
        }
            break;
        case 3:
        {
            DSLogInfo(@"目前该项无埋点需求");
        }
            break;
        default:
            break;
    }
}

- (void)showServerConfigedAlert:(DSAlertConfigModel *)model {
    if (!model || model.msg.length == 0) {
        DDLogError(@"wrong alert config model.");
        return;
    }
    
    if (self.newAlertToggle) {
        UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:model.msg];
        [alert configAttributedTitle:[model.msg highlightBraceContent]];
        
        if (model.btn_right.length > 0) {
            [alert addActionButtonWithTitle:model.btn_right andButtonType:UNIAlertViewButtonHighlight];
        }
        if (model.btn_left.length > 0) {
            [alert addActionButtonWithTitle:model.btn_left andButtonType:UNIAlertViewButtonDefault];
        }
        
        [alert setHandlerBlock:^(NSInteger buttonIndex, InterceptPageModelItem *buttonItem, UNIAlertView *alertView) {
            NSString *url;
            
            if (model.btn_left.length > 0 && [buttonItem.text isEqualToString:model.btn_left] && model.left_url.length > 0) {
                url = model.left_url;
            }
            else if (model.btn_right.length > 0 && [buttonItem.text isEqualToString:model.btn_right] && model.right_url.length >0 )
            {
                url = model.right_url;
            }
            else if (model.btn_left.length == 0 && model.btn_right.length > 0 && model.right_url.length > 0){
                url = model.right_url;
            }
            else{
                DSLogInfo(@"no action in this alert");
            }
            
            if (url) {
                DSWebViewController *vc = [[DSWebViewController alloc] init];
                vc.url = [NSURL URLWithString:url];
                UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                nav.navigationBarHidden = YES;
                [nav pushViewController:vc animated:YES];
//                [self.delegate.navigationController pushViewController:vc animated:YES];
            }
        }];
        [alert show];
    }
    else{
        DSAlertView *alert = [[DSAlertView alloc] initWithTitle:model.msg];
        [alert configAttributedTitle:[model.msg highlightBraceContent]];
        
        if (model.btn_left.length > 0) {
            [alert addButtonWithTitle:model.btn_left type:DSAlertViewButtonCancel];
        }
        
        if (model.btn_right.length > 0) {
            [alert addButtonWithTitle:model.btn_right];
        }
        
        [alert setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
            NSString *url;
            if (buttonIndex == 0 && model.btn_left.length > 0 && model.left_url.length > 0) {
                url = model.left_url;
            }
            else if (buttonIndex == 0 &&model.btn_left.length == 0 && model.btn_right.length > 0 && model.right_url.length > 0) {
                url = model.right_url;
            }
            else if (buttonIndex == 1 && model.btn_right.length > 0 && model.right_url.length > 0) {
                url = model.right_url;
            }
            
            if (url) {
                DSWebViewController *vc = [[DSWebViewController alloc] init];
                vc.url = [NSURL URLWithString:url];
                UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                nav.navigationBarHidden = YES;
                [nav pushViewController:vc animated:YES];
//                [self.delegate.navigationController pushViewController:vc animated:YES];
            }
        }];
        [alert show];
    }
    
}

- (void)onlineStatusChanged:(DriverOnlineStatus)onlineStatus ifPlayAudio:(BOOL)ifPlay response:(id)object {
    // 设置UI
    [self setViewForOnlineStatus:onlineStatus];
    
    // 重要，这个地方的改动可能会影响听单
    if (onlineStatus == DriverOnlineStatusOffRunning) {
        [[NSNotificationCenter defaultCenter] postNotificationName:UNIModeSetting_DriverOnlineStatusOffRunning object:nil];
        [DSLocationManager manager].stopWhenInBack = YES;
    }
    else {
        [self setUpQueryDriverStatus:5];
        [[NSNotificationCenter defaultCenter] postNotificationName:UNIModeSetting_DriverOnlineStatusInRunning object:nil];
        [DSLocationManager manager].stopWhenInBack = NO;
    }
    UNISetOnlineStatusParamsModel *params = nil;
    if (object) {
        params =  [[UNISetOnlineStatusParamsModel alloc]init];
        NSString *onTts = [object one_stringForKey:@"on_tts"].length > 0 ? [object one_stringForKey:@"on_tts"]: @"";
        // on_tts: 全调度司机出车tts播报，有则传
        NSString *offTts = [object one_stringForKey:@"off_tts"].length > 0 ? [object one_stringForKey:@"off_tts"]: @"";
        // off_tts:全调度司机收车tts播报，有则传
        params.on_tts = onTts;
        params.off_tts = offTts;
    }
    [[UNIModeSettingController sharedInstance] onlineStatusChanged:onlineStatus ifPlayAudio:ifPlay withParams:params];
}

//设置顺路目的地，小于次距离提示不可设置，单位为米。
- (NSInteger)settingRoadDistanceConfigForApollo{
    APOExperiment *experiment = [ApolloSDKManager experimentWithName:@"driver_order_set_config"];
    if (experiment.enabled) {
        return [experiment integerOfParamWithKey:@"set_road_dest_dist" defaultValue:3000];
    }else{
        return 3000;
    }

}

// 判断实时目的地与当前位置距离，是否大于服务器配置距离（如果小于不能设置该目的地）
- (BOOL)checkDistanceToRealtimeDestinationLat:(double)lat lng:(double)lng {
    CLLocation *destLoc = [[CLLocation alloc] initWithLatitude:lat longitude:lng];
    double distance = [[DSLocationManager manager].lastLocation distanceFromLocation:destLoc];
    double threshold = [self settingRoadDistanceConfigForApollo];
    
    if (threshold <= 0 || distance <= 0)
    return YES; // 数据非法时，不限制距离
    else
    return (distance >  threshold);
}
-(void)offRunningIntervene:(UNIInterveneModel *)intervene{
    __weak DriverOperationController *ws = self;
    if(!intervene){
        DSLogError(@"没有干预数据或干预数据不全,收车");
        [DSToastUtils showToast:@"收车失败"];
    }else{
        [[DSOrderFilter filter] addFilter:DSOrderFilterKey_iGnore];
        DDAudioText(intervene.content, DSVoicePlayerPriorityPushMsg);
        if (self.newAlertToggle) {
            UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:intervene.title andContent:intervene.content];
            [alert configAttributedContent:[intervene.content highlightBraceContent]];
            UIImageView * imageView = [[UIImageView alloc]initWithFrame:CGRectMake(0, 0, alert.width, 311.0/2)];
            [imageView sd_setImageWithURL:[NSURL URLWithString:intervene.imageUrl]];
            [alert addCustomerTopView:imageView];
            [alert addActionButtonWithTitle:intervene.rightButton andButtonType:UNIAlertViewButtonHighlight];
            [alert addActionButtonWithTitle:intervene.leftButton andButtonType:UNIAlertViewButtonDefault];
            [alert setHandlerBlock:^(NSInteger buttonIndex, InterceptPageModelItem *buttonItem, UNIAlertView *alertView) {
                [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
                if(buttonIndex == 0){
                    if(intervene.displayType.integerValue == 1){
                        //导航到热区
                        [StatisticsUtil driver_influback_ck:@"3" interveneName:intervene.interveneName];
                        DSLogInfo(@"司机接受干预，导航到热区");
                        CLLocationDegrees lat = [intervene.desLocation.lat doubleValue];
                        CLLocationDegrees lng = [intervene.desLocation.lng doubleValue];
                        CLLocationCoordinate2D to = CLLocationCoordinate2DMake(lat, lng);
                        if([[UNIMapManager shareManager] isSelfNaviEnable]){
                            [[UNIMapManager shareManager] startNaviation:to scene:4 extraInfo:nil];
                        }
                        else {
                            DSJSInnerNavigationViewController *naviViewController = [[DSJSInnerNavigationViewController alloc] initWithToCoordinate:to andScene:DSInnerNavigationSceneDispatchCard];
                            
                            UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                            nav.navigationBarHidden = YES;
                            [nav pushViewController:naviViewController animated:YES];
                        }
                    }else if (intervene.displayType.integerValue == 2){
                        //继续出车
                        DSLogInfo(@"司机接受干预，继续出车");
                        [StatisticsUtil driver_influback_ck:@"2" interveneName:intervene.interveneName];
                    }else{
                        DSLogError(@"未定义的干预类型，收车");
                        [ws setOnineStatus:DriverOnlineStatusOffRunning];
                    }
                }else if(buttonIndex == 1){
                    [StatisticsUtil driver_influback_ck:@"1" interveneName:intervene.interveneName];
                    DSLogInfo(@"司机不接受干预，收车");
                    [ws setOnineStatus:DriverOnlineStatusOffRunning];
                }
            }];
            [alert show];
        }
        else{
            DSAlertView *interveneAlert = [[DSAlertView alloc] initWithTitle:intervene.title message:intervene.content networkImageURL:intervene.imageUrl];
            [interveneAlert configAttributedMessage:[intervene.content highlightBraceContent]];
            [interveneAlert addButtonWithTitle:intervene.leftButton type:DSAlertViewButtonCancel];
            [interveneAlert addButtonWithTitle:intervene.rightButton type:DSAlertViewButtonDefault];
            [interveneAlert setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
                [[DSOrderFilter filter] removeFilter:DSOrderFilterKey_iGnore];
                if(buttonIndex == 0){
                    [StatisticsUtil driver_influback_ck:@"1" interveneName:intervene.interveneName];
                    DSLogInfo(@"司机不接受干预，收车");
                    [ws setOnineStatus:DriverOnlineStatusOffRunning];
                }else if(buttonIndex == 1){
                    if(intervene.displayType.integerValue == 1){
                        //导航到热区
                        [StatisticsUtil driver_influback_ck:@"3" interveneName:intervene.interveneName];
                        DSLogInfo(@"司机接受干预，导航到热区");
                        CLLocationDegrees lat = [intervene.desLocation.lat doubleValue];
                        CLLocationDegrees lng = [intervene.desLocation.lng doubleValue];
                        CLLocationCoordinate2D to = CLLocationCoordinate2DMake(lat, lng);
                        if([[UNIMapManager shareManager] isSelfNaviEnable]){
                            [[UNIMapManager shareManager] startNaviation:to scene:4 extraInfo:nil];
                        }
                        else {
                            DSJSInnerNavigationViewController *naviViewController = [[DSJSInnerNavigationViewController alloc] initWithToCoordinate:to andScene:DSInnerNavigationSceneDispatchCard];
                            
                            UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                            nav.navigationBarHidden = YES;
                            [nav pushViewController:naviViewController animated:YES];
                        }
                    }else if (intervene.displayType.integerValue == 2){
                        //继续出车
                        DSLogInfo(@"司机接受干预，继续出车");
                        [StatisticsUtil driver_influback_ck:@"2" interveneName:intervene.interveneName];
                    }else{
                        DSLogError(@"未定义的干预类型，收车");
                        [ws setOnineStatus:DriverOnlineStatusOffRunning];
                    }
                }
            }];
            [interveneAlert showInView:[UIApplication sharedApplication].keyWindow];
        }
        
        [StatisticsUtil driver_influback_sw:intervene.interveneName];
    }
}

- (void)showAlertWithPromptData:(UNIPromptDataModel *)prompt
                andOnlineStatus:(DriverOnlineStatus)is_online
                       complete:(DriverOperationBlock)complete{
    if (self.newAlertToggle) {
        UNIAlertView * alert = [[UNIAlertView alloc]initWithTitle:prompt.msg];
        [alert addActionButtonWithTitle:prompt.btn_right andButtonType:UNIAlertViewButtonHighlight];
        [alert addActionButtonWithTitle:prompt.btn_left andButtonType:UNIAlertViewButtonDefault];
        [alert setHandlerBlock:^(NSInteger buttonIndex, InterceptPageModelItem *buttonItem, UNIAlertView *alertView) {
            if(buttonIndex == 0){
                if(prompt.right_url && prompt.right_url.length > 0){
                    DSWebViewController *webVC = [[DSWebViewController alloc] init];
                    webVC.url = [NSURL URLWithString:prompt.right_url];
                    UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                    nav.navigationBarHidden = YES;
                    [nav pushViewController:webVC animated:YES];
                    [StatisticsUtil gulf_d_x_workblocking_block_ck];
                }
            }else if(buttonIndex == 1){
                [self setOnineStatus:is_online isNeedBlock:0 withNotiParams:nil complete:complete];
                [StatisticsUtil gulf_d_x_workingblocker_working_ck];
            }
        }];
        [alert show];
    }
    else{
        DSAlertView *alertView = [[DSAlertView alloc] initWithTitle:prompt.msg];
        [alertView addButtonWithTitle:prompt.btn_left type:DSAlertViewButtonCancel];
        [alertView addButtonWithTitle:prompt.btn_right];
        [alertView show];
        [alertView setHandlerBlock:^(NSInteger buttonIndex, DSAlertView *alertView) {
            if(buttonIndex == 0){
                [self setOnineStatus:is_online isNeedBlock:0 withNotiParams:nil complete:complete];
                [StatisticsUtil gulf_d_x_workingblocker_working_ck];
            }else if(buttonIndex == 1){
                if(prompt.right_url && prompt.right_url.length > 0){
                    DSWebViewController *webVC = [[DSWebViewController alloc] init];
                    webVC.url = [NSURL URLWithString:prompt.right_url];
                    UINavigationController *nav = [OPEV getID:OpenEnvKey_NavigationController defaultValue:nil];
                    nav.navigationBarHidden = YES;
                    [nav pushViewController:webVC animated:YES];
                    [StatisticsUtil gulf_d_x_workblocking_block_ck];
                }
            }
        }];
    }
    
}

#pragma mark - 获取模式getListenMode，设置模式setListenMode
- (void)getListenMode {
    [[UNIModeSettingController sharedInstance] getListenMode];
}

- (void)didLogin {
    // 3.x原有逻辑，在登录成功的消息响应中，先加载操作区UI
    // 然后开始设置连接动画
    [self loadViews];
}

- (void)willLogout {
    // 3.x原有逻辑，在退出登录的消息响应中，先加载操作区UI
    [self unloadViews];
}
@end
