//
//  MainScrollView.swift
//  waifu2xOsx
//
//  Created by sewake on 2016/05/10.
//  Copyright © 2016年 Yasumasa Sewake. All rights reserved.
//

import Foundation
import AppKit

class MainScrollView: NSScrollView {
  
  var x1Layer   : x1ImageLayer? = nil
  var x2Layer   : x2ImageLayer? = nil
  var imageData : NSImage?
  
  var layerFrame : NSRect = CGRectZero
  var calcFrame :  NSRect = CGRectZero
  var token: dispatch_once_t = 0
  
  required init?(coder: NSCoder) {
    super.init(coder: coder)
    
    self.wantsLayer = true
    self.registerForDraggedTypes([NSFilenamesPboardType]);
    
    calcFrame = self.frame
    
    self.maxMagnification = 2.0
  }
  
  override func layout() {
    // 諸々レイアウト
    super.layout()

    let origin   = window!.frame.origin
    calcFrame.origin = origin
  
    window!.setFrame(calcFrame, display:true, animate:true)
    self.documentView!.setFrameSize(calcFrame.size)

    dispatch_once(&token) {
      self.window?.titleVisibility = .Hidden
      self.window?.styleMask |= NSFullSizeContentViewWindowMask
      self.window?.titlebarAppearsTransparent = true
    }
  }
 
  override func draggingEntered(sender:NSDraggingInfo)->NSDragOperation{
    //return NSDragOperation.Generic;
    //        return NSDragOperation.Copy; //マウスポインタがかわる(+の緑アイコンがつく)
    return NSDragOperation.Link;
  }
  
  override func performDragOperation(sender:NSDraggingInfo)->Bool {
    
    if let pasteboard = sender.draggingPasteboard().propertyListForType("NSFilenamesPboardType") as? NSArray {
      if let path = pasteboard[0] as? String {

        _initializeScrollView( path )
        
        // ファイルを開いた場合はtrue
        return true
      }
    }
    
    return false
  }
  
  private func _initializeScrollView( path : String )
  {
    // イメージをロード
    _openImageFile(path)
    
    // ウィンドウサイズを確定
    _calcWindowSize()
    self.layout()

    x1Layer?.removeFromSuperlayer()
    x2Layer?.removeFromSuperlayer()
    
    // イメージをロード (元画像)
    x1Layer = x1ImageLayer(imageData:self.imageData!)
    x1Layer!.frame = layerFrame
    self.layer?.addSublayer(x1Layer!)
    
    // イメージをロード x2画像
    x2Layer = x2ImageLayer(imageData:self.imageData!)
    var x2LayerFrame = layerFrame
    x2LayerFrame.origin.x = layerFrame.width
    x2Layer!.frame = x2LayerFrame
    self.layer?.addSublayer(x2Layer!)
  }
  
  
//MARK:private
 
  func _calcWindowSize()
  {
    let imageRep = self.imageData!.representations[0]
    let origin   = window!.frame.origin

    // ウィンドウサイズを決める
    calcFrame = NSMakeRect(origin.x, origin.y, CGFloat(imageRep.pixelsWide) * 2, CGFloat(imageRep.pixelsHigh))
    
    // レイヤサイズを決める
    layerFrame = NSMakeRect(0, 0, CGFloat(imageRep.pixelsWide), CGFloat(imageRep.pixelsHigh))
  }
  
  func _openImageFile( path : String )
  {
    let data = NSFileManager.defaultManager().contentsAtPath(path)
    self.imageData = NSImage(data:data!)
  }

}