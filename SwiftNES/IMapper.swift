//
//  IMapper.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 29/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

protocol IMapper {
  
  var cartridge: Cartridge! { get set }
  
  func loadPRG ();
  
  func switchPRGbank (ram: RAM, _ bankIndex: Int, _ address: Int);
  
  func loadCHR ();
  
  func switchCHRbank (ram: RAM, _ bankIndex: Int, _ address: Int);
  
}