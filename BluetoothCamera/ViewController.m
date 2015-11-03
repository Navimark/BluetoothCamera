//
//  ViewController.m
//  BluetoothCamera
//
//  Created by ChenZheng on 15/11/1.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import "ViewController.h"
#import <ReactiveCocoa.h>
#import <SCRecorder.h>
#import "BLEPeripheralManager.h"
#import "BLECentralManager.h"
#import "UIImage+KIAdditions.h"
#import <ReactiveCocoa.h>

typedef NS_ENUM(NSInteger,ViewType) {
    ViewTypeCentral = 10,
    ViewTypePeripheral
};

@interface ViewController ()

@property (nonatomic) ViewType currentType;
@property (nonatomic, strong) SCRecorder *recorder;
@property (nonatomic, strong) SCRecordSession *recordSession;
@property (weak, nonatomic) IBOutlet UIView *preView;
@property (nonatomic , strong) BLEPeripheralManager *peripheralManager;



@property (weak, nonatomic) IBOutlet UIButton *shootButton;
@property (weak, nonatomic) IBOutlet UIView *imageFrameView;
@property (nonatomic , strong) BLECentralManager *centralManager;
@property (weak, nonatomic) IBOutlet UIImageView *receviedImageView;

@end

@implementation ViewController

- (BLEPeripheralManager *)peripheralManager
{
    if (!_peripheralManager) {
        _peripheralManager = [[BLEPeripheralManager alloc] init];
    }
    return _peripheralManager;
}

- (BLECentralManager *)centralManager
{
    if (!_centralManager) {
        _centralManager = [[BLECentralManager alloc] init];
    }
    return _centralManager;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"请选择工作模式" delegate:nil cancelButtonTitle:nil otherButtonTitles:@"遥控器模式",@"摄像机模式", nil];
    @weakify(self);
    [[[alert rac_buttonClickedSignal] deliverOnMainThread] subscribeNext:^(NSNumber *index) {
        @strongify(self);
        if (index.integerValue == 0) {
            self.currentType = ViewTypeCentral;
        } else if (index.integerValue == 1) {
            self.currentType = ViewTypePeripheral;
        }
        [self performSelectorOnMainThread:@selector(configView) withObject:nil waitUntilDone:NO];
    }];
    [alert show];
}

- (void)configView
{
    if (self.currentType == ViewTypePeripheral) {
        self.recorder = [SCRecorder recorder];
        self.recorder.captureSessionPreset = AVCaptureSessionPresetPhoto;
        self.recorder.audioConfiguration.enabled= NO;
        self.recorder.device = AVCaptureDevicePositionBack;
        self.recorder.previewView = self.preView;
        self.recorder.initializeSessionLazily = NO;
        self.recorder.autoSetVideoOrientation = YES;
        self.recorder.videoConfiguration.scalingMode = AVVideoScalingModeResizeAspectFill;
        self.recordSession = [SCRecordSession recordSession];
        self.recorder.session = self.recordSession;
        NSError *error;
        if (![_recorder prepare:&error]) {
            NSLog(@"Prepare error: %@", error.localizedDescription);
        }
        self.imageFrameView.hidden = YES;
        self.preView.hidden = NO;
        [self.recorder startRunning];
        //开始广播
        [self.peripheralManager readyToBroadcastVcard];
        
        @weakify(self);
        [[RACObserve(self.peripheralManager, readyToSendImage) deliverOnMainThread] subscribeNext:^(NSNumber *x) {
            @strongify(self);
 //           [[[UIAlertView alloc] initWithTitle:[NSString stringWithFormat:@"搞什么%@",x] message:nil delegate:nil cancelButtonTitle:@"去洗哦啊 " otherButtonTitles:nil, nil] show];
            if (!x.boolValue) {
                return ;
            }
            __weak __typeof(self)weakSelf = self;
            [self.recorder capturePhoto:^(NSError * _Nullable error, UIImage * _Nullable image) {
                __strong __typeof(weakSelf)strongSelf = weakSelf;
                if (image != nil) {
                    strongSelf.peripheralManager.image = [UIImage resizeImage:image toSize:CGSizeMake(320, 320)];
                }
            }];
        }];
    } else {
        self.imageFrameView.hidden = NO;
        self.preView.hidden = YES;
        [self.centralManager startSearchingWithServiceUUIDsWhenReady:@[self.peripheralManager.broadcastIdentifyKey]];
        __weak __typeof(self)weakSelf = self;
        self.centralManager.receviedTotoallyImageDataHandler = ^(NSData *imageData){
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            dispatch_async(dispatch_get_main_queue(), ^{
                UIImage *image = [UIImage imageWithData:imageData];
                strongSelf.receviedImageView.image = image;
            });
        };
        self.centralManager.updatePercentHandler = ^(CGFloat percent){
            NSLog(@"主界面上更新进度为:%@",@(percent));
        };
    }
}
//
//2765BD69-B7A1-4EB1-B2DF-23062E99062A
#pragma mark - Action
- (IBAction)shootButtonAction:(UIButton *)sender
{
    //想peripheral发送request，拍照，
}


@end
