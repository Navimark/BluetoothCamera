//
//  BLEPeripheralManager.h
//  BluetoothCamera
//
//  Created by ChenZheng on 15/11/1.
//  Copyright © 2015年 QiuShiBaiKe. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface BLEPeripheralManager : NSObject

@property (nonatomic , strong, readonly) CBPeripheralManager *peripheralManager;
@property (nonatomic , strong, readonly) NSString *broadcastIdentifyKey;
@property (nonatomic , strong) UIImage *image;
@property (nonatomic , readonly) BOOL readyToSendImage;

- (void)readyToBroadcastVcard;

@end
