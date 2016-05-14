//
//  x1ImageLayer.swift
//  waifu2xOsx
//
//  Created by sewake on 2016/05/14.
//  Copyright © 2016年 Yasumasa Sewake. All rights reserved.
//

import Foundation
import Cocoa

class x1ImageLayer : CALayer {

  required init?(coder aDecoder: NSCoder) {
    super.init(coder:aDecoder)
  }

  init(imageData : NSImage ) {
    super.init()
    
    self.contentsScale = (NSScreen.mainScreen()?.backingScaleFactor)!
    self.contents = imageData
  }
  
  
}