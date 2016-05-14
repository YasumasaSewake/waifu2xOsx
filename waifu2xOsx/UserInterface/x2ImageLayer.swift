//
//  x2ImageLayer.swift
//  waifu2xOsx
//
//  Created by sewake on 2016/05/14.
//  Copyright © 2016年 Yasumasa Sewake. All rights reserved.
//

import Foundation
import Cocoa

class x2ImageLayer : CALayer {

  var imageData : NSImage?
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder:aDecoder)
  }

  init(imageData : NSImage ) {
    super.init()
    
    self.imageData = imageData
    
    self.contentsScale = (NSScreen.mainScreen()?.backingScaleFactor)!

    self._loadx2Image()
  }
  
  func _loadx2Image()
  {
    //NSOperationQueue().addOperationWithBlock({ () -> Void in
      let x2ImageData = BridgingConverter.convertTo2xImage(self.imageData)
      self.contents = x2ImageData
//    })
  }
}
