//
//  BridgingConverter.h
//  waifu2xOsx
//
//  Created by sewake on 2016/05/10.
//  Copyright © 2016年 Yasumasa Sewake. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface BridgingConverter : NSObject

+(NSImage *)convertTo2xImage:(NSImage *)srcImage;

@end
