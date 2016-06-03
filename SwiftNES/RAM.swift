//
//  RAM.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 20/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//


public class RAM {
  
  var memory: [Int];
  
  func reset () {
    memory = [Int](count:0x10000, repeatedValue: 0);
  }
  
  init () {
    memory = [Int](count:0x10000, repeatedValue: 0)
  }
  
  func read8 (address: Int) -> Int {
    return memory[address];
  }
  
  func read16 (address: Int) -> Int {
    return (memory[address + 1] << 8) | memory[address];
  }
  
  func read16WithBug (address: Int) -> Int {
    return (memory[(address + 1) & 0xFF] << 8) | memory[address];
  }
  
  func read16WithIndirectBug (address1: Int, _ address2: Int) -> Int {
    return (memory[address2] << 8) | memory[address1];
  }
  
  func write (address: Int, _ value: Int) {
    memory[address] = value;
  }
  
  func pushToStack (cpu: CPU, _ value: Int) {
    write((0x0100 + cpu.SP), value);
    cpu.decrementSP();
  }
  
  func popFromStack (cpu: CPU) -> Int {
    cpu.incrementSP();
    return read8(0x0100 + cpu.SP);
  }
}
