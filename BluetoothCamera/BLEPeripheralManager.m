//
//  BLEPeripheralManager.m
//  BluetoothCamera
//
//  Created by ChenZheng on 15/11/1.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import "BLEPeripheralManager.h"
#import <ReactiveCocoa.h>

static NSString *const kPeripheralQueueCreateLabel = @"com.QiuShiBaiKe.xx.kPeripheralQueueCreateLabel";
static NSString *const kSenderCharacteristicUUIDString = @"DDDD";
static NSString *const kPercentCharacteristicUUIDString = @"FFFF";

static NSString *const kSendPhotoServiceUUIDString = @"0931905A-F796-44D1-9DDA-8E2C1C93578A";
static NSString *const kAdIdentifyKey = @"B7A1";

@interface BLEPeripheralManager () <CBPeripheralManagerDelegate>

@property (nonatomic , strong) CBPeripheralManager *peripheralManager;
@property (nonatomic , strong) CBMutableService     *sendPhotoService;

@property (nonatomic , strong) CBMutableCharacteristic *percentCharacteristic;
@property (nonatomic , strong) CBMutableCharacteristic *senderCharacteristic;
@property (nonatomic) BOOL broadcastWhenReady;
@property (nonatomic , strong) CBCentral *activeCentral;

@property (nonatomic) BOOL readyToSendImage;
@property (nonatomic) BOOL isSending;
@property (nonatomic , strong) dispatch_semaphore_t sendDataSemaphore;

@end

@implementation BLEPeripheralManager

- (NSString *)broadcastIdentifyKey
{
    return kAdIdentifyKey;
}

- (CBPeripheralManager *)peripheralManager
{
    if (!_peripheralManager) {
        dispatch_queue_t q = dispatch_queue_create([kPeripheralQueueCreateLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:q options:nil];
    }
    return _peripheralManager;
}

- (void)readyToBroadcastVcard
{
    self.broadcastWhenReady = YES;
    [self peripheralManager];
}

#pragma mark - Private

- (void)setupService
{
    CBUUID *characteristicUUID1 = [CBUUID UUIDWithString:kPercentCharacteristicUUIDString];
    self.percentCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID1
                                                                    properties:CBCharacteristicPropertyNotify
                                                                         value:nil
                                                                   permissions:CBAttributePermissionsReadable];
    
    CBUUID *characteristicUUID2 = [CBUUID UUIDWithString:kSenderCharacteristicUUIDString];
    self.senderCharacteristic = [[CBMutableCharacteristic alloc] initWithType:characteristicUUID2
                                                                   properties:CBCharacteristicPropertyNotify
                                                                        value:nil
                                                                  permissions:CBAttributePermissionsReadable];
    CBUUID *servieceUUID = [CBUUID UUIDWithString:kSendPhotoServiceUUIDString];
    self.sendPhotoService = [[CBMutableService alloc] initWithType:servieceUUID primary:YES];
    [self.sendPhotoService setCharacteristics:@[self.senderCharacteristic,self.percentCharacteristic]];
    [self.peripheralManager addService:self.sendPhotoService];
    
    @weakify(self);
    [RACObserve(self, image) subscribeNext:^(UIImage *image) {
        @strongify(self);
        if (self.activeCentral != nil) {
            [self startSendImage];
        }
    }];
    
    self.sendDataSemaphore = dispatch_semaphore_create(0);
}

