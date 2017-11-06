//
//  Mapper.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 29/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

class Mapper000: IMapper {
  
  var cartridge: Cartridge!;
  
  init () {
    cartridge = nil;
  }
  
  init (_ cartridge: Cartridge) {
    self.cartridge = cartridge;
  }
  
  func loadPRG () {
    if (cartridge!.PRG_ROM_SIZE > 1) {
      switchPRGbank(cartridge!.cpu!.ram, 0, 0x8000);
      switchPRGbank(cartridge!.cpu!.ram, 1, 0xC000);
    } else {
      switchPRGbank(cartridge!.cpu!.ram, 0, 0x8000);
      switchPRGbank(cartridge!.cpu!.ram, 0, 0xC000);
    }
  }
  
  func switchPRGbank (ram: RAM, _ bankIndex: Int, _ address: Int) {
    var i = bankIndex * 16384;
    let limit = i + 16384;
    
    var j = 0;
    for (; i < limit; i++) {
      ram.write(address + j, (cartridge?.PRG_ROM[i])!);
      j++;
    }
  }
  
  func loadCHR () {
    
  }
  
  func switchCHRbank (ram: RAM, _ bankIndex: Int, _ address: Int) {
    
  }
  
}
