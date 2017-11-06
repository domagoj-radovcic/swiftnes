//
//  Cartridge.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 29/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

import Foundation;

class Cartridge {
  
  var cpu: CPU!;
  
  var mapper: IMapper!;
  
  var header: [Int];
  
  var PRG_ROM_SIZE: Int; // 16kB units, x 16
  var PRG_ROM: [Int];
  
  var CHR_ROM_SIZE: Int; // 8kB units, x 8
  var CHR_ROM: [Int];
  
  var RAM_SIZE: Int; // 8kB units, x 8
  var RAM: [Int];
  
  var mirroring: Int; // 0 - horizontal, 1 - vertical
  var batterySRAM: Int;
  var trainer: Int;
  var fourScreenVRAM: Int;
  var mapperNumber: Int;
  var vsSystem: Int;
  var tvSystem: Int;
  
  init () {
    cpu = nil;
    mapper = nil;
    
    header = [Int]();
    
    PRG_ROM_SIZE = 0;
    PRG_ROM = [Int]();
    
    CHR_ROM_SIZE = 0;
    CHR_ROM = [Int]();
    
    RAM_SIZE = 0;
    RAM = [Int]();
    
    mirroring = 0;
    batterySRAM = 0;
    trainer = 0;
    fourScreenVRAM = 0;
    mapperNumber = 0;
    vsSystem = 0;
    tvSystem = 0;
  }
  
  func setCpu (cpu: CPU) {
    self.cpu = cpu;
  }
  
  func loadCartridge () -> Bool {
    let path = NSBundle(forClass: Cartridge.self).pathForResource("nestest", ofType: "nes") ?? "";
    let data = NSData(contentsOfFile: path as String);
    let dataCount = (data?.length)!;
    var dataArray = [uint8](count: dataCount, repeatedValue: 0);
    
    data?.getBytes(&dataArray, range: NSRange(location: 0, length: dataCount));

    header = [Int](count: 16, repeatedValue: 0);
    for (var i = 0; i < 16; i++) {
      header[i] = Int(dataArray[i]);
    }
  
    if header[0] != 0x4E || header[1] != 0x45 || header[2] != 0x53 || header[3] != 0x1A {
      return false;
    }
    
    PRG_ROM_SIZE = header[4];
    PRG_ROM = [Int](count: 16384 * PRG_ROM_SIZE, repeatedValue: 0);
    
    CHR_ROM_SIZE = header[5];
    CHR_ROM = [Int](count: 8192 * PRG_ROM_SIZE, repeatedValue: 0);
    
    mirroring = (header[6] >> 0) & 1;
    batterySRAM = (header[6] >> 1) & 1;
    trainer = (header[6] >> 2) & 1;
    fourScreenVRAM = (header[6] >> 3) & 1;
    
    mapperNumber = (header[6] >> 4 & 0x0f) | (header[7] >> 4 & 0x0f);
    
    var j = 0;
    let length = 16 + PRG_ROM.count;
    for (var i = 16; i < length; i++) {
      PRG_ROM[j] = Int(dataArray[i]) & 0xff;
      j++;
    }
    
    loadMapper();
    loadPRG();

    return true;
  }
  
  func loadMapper () {
    switch mapperNumber {
    case 0x0000:
      mapper = Mapper000(self);
      break;
    default:
      break;
    }
  }
  
  func loadPRG () {
    mapper?.loadPRG();
  }
  
  func switchPRGbank (bankIndex: Int, _ address: Int) {
    mapper?.switchPRGbank(cpu!.ram, bankIndex, address);
  }
  
  func loadCHR () {
    mapper?.loadCHR();
  }
  
  func switchCHRbank (bankIndex: Int, _ address: Int) {
    mapper?.switchCHRbank(cpu!.ram, bankIndex, address);
  }
  
  func outputInfo () {
    print("##### CARTRIDGE INFO #####");
    print("PRG ROM banks: \(PRG_ROM_SIZE)");
    print("CHR ROM banks: \(CHR_ROM_SIZE)");
    print("RAM banks: \(RAM_SIZE)");
    print("Mirroring: \(mirroring == 0 ? "Horizontal" : "Vertical")");
    print("Battery save: \(batterySRAM)");
    print("Trainer: \(trainer)");
    print("Fourscreen VRAM: \(fourScreenVRAM)");
    print("Mapper number: \(mapperNumber)");
    print("PRG ROM size: \(PRG_ROM_SIZE * 16) kB");
    print("CHR ROM size: \(CHR_ROM_SIZE * 8) kB");
    print("RAM size: \(RAM_SIZE * 8) kB");
  }
  
}