- (void)startSendImage
{
    NSData *imageData = UIImageJPEGRepresentation(self.image, 0.6);
    NSUInteger totalLength = [imageData length];
    
    NSUInteger sentSize = 0;
    NSUInteger loc = 0;
    
    NSUInteger packageIndex = 0;
    while (sentSize < totalLength) {
        NSUInteger maxBatchSize = [self.activeCentral maximumUpdateValueLength] - 2;//留出2个byte位置，作为index
        NSData *batchImageData = nil;
        NSUInteger oneTimeSize = 0;
        
        if (totalLength - sentSize < maxBatchSize) {
            //发送(totalLength - sentSize)大小的
            oneTimeSize = totalLength - sentSize;
        } else {
            oneTimeSize = maxBatchSize;
        }
        
        batchImageData = [imageData subdataWithRange:NSMakeRange(loc, oneTimeSize)];
        
        NSMutableData *tData = [NSMutableData dataWithData:batchImageData];
        
        //用16进制表示packageIndex，高八位放在pi[0]，低八位放在pi[1]
        
        Byte pi[2] = {(packageIndex | 0xff00) >> 8,packageIndex | 0x00ff};
        [tData appendBytes:pi length:2];
        
        batchImageData = tData;
        
        loc = (loc + oneTimeSize);
        
        BOOL sendImageSucc = [self.peripheralManager updateValue:batchImageData
                          forCharacteristic:self.senderCharacteristic onSubscribedCentrals:@[self.activeCentral]];
        if (!sendImageSucc) {
//            阻塞线程，直到peripheralManagerIsReadyToUpdateSubscribers
            NSLog(@"发送image数据堵塞了");
            dispatch_semaphore_wait(self.sendDataSemaphore, DISPATCH_TIME_FOREVER);
        }
        NSLog(@"成功发送数据batchImageData = %@,packageIndex = %@",batchImageData,@(packageIndex));
        //更新进度
        NSInteger percent = (sentSize * 1.0f / totalLength) * 100;
        pi[0] = percent;
        BOOL sendPercentSucc = [self.peripheralManager updateValue:[NSData dataWithBytes:pi length:1]
                          forCharacteristic:self.percentCharacteristic onSubscribedCentrals:@[self.activeCentral]];
        if (!sendPercentSucc) {
//            阻塞线程，直到peripheralManagerIsReadyToUpdateSubscribers
            NSLog(@"发送进度堵塞了 = %@",@(percent));
            dispatch_semaphore_wait(self.sendDataSemaphore, DISPATCH_TIME_FOREVER);
        }
        NSLog(@"发送进度 = %@",@(percent));
        sentSize = loc + oneTimeSize;
        packageIndex ++;
    }
//    NSLog(@"maxBatchSize = %@",@(maxBatchSize));//字节byte
    Byte pi[1] = {100};
    NSLog(@"发送进度100%%");
    BOOL isSendPercentSucc = [self.peripheralManager updateValue:[NSData dataWithBytes:pi length:1]
          forCharacteristic:self.percentCharacteristic onSubscribedCentrals:@[self.activeCentral]];
    if (!isSendPercentSucc) {
        dispatch_semaphore_wait(self.sendDataSemaphore, DISPATCH_TIME_FOREVER);
    }
    self.readyToSendImage = NO;
}

#pragma mark - CBPeripheralManagerDelegate
- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    NSLog(@"peripheralManagerIsReadyToUpdateSubscribers");
    dispatch_semaphore_signal(self.sendDataSemaphore);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didAddService:(CBService *)service error:(NSError *)error
{
    if (error == nil) {
        NSDictionary *adDict = @{CBAdvertisementDataLocalNameKey:kAdIdentifyKey,
                                 CBAdvertisementDataServiceUUIDsKey:@[[CBUUID UUIDWithString:kSendPhotoServiceUUIDString]],
                                 CBAdvertisementDataIsConnectable:@(YES)};
        NSLog(@"开始广播adDict = %@",adDict);
        [self.peripheralManager startAdvertising:adDict];
    } else {
        NSLog(@"%s,error = %@",__PRETTY_FUNCTION__,error);
    }
}

- (void)peripheralManagerDidStartAdvertising:(CBPeripheralManager *)peripheral error:(NSError *)error
{
    NSLog(@"开始广播%s,error = %@",__PRETTY_FUNCTION__,error);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    if (self.isSending) {
        return;
    }
    [self.peripheralManager stopAdvertising];
    NSLog(@"已经有central=%@设备接受了服务，我们要给它生成动态数据\n连接请求,%s,,characteristic = %@",central,__PRETTY_FUNCTION__,characteristic);
    self.activeCentral = central;
    //更新进度为0%
    Byte pi[1] = {0};
    
    BOOL isSendSucc = [self.peripheralManager updateValue:[NSData dataWithBytes:pi length:1]
                      forCharacteristic:self.percentCharacteristic onSubscribedCentrals:@[self.activeCentral]];
    if (!isSendSucc) {
        dispatch_semaphore_wait(self.sendDataSemaphore, DISPATCH_TIME_FOREVER);
    }
    self.readyToSendImage = YES;
    self.isSending = YES;
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    NSLog(@"%s",__PRETTY_FUNCTION__);
}

- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
        {
            NSLog(@"Bluetooth is currently powered on and available to use.");
            if (self.broadcastWhenReady) {
                [self setupService];
            }
        }
            break;
        case CBPeripheralManagerStatePoweredOff:
        {
            NSLog(@"Bluetooth is currently powered off.");
        }
            break;
        case CBPeripheralManagerStateUnauthorized:
        {
            NSLog(@"The application is not authorized to use the Bluetooth Low Energy Peripheral/Server role.");
        }
            break;
        case CBPeripheralManagerStateUnsupported:
        {
            NSLog(@"The platform doesn't support the Bluetooth Low Energy Peripheral/Server role.");
        }
            break;
        case CBPeripheralManagerStateResetting:
        {
            NSLog(@"The connection with the system service was momentarily lost, update imminent.");
        }
            break;
        case CBPeripheralManagerStateUnknown:
        {
            NSLog(@"State unknown, update imminent.");
        }
            break;
        default:
            NSLog(@"Peripheral Manager did change state");
            break;
    }
}

@end
