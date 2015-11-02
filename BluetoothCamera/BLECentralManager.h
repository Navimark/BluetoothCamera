//
//  BLECentralManager.h
//  BluetoothCamera
//
//  Created by ChenZheng on 15/11/1.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <UIKit/UIKit.h>

@interface BLECentralManager : NSObject

@property (nonatomic , strong , readonly) CBCentralManager *centralManager;
@property (nonatomic , strong) CBPeripheral *activePeripheral;
@property (nonatomic , strong , readonly) dispatch_queue_t centralConnectQueue;

@property (nonatomic , strong) NSMutableData *totalReceviedImageData;
@property (nonatomic , copy) void(^updatePercentHandler)(CGFloat percent);

/**
 *  开始搜索服务
 *
 *  @param services 由16进制字符串组成的128bit或者16bit的字符串
 *  @return 成功启动返回YES
 */
- (void)startSearchingWithServiceUUIDsWhenReady:(NSArray *)services;
- (void)cleanUpConnection;


@end
