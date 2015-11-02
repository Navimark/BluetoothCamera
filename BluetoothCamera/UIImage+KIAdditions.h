//
//  UIImage+KIImage.h
//  QiuBai
//
//  Created by Archmage on 14-4-16.
//  Copyright (c) 2014年 Less Everything. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (KIAdditions)

+ (UIImage *)resizeImage:(UIImage*)img toSize:(CGSize)newSize;

@end
