//
//  OpCode.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 20/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

public enum OpCodeName {
  
  case ADC, AND, ASL, BCC, BCS, BEQ, BIT, BMI, BNE, BPL, BRK, BVC, BVS, CLC, CLD, CLI, CLV, CMP, CPX, CPY, DEC, DEX,
    DEY, EOR, INC, INX, INY, JMP, JSR, LDA, LDX, LDY, LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL, ROR, RTI, RTS, SBC, SEC,
    SED, SEI, STA, STX, STY, TAX, TAY, TSX, TXA, TXS, TYA, AAC, AAX, ARR, ASR, ATX, AXA, AXS, DCP, DOP, ISC, KIL, LAR,
    LAX, RLA, RRA, SLO, SRE, SXA, SYA, TOP, XAA, XAS
}

public enum AddressingMode {
  
  case Absolute, AbsoluteX, AbsoluteY, Accumulator, Immediate, Implicit, Indirect, IndirectX, IndirectY, Relative,
    ZeroPage, ZeroPageX, ZeroPageY
}

public class OpCode {
  
  var name: OpCodeName;
  var code: Int;
  var addressingMode: AddressingMode;
  var size: Int;
  var cycles: Int;
  
  init (_ name: OpCodeName, _ code: Int, _ addressingMode: AddressingMode, _ size: Int, _ cycles: Int) {
    self.name = name;
    self.code = code;
    self.addressingMode = addressingMode;
    self.size = size;
    self.cycles = cycles;
  }
}