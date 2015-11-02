//
//  BLECentralManager.m
//  BluetoothCamera
//
//  Created by ChenZheng on 15/11/1.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import "BLECentralManager.h"

static NSString *const kCentralQueueCreateLabel = @"com.QiuShiBaiKe.xx.BLECentralManager";

@interface BLECentralManager () <CBCentralManagerDelegate, CBPeripheralDelegate>

@property (nonatomic , strong) dispatch_queue_t centralConnectQueue;
@property (nonatomic , strong) CBCentralManager *centralManager;

@property (nonatomic , strong) NSArray *targetServiceStrings;
@property (nonatomic) BOOL startScanWhenReady;
@property (nonatomic , strong) CBUUID *targetUUID;

@end

@implementation BLECentralManager

- (CBCentralManager *)centralManager
{
    if (!_centralManager) {
        self.centralConnectQueue = dispatch_queue_create([kCentralQueueCreateLabel UTF8String], DISPATCH_QUEUE_CONCURRENT);
        _centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.centralConnectQueue options:@{CBCentralManagerOptionShowPowerAlertKey:@(YES)}];
    }
    return _centralManager;
}

- (void)cleanUpConnection
{
    if (self.centralManager.state != CBCentralManagerStatePoweredOn) {
        return;
    }
    
    [self.centralManager stopScan];
    
    if (self.activePeripheral.state != CBPeripheralStateConnected) {
        return;
    }
    
    if (self.activePeripheral.services != nil) {
        for (CBService *service in self.activePeripheral.services) {
            if (service.characteristics != nil) {
                for (CBCharacteristic *characteristic in service.characteristics) {
                    if (characteristic.isNotifying) {
                        [self.activePeripheral setNotifyValue:NO forCharacteristic:characteristic];
                    }
                }
            }
        }
    }
    
    [self.centralManager cancelPeripheralConnection:self.activePeripheral];
}

- (void)startSearchingWithServiceUUIDsWhenReady:(NSArray *)services
{
    self.targetServiceStrings = services;
    self.startScanWhenReady = YES;
    [self centralManager];
}

- (void)startSearchingWithServiceUUIDs:(NSArray *)services;
{
    NSMutableArray *servicesArray = [NSMutableArray array];
    for (NSString *string in services) {
        CBUUID *cbuuID = [CBUUID UUIDWithString:string];
        [servicesArray addObject:cbuuID];
    }
    NSLog(@"开始搜索servicesArray = %@",servicesArray);
    [self.centralManager scanForPeripheralsWithServices:servicesArray options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES }];
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    switch (central.state) {
        case CBCentralManagerStateUnknown:
        {
            
        }
            break;
        case CBCentralManagerStatePoweredOn:
        {
            if (self.startScanWhenReady) {
                [self startSearchingWithServiceUUIDs:self.targetServiceStrings];
            }
            break;
        }
        case CBCentralManagerStateUnauthorized:
        {
            
        }
            break;
        default:
            break;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"找到广播：%@,RSSI = %@",advertisementData,RSSI);
    //    Polar HR Sensor
    //    Bluno
    //    Heart Rate
    
    //NOTE:
    /*
     UUID:FB300B7F-D908-4303-8348-0CB1F5F1DC74
     开始scan之后，需要设置一个超时时间，除非设定就是一直scan
     */
    if ([advertisementData[@"kCBAdvDataLocalName"] isEqualToString:@"B7A1"]) {
        NSLog(@"开始连接");
        
        //NOTE：这里一定要hold住
        self.activePeripheral = peripheral;
        [self.centralManager connectPeripheral:peripheral options:nil];
        [self.centralManager stopScan];
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"连接失败");
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"连接上一个外设");
    self.activePeripheral = peripheral;
    self.activePeripheral.delegate = self;
    //NOTE:通常这里指定UUID(CBUUID)
    [self.activePeripheral discoverServices:nil];
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"断开连接了");
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"找到的服务:%@",service);
        //NOTE:通常这里指定UUID(CBUUID)
        [peripheral discoverCharacteristics:nil forService:service];
    }
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"服务:%@对应的特征值:%@，UUID = %@",service,characteristic,characteristic.UUID);
        if (characteristic.properties == CBCharacteristicPropertyNotify) {
            NSLog(@"监听characteristic = %@",characteristic);
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"血糖写入errror = %@",error);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"didUpdateNotificationStateForCharacteristic = %@,value = %@",characteristic,characteristic.value);
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error didUpdateValueForCharacteristic characteristics: %@,characteristic=%@", error,characteristic);
        return;
    }
    if (self.totalReceviedImageData == nil) {
        self.totalReceviedImageData = [NSMutableData data];
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"FFFF"]]) {
        NSLog(@"收到进度数据:%@",characteristic.value);
        NSData *data = characteristic.value;
        const char*   pos =  [data bytes];
        NSInteger  a = -1;
        memcpy(&a, pos, sizeof(int));
        if (self.updatePercentHandler) {
            self.updatePercentHandler(a);
        }
    }
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:@"DDDD"]]) {
        NSData *batchImageData = [characteristic.value subdataWithRange:NSMakeRange(0, characteristic.value.length - 2)];
        NSData *indexData = [characteristic.value subdataWithRange:NSMakeRange(characteristic.value.length - 2, 2)];
        Byte *indexArr = (Byte *)[indexData bytes];
        
        //用16进制表示packageIndex，高八位放在pi[0]，低八位放在pi[1]
        
//        Byte pi[2] = {(packageIndex | 0xff00) >> 8,packageIndex | 0x00ff};
        NSInteger index = indexArr[0];
        index = index << 8;
        index = index | indexArr[1];
        NSLog(@"序号:%@,收到图片数据:%@",@(index),batchImageData);
        
    }
    
    NSData *data = characteristic.value;
    NSString *string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"UUID = %@,DATA = %@,String = %@",characteristic.UUID.UUIDString,[self.class getFormattedStringFromData:characteristic.value],string);
}

+ (NSString *)getFormattedStringFromData:(NSData *)data
{
    Byte *testByte = (Byte *)[data bytes];
    NSString *string = @"";
    @autoreleasepool {
        NSString *hexStr=@"";
        for(int i=0;i<[data length];i++) {
            NSString *newHexStr = [NSString stringWithFormat:@"%x",testByte[i]&0xff]; ///16进制数
            if([newHexStr length]==1)
                hexStr = [NSString stringWithFormat:@"%@0%@",hexStr,newHexStr];
            else
                hexStr = [NSString stringWithFormat:@"%@%@",hexStr,newHexStr];
        }
        
        //        for(int i=0;i<[data length];i++)
        //            printf("。%d,",testByte[i]);
        //        putchar('\n');
        //        string = [NSString stringWithFormat:@"HEX串:%@,长度:%ld",hexStr,[data length]];
        string = [NSString stringWithFormat:@"%@",hexStr];
        //        NSLog(@"%@",string);
    }
    return string;
}

@end
