//
//  VRAM.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 09/12/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

import Foundation

public class VRAM {
  
  var vram: [Int];
  var sprRam: [Int];
  
  func reset () {
    vram = [Int](count:0x10000, repeatedValue: 0);
    sprRam = [Int](count:0x100, repeatedValue: 0);
  }
  
  init () {
    vram = [Int](count:0x10000, repeatedValue: 0)
    sprRam = [Int](count:0x100, repeatedValue: 0);
  }

  
}