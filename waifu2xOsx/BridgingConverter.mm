//
//  BridgingConverter.m
//  waifu2xOsx
//
//  Created by sewake on 2016/05/10.
//  Copyright © 2016年 Yasumasa Sewake. All rights reserved.
//
#include <opencv2/opencv.hpp>
#include <opencv2/core/ocl.hpp>
#include "modelHandler.hpp"
#include "convertRoutine.hpp"

#import <Cocoa/Cocoa.h>
#import "BridgingConverter.h"

@implementation BridgingConverter

+(NSImage *)convertTo2xImage:(NSImage *)srcImage
{
  // load image file
  cv::Mat image = [BridgingConverter nsImageToCVMat:srcImage];

  if (image.size().width == 0 || image.size().height == 0) {
    NSLog(@"error1:convertTo2xImage");
    return nil;
  }

  image.convertTo(image, CV_32F, 1.0 / 255.0);

  int blockSize = 512;  // 仮の値
  w2xc::modelUtility::getInstance().setBlockSize(cv::Size(blockSize, blockSize));

  std::string modelFileName;
  std::string resourcePath = std::string([[[NSBundle mainBundle] resourcePath] UTF8String]);

  // ===== Noise Reduction Phase =====
  NSString *noise1Path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"noise1_model.bin"];
  
  modelFileName = std::string([noise1Path UTF8String]);
  std::vector<std::unique_ptr<w2xc::Model> > models1;
  
  if (!w2xc::modelUtility::generateModelFromBin(modelFileName, models1))
    std::exit(-1);

  cv::Mat imageYUV;
  cv::cvtColor(image, imageYUV, cv::COLOR_RGB2YUV);
  std::vector<cv::Mat> imageSplit;
  cv::Mat imageY;
  cv::split(imageYUV, imageSplit);
  imageSplit[0].copyTo(imageY);
  
  w2xc::convertWithModels(imageY, imageSplit[0], models1, resourcePath);
  
  cv::merge(imageSplit, imageYUV);
  cv::cvtColor(imageYUV, image, cv::COLOR_YUV2RGB);

  // ===== scaling phase =====
  int iterTimesTwiceScaling = 1;
  NSString *scalePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"scale2.0x_model.bin"];
  modelFileName = std::string([scalePath UTF8String]);
  
  std::vector<std::unique_ptr<w2xc::Model> > models2;
  if (!w2xc::modelUtility::generateModelFromBin(modelFileName, models2))
    std::exit(-1);

  for (int nIteration = 0; nIteration < iterTimesTwiceScaling; nIteration++) {
    
    std::cout << "#" << std::to_string(nIteration + 1)
    << " 2x Scaling..." << std::endl;
    
    cv::Mat imageYUV;
    cv::Size imageSize = image.size();
    imageSize.width *= 2;
    imageSize.height *= 2;
    cv::Mat image2xNearest;
    cv::resize(image, image2xNearest, imageSize, 0, 0, cv::INTER_NEAREST);
    cv::cvtColor(image2xNearest, imageYUV, cv::COLOR_RGB2YUV);
    std::vector<cv::Mat> imageSplit;
    cv::Mat imageY;
    cv::split(imageYUV, imageSplit);
    imageSplit[0].copyTo(imageY);
    
    // generate bicubic scaled image and
    // convert RGB -> YUV and split
    imageSplit.clear();
    cv::Mat image2xBicubic;
    cv::resize(image,image2xBicubic,imageSize,0,0,cv::INTER_CUBIC);
    cv::cvtColor(image2xBicubic, imageYUV, cv::COLOR_RGB2YUV);
    cv::split(imageYUV, imageSplit);
    
    if(!w2xc::convertWithModels(imageY, imageSplit[0], models2, resourcePath))
    {
      std::cerr << "w2xc::convertWithModels : something error has occured.\n stop." << std::endl;
      std::exit(1);
    };
    
    cv::merge(imageSplit, imageYUV);
    cv::cvtColor(imageYUV, image, cv::COLOR_YUV2RGB);
    
  } // 2x scaling : end

  image.convertTo(image, CV_8U, 255.0);
  
  NSImage *retImage = [BridgingConverter NSImageFromCVMat:image];
  return retImage;
}

+(cv::Mat)nsImageToCVMat:(NSImage *)image
{
  CGImageRef cgimage = [BridgingConverter nsdataToCGImage:image];
  
  CGColorSpaceRef colorSpace = CGImageGetColorSpace(cgimage);
  CGFloat cols = image.size.width;
  CGFloat rows = image.size.height;

  cv::Mat cvMat(rows, cols, CV_8UC4); // 8 bits per component, 4 channels
  
  CGContextRef contextRef = CGBitmapContextCreate(cvMat.data,                 // Pointer to backing data
                                                  cols,                       // Width of bitmap
                                                  rows,                       // Height of bitmap
                                                  8,                          // Bits per component
                                                  cvMat.step[0],              // Bytes per row
                                                  colorSpace,                 // Colorspace
                                                  kCGImageAlphaNoneSkipLast |
                                                  kCGBitmapByteOrderDefault); // Bitmap info flags
  
  CGContextDrawImage(contextRef, CGRectMake(0, 0, cols, rows), cgimage);
  CGContextRelease(contextRef);
  
  return cvMat;
}

+(CGImageRef)nsdataToCGImage:(NSImage *)image
{
  CGContextRef bitmapCtx = CGBitmapContextCreate(NULL/*data - pass NULL to let CG allocate the memory*/,
                                                 [image size].width,
                                                 [image size].height,
                                                 8 /*bitsPerComponent*/,
                                                 0 /*bytesPerRow - CG will calculate it for you if it's allocating the data.  This might get padded out a bit for better alignment*/,
                                                 [[NSColorSpace genericRGBColorSpace] CGColorSpace],
                                                 kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
  
  [NSGraphicsContext saveGraphicsState];
  [NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:bitmapCtx flipped:NO]];
  [image drawInRect:NSMakeRect(0,0, [image size].width, [image size].height) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0];
  [NSGraphicsContext restoreGraphicsState];
  
  CGImageRef cgImage = CGBitmapContextCreateImage(bitmapCtx);
  CGContextRelease(bitmapCtx);
  
  return cgImage;
}

+(NSImage *)NSImageFromCVMat:(const cv::Mat&)cvMat
{
  NSData *data = [NSData dataWithBytes:cvMat.data length:cvMat.elemSize() * cvMat.total()];
  
  CGColorSpaceRef colorSpace;
  
  if (cvMat.elemSize() == 1)
  {
    colorSpace = CGColorSpaceCreateDeviceGray();
  }
  else
  {
    colorSpace = CGColorSpaceCreateDeviceRGB();
  }
  
  CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
  
  CGImageRef imageRef = CGImageCreate(cvMat.cols,                                     // Width
                                      cvMat.rows,                                     // Height
                                      8,                                              // Bits per component
                                      8 * cvMat.elemSize(),                           // Bits per pixel
                                      cvMat.step[0],                                  // Bytes per row
                                      colorSpace,                                     // Colorspace
                                      kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                      provider,                                       // CGDataProviderRef
                                      NULL,                                           // Decode
                                      false,                                          // Should interpolate
                                      kCGRenderingIntentDefault);                     // Intent
  
  
  NSBitmapImageRep *bitmapRep = [[NSBitmapImageRep alloc] initWithCGImage:imageRef];
  NSImage *image = [[NSImage alloc] init];
  [image addRepresentation:bitmapRep];
  
  CGImageRelease(imageRef);
  CGDataProviderRelease(provider);
  CGColorSpaceRelease(colorSpace);
  
  return image;
}

@end
