//
//  CPU.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 20/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

import Foundation;

public class CPU {
  
  // registers
  var PC: Int;
  var SP: Int;
  var REG_X: Int;
  var REG_Y: Int;
  var REG_A: Int;
  
  // status flags
  var F_Negative: Int;
  var F_Overflow: Int;
  var F_Unused: Int;
  var F_Break: Int;
  var F_Decimal: Int;
  var F_InterruptDisable: Int;
  var F_Zero: Int;
  var F_Carry: Int;
  
  // ram
  var ram: RAM;
  
  // opcodes
  var cycles: Int;
  var instructionCount: Int;
  var opcodeList: [OpCode?];
  
  var address: Int;
  var currentOpcode: OpCode?;

  init () {
    PC = 0xC000;
    SP = 0xFD;
    REG_A = 0;
    REG_X = 0;
    REG_Y = 0;
    F_Carry = (0x24 >> 0) & 1;
    F_Zero = (0x24 >> 1) & 1;
    F_InterruptDisable = (0x24 >> 2) & 1;
    F_Decimal = (0x24 >> 3) & 1;
    F_Break = (0x24 >> 4) & 1;
    F_Unused = 1;
    F_Overflow = (0x24 >> 6) & 1;
    F_Negative = (0x24 >> 7) & 1;
    ram = RAM();
    cycles = 0;
    instructionCount = 0;
    for (var i = 0x0000; i <= 0x07FF; i++) {
      ram.write(i, 0xFF);
      if (i == 0x0008) { ram.write(i, 0xF7); }
      if (i == 0x0009) { ram.write(i, 0xEF); }
      if (i == 0x000A) { ram.write(i, 0xDF); }
      if (i == 0x000F) { ram.write(i, 0xBF); }
    }
    ram.write(0x4017, 0x00);
    ram.write(0x4015, 0x00);
    for (var i = 0x4000; i <= 0x400F; i++) {
      ram.write(i, 0x00);
    }
    opcodeList = [OpCode?](count: 0x100, repeatedValue: nil);
    address = 0x0000;
    currentOpcode = nil;
    generateOpCodes();
  }
  
  func emulate () {
    currentOpcode = opcodeList[ram.read8(PC)];
    log();
    executeOpCode();
    cycles += currentOpcode!.cycles;
    PC += currentOpcode!.size;
    instructionCount++;
  }
  
  func log() {
    print("\(currentOpcode!.name) A:\(String(format:"%02X", REG_A)) X:\(String(format:"%02X", REG_X))" +
      " Y:\(String(format:"%02X", REG_Y)) P:\(String(format:"%02X", getStatusFlags())) SP:\(String(format:"%02X", SP))");
  }
  
  func getAddress () -> Int {
    address = 0x0000;
    if let addresingMode = currentOpcode?.addressingMode {
      switch addresingMode {
      case .Absolute:
        address = ram.read16(PC + 1);
        break;
      case .AbsoluteX:
        address = ram.read16(PC + 1);
        if (checkPageCross(address, address + REG_X)) {
          cycles += 1;
        }
        address += REG_X;
        break;
      case .AbsoluteY:
        address = ram.read16(PC + 1);
        if (checkPageCross(address, address + REG_Y)) {
          cycles += 1;
        }
        address += REG_Y;
        break;
      case .Accumulator:
        address = REG_A;
        break;
      case .Immediate:
        address = PC + 1;
        break;
      case .Implicit:
        break;
      case .Indirect:
        var highByte = ram.read8(PC + 1);
        var lowByte = ram.read8(PC + 2);
        address = (lowByte << 8) | highByte;
        if (checkPageCross(address, address + 1)) {
          lowByte = (address << 8 + 1) & 0xFF;
          highByte = address & 0xFF00;
          address = (lowByte << 8) | highByte;
        } else {
          address = ram.read16(address);
        }
        break;
      case .IndirectX:
        address = ram.read8(PC + 1) + REG_X;
        address &= 0xFF;
        if (checkPageCross(address, address + 1)) {
          address = ram.read16WithBug(address);
        } else {
          address = ram.read16(address);
        }
        break;
      case .IndirectY:
        address = ram.read8(PC + 1);
        address &= 0xFF;
        if (checkPageCross(address, address + 1)) {
          address = ram.read16WithBug(address);
        } else {
          address = ram.read16(address);
        }
        if (checkPageCross(address, address + REG_Y)) {
          cycles += 1;
        }
        address += REG_Y;
        break;
      case .Relative:
        let offset = ram.read8(PC + 1);
        if (offset < 0x80) {
          address = PC + offset;
        } else {
          address = PC + offset - 0x100;
        }
        break;
      case .ZeroPage:
        address = ram.read8(PC + 1);
        break;
      case .ZeroPageX:
        address = ram.read8(PC + 1) + REG_X;
        address &= 0xFF;
        break;
      case .ZeroPageY:
        address = ram.read8(PC + 1) + REG_Y;
        address &= 0xFF;
        break;
      }
    }
    
    address &= 0xFFFF;
    return address;
  }
  
  func executeOpCode () {
    let address = getAddress();
    var temp = 0, oldCarryFlag = 0;
    if let opCodeName = currentOpcode?.name {
      switch opCodeName {
      case .AAC: // AND byte with accumulator. If result is negative then carry is set. Status flags: N,Z,C
        temp = ram.read8(address) & REG_A;
        temp &= 0xFF;
        updateNegativeFlag(temp);
        updateZeroFlag(temp);
        if (F_Negative == 1) {
          F_Carry = 1;
        }
        break;
      case .AAX: // ANDs the contents of the A and X registers (without changing the
        // contents of either register) and stores the result in memory.
        // AXS does not affect any flags in the processor status register.
        temp = REG_X & REG_A;
        temp &= 0xFF;
        ram.write(address, temp);
        break;
      case .ADC: // Add with Carry
        temp = ram.read8(address) + REG_A + F_Carry;
        F_Overflow = ((REG_A ^ temp) & (ram.read8(address) ^ temp) & 0x80) != 0 ? 1 : 0;
        updateCarryFlag(temp);
        REG_A = temp & 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .AND: // Logical AND
        REG_A = ram.read8(address) & REG_A;
        REG_A &= 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .ARR:
        break;
      case .ASL: // Arithmetic Shift Left
        if (currentOpcode?.addressingMode == AddressingMode.Accumulator) {
          F_Carry = (REG_A >> 7) & 1;
          REG_A = (REG_A << 1);
          REG_A &= 0xFF;
          updateZeroFlag(REG_A);
          updateNegativeFlag(REG_A);
        } else {
          F_Carry = (ram.read8(address) >> 7) & 1;
          temp = (ram.read8(address) << 1);
          temp &= 0xFF;
          updateZeroFlag(temp);
          updateNegativeFlag(temp);
          ram.write(address, temp);
        }
        break;
      case .ASR:
        break;
      case .ATX: // ORs the A register with #$EE, ANDs the result with an immediate value, and then stores the result in both A and X.
        temp = REG_A | 0xEE;
        temp &= ram.read8(address);
        temp &= 0xFF;
        REG_A &= temp;
        REG_X &= temp;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .AXA:
        break;
      case .AXS:
        break;
      case .BCC: // Branch if Carry Clear
        if (F_Carry == 0) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BCS: // Branch if Carry Set
        if (F_Carry == 1) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BEQ: // Branch if Equal
        if (F_Zero == 1) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BIT: // Bit Test
        temp = ram.read8(address) & REG_A;
        updateZeroFlag(temp);
        F_Overflow = (ram.read8(address) >> 6) & 1;
        F_Negative = (ram.read8(address) >> 7) & 1;
        break;
      case .BMI: // Branch if Minus
        if (F_Negative == 1) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BNE: // Branch if Not Equal
        if (F_Zero == 0) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BPL: // Branch if Positive
        if (F_Negative == 0) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BRK: // Force Interrupt
        break;
      case .BVC: // Branch if Overflow Clear
        if (F_Overflow == 0) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .BVS: // Branch if Overflow Set
        if (F_Overflow == 1) {
          if (checkPageCross(PC, address)) {
            cycles += 2;
          } else {
            cycles += 1;
          }
          PC = address;
        }
        break;
      case .CLC: // Clear Carry Flag
        F_Carry = 0;
        break;
      case .CLD: // Clear Decimal Mode
        F_Decimal = 0;
        break;
      case .CLI: // Clear Interrupt Disable
        F_InterruptDisable = 0;
        break;
      case .CLV: // Clear Overflow Flag
        F_Overflow = 0;
        break;
      case .CMP: // Compare
        temp = REG_A - ram.read8(address);
        F_Carry = temp >= 0 ? 1 : 0;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        break;
      case .CPX: // Compare X Register
        temp = REG_X - ram.read8(address);
        F_Carry = temp >= 0 ? 1 : 0;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        break;
      case .CPY: // Compare Y Register
        temp = REG_Y - ram.read8(address);
        F_Carry = temp >= 0 ? 1 : 0;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        break;
      case .DCP: // Subtract 1 from memory (without borrow).
        temp = ram.read8(address) - 1;
        temp &= 0xFF;
        ram.write(address, temp);
        temp = REG_A - ram.read8(address);
        F_Carry = temp >= 0 ? 1 : 0;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        break;
      case .DEC: // Decrement Memory
        temp = ram.read8(address) - 1;
        temp &= 0xFF;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        ram.write(address, temp);
        break;
      case .DEX: // Decrement X Register
        REG_X -= 1;
        REG_X &= 0xFF;
        updateZeroFlag(REG_X);
        updateNegativeFlag(REG_X);
        break;
      case .DEY: // Decrement Y Register
        REG_Y -= 1;
        REG_Y &= 0xFF;
        updateZeroFlag(REG_Y);
        updateNegativeFlag(REG_Y);
        break;
      case .DOP: // Double No Operation - ILLEGAL
        break;
      case .EOR: // Exclusive OR
        REG_A = REG_A ^ ram.read8(address);
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .INC: // Increment Memory
        temp = ram.read8(address) + 1;
        temp &= 0xFF;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        ram.write(address, temp);
        break;
      case .INX: // Increment X Register
        REG_X += 1;
        REG_X &= 0xFF;
        updateZeroFlag(REG_X);
        updateNegativeFlag(REG_X);
        break;
      case .INY: // Increment Y Register
        REG_Y += 1;
        REG_Y &= 0xFF;
        updateZeroFlag(REG_Y);
        updateNegativeFlag(REG_Y);
        break;
      case .ISC: // Increase memory by one, then subtract memory from accu-mulator (with borrow). Status flags: N,V,Z,C
        temp = ram.read8(address) + 1;
        temp &= 0xFF;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        ram.write(address, temp);
        temp = REG_A - ram.read8(address) - (1 - F_Carry);
        F_Overflow = (((REG_A ^ ram.read8(address)) & 0x80) != 0) && (((REG_A ^ temp) & 0x80) != 0) ? 1 : 0;
        F_Carry = temp >= 0 ? 1 : 0;
        REG_A = temp & 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .JMP: // Jump
        PC = address;
        PC -= currentOpcode!.size;
        break;
      case .JSR: // Jump to Subroutine
        temp = PC + currentOpcode!.size - 1;
        ram.pushToStack(self, (temp >> 8) & 0xFF);
        ram.pushToStack(self, temp & 0xFF);
        PC = address;
        PC -= currentOpcode!.size;
        break;
      case .KIL:
        break;
      case .LAR:
        break;
      case .LAX: // Load accumulator and X register with memory. Status flags: N,Z
        REG_A = ram.read8(address);
        REG_X = REG_A;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .LDA: // Load Accumulator
        REG_A = ram.read8(address);
        REG_A &= 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .LDX: // Load X Register
        REG_X = ram.read8(address);
        REG_X &= 0xFF;
        updateZeroFlag(REG_X);
        updateNegativeFlag(REG_X);
        break;
      case .LDY: // Load Y Register
        REG_Y = ram.read8(address);
        REG_Y &= 0xFF;
        updateZeroFlag(REG_Y);
        updateNegativeFlag(REG_Y);
        break;
      case .LSR: // Logical Shift Right
        if (currentOpcode?.addressingMode == AddressingMode.Accumulator) {
          F_Carry = (REG_A >> 0) & 1;
          REG_A = (REG_A >> 1);
          REG_A = REG_A & 0xFF;
          updateZeroFlag(REG_A);
          updateNegativeFlag(REG_A);
        } else {
          F_Carry = (ram.read8(address) >> 0) & 1;
          temp = (ram.read8(address) >> 1);
          temp &= 0xFF;
          updateZeroFlag(temp);
          updateNegativeFlag(temp);
          ram.write(address, temp);
        }
        break;
      case .NOP: // No Operation
        break;
      case .ORA: // Logical Inclusive OR
        REG_A |= ram.read8(address);
        REG_A &= 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .PHA: // Push Accumulator
        ram.pushToStack(self, REG_A);
        break;
      case .PHP: // Push Processor Status
        temp = getStatusFlags() ^ (1 << 4);
        ram.pushToStack(self, temp);
        break;
      case .PLA: // Pull Accumulator
        REG_A = ram.popFromStack(self);
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .PLP: // Pull Processor Status
        setStatusFlag(ram.popFromStack(self));
        break;
      case .RLA: // Rotate one bit left in memory, then AND accumulator with memory. Status flags: N,Z,C
        temp = ram.read8(address);
        oldCarryFlag = F_Carry;
        F_Carry = ((temp >> 7) & 1);
        temp = (temp << 1);
        temp = temp | ((oldCarryFlag >> 0) & 1);
        temp = temp & 0xFF;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        ram.write(address, temp);
        REG_A &= ram.read8(address);
        REG_A &= 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .ROL: // Rotate Left
        if (currentOpcode?.addressingMode == AddressingMode.Accumulator) {
          temp = REG_A;
          oldCarryFlag = F_Carry;
          F_Carry = ((temp >> 7) & 1);
          temp = (temp << 1);
          temp = temp | ((oldCarryFlag >> 0) & 1);
          REG_A = temp & 0xFF;
          updateZeroFlag(REG_A);
          updateNegativeFlag(REG_A);
        } else {
          temp = ram.read8(address);
          oldCarryFlag = F_Carry;
          F_Carry = ((temp >> 7) & 1);
          temp = (temp << 1);
          temp = temp | ((oldCarryFlag >> 0) & 1);
          temp = temp & 0xFF;
          updateZeroFlag(temp);
          updateNegativeFlag(temp);
          ram.write(address, temp);
        }
        break;
      case .ROR: // Rotate Right
        if (currentOpcode?.addressingMode == AddressingMode.Accumulator) {
          temp = REG_A;
          oldCarryFlag = F_Carry;
          F_Carry = ((temp >> 0) & 1);
          temp = (temp >> 1);
          temp = temp | (((oldCarryFlag >> 0) & 1) << 7);
          REG_A = temp & 0xFF;
          updateZeroFlag(REG_A);
          updateNegativeFlag(REG_A);
        } else {
          temp = ram.read8(address);
          oldCarryFlag = F_Carry;
          F_Carry = ((temp >> 0) & 1);
          temp = (temp >> 1);
          temp = temp | (((oldCarryFlag >> 0) & 1) << 7);
          temp = temp & 0xFF;
          updateZeroFlag(temp);
          updateNegativeFlag(temp);
          ram.write(address, temp);
        }
        break;
      case .RRA: // Rotate one bit right in memory, then add memory to accumulator (with carry).
        temp = ram.read8(address);
        oldCarryFlag = F_Carry;
        F_Carry = ((temp >> 0) & 1);
        temp = (temp >> 1);
        temp = temp | (((oldCarryFlag >> 0) & 1) << 7);
        temp = temp & 0xFF;
        updateZeroFlag(temp);
        updateNegativeFlag(temp);
        ram.write(address, temp);
        temp = ram.read8(address) + REG_A + F_Carry;
        F_Overflow = ((REG_A ^ temp) & (ram.read8(address) ^ temp) & 0x80) != 0 ? 1 : 0;
        updateCarryFlag(temp);
        REG_A = temp & 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .RTI: // Return from Interrupt
        setStatusFlag(ram.popFromStack(self));
        PC = ram.popFromStack(self) | ram.popFromStack(self) << 8;
        PC -= currentOpcode!.size;
        break;
      case .RTS: // Return from Subroutine
        PC = ram.popFromStack(self) | ram.popFromStack(self) << 8;
        break;
      case .SBC: // Subtract with Carry
        temp = REG_A - ram.read8(address) - (1 - F_Carry);
        F_Overflow = (((REG_A ^ ram.read8(address)) & 0x80) != 0) && (((REG_A ^ temp) & 0x80) != 0) ? 1 : 0;
        F_Carry = temp >= 0 ? 1 : 0;
        REG_A = temp & 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .SEC: // Set Carry Flag
        F_Carry = 1;
        break;
      case .SED: // Set Decimal Flag
        F_Decimal = 1;
        break;
      case .SEI: // Set Interrupt Disable
        F_InterruptDisable = 1;
        break;
      case .SLO: // Shift left one bit in memory, then OR accumulator with memory. Status flags: N,Z,C
        F_Carry = (ram.read8(address) >> 7) & 1;
        temp = (ram.read8(address) << 1);
        temp = temp & 0xFF;
        updateZeroFlag(ram.read8(address));
        updateNegativeFlag(ram.read8(address));
        ram.write(address, temp);
        REG_A |= ram.read8(address);
        REG_A &= 0xFF;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .SRE: // Shift right one bit in memory, then EOR accumulator with memory. Status flags: N,Z,C
        F_Carry = (ram.read8(address) >> 0) & 1;
        temp = (ram.read8(address) >> 1);
        temp = temp & 0xFF;
        updateZeroFlag(ram.read8(address));
        updateNegativeFlag(ram.read8(address));
        ram.write(address, temp);
        REG_A = REG_A ^ ram.read8(address);
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .STA: // Store Accumulator
        ram.write(address, REG_A);
        break;
      case .STX: // Store X Register
        ram.write(address, REG_X);
        break;
      case .STY: // Store Y Register
        ram.write(address, REG_Y);
        break;
      case .SXA:
        break;
      case .SYA:
        break;
      case .TAX: // Transfer Accumulator to X
        REG_X = REG_A;
        updateZeroFlag(REG_X);
        updateNegativeFlag(REG_X);
        break;
      case .TAY: // Transfer Accumulator to Y
        REG_Y = REG_A;
        updateZeroFlag(REG_Y);
        updateNegativeFlag(REG_Y);
        break;
      case .TOP: // Triple No Operation - ILLEGAL
        break;
      case .TSX: // Transfer Stack Pointer to X
        REG_X = SP;
        updateZeroFlag(REG_X);
        updateNegativeFlag(REG_X);
        break;
      case .TXA: // Transfer X to Accumulator
        REG_A = REG_X;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .TXS: // Transfer X to Stack Pointer
        SP = REG_X;
        break;
      case .TYA: // Transfer Y to Accumulator
        REG_A = REG_Y;
        updateZeroFlag(REG_A);
        updateNegativeFlag(REG_A);
        break;
      case .XAA:
        break;
      case .XAS:
        break;
      }
    }
  }
  
  func checkPageCross (address1: Int, _ address2: Int) -> Bool {
    return ((address1 & 0xFF00) != (address2 & 0xFF00));
  }
  
  func updateZeroFlag (value: Int) {
    F_Zero = (value == 0 ? 1 : 0);
  }
  
  func updateCarryFlag (value: Int) {
    F_Carry = (value > 0xFF ? 1 : 0);
  }
  
  func updateNegativeFlag (value: Int) {
    F_Negative = ((value & 0x80) != 0 ? 1 : 0);
  }
  
  func setStatusFlag (value: Int) {
    F_Carry = (value >> 0) & 1;
    F_Zero = (value >> 1) & 1;
    F_InterruptDisable = (value >> 2) & 1;
    F_Decimal = (value >> 3) & 1;
    F_Unused = 1;
    F_Overflow = (value >> 6) & 1;
    F_Negative = (value >> 7) & 1;
  }
  
  func getStatusFlags () -> Int {
    return F_Carry | (F_Zero << 1) | (F_InterruptDisable << 2) | (F_Decimal << 3) | (F_Break << 4) | (1 << 5) |
      (F_Overflow << 6) | (F_Negative << 7);
  }
  
  func decrementSP () {
    SP--;
    SP &= 0xFF;
  }
  
  func incrementSP () {
    SP++;
    SP &= 0xFF;
  }
  
  func setOpCode (opcode: OpCode) {
		opcodeList[opcode.code] = opcode;
  }
  
  func generateOpCodes() {
		// ADC
		setOpCode(OpCode(OpCodeName.ADC, 0x69, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.ADC, 0x65, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.ADC, 0x75, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.ADC, 0x6D, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.ADC, 0x7D, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.ADC, 0x79, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.ADC, 0x61, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.ADC, 0x71, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// AND
		setOpCode(OpCode(OpCodeName.AND, 0x29, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.AND, 0x25, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.AND, 0x35, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.AND, 0x2D, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.AND, 0x3D, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.AND, 0x39, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.AND, 0x21, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.AND, 0x31, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// ASL
		setOpCode(OpCode(OpCodeName.ASL, 0x0A, AddressingMode.Accumulator, 1, 2));
		setOpCode(OpCode(OpCodeName.ASL, 0x06, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.ASL, 0x16, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.ASL, 0x0E, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.ASL, 0x1E, AddressingMode.AbsoluteX, 3, 7));
  
		// BCC
		setOpCode(OpCode(OpCodeName.BCC, 0x90, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BCS
		setOpCode(OpCode(OpCodeName.BCS, 0xB0, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BEQ
		setOpCode(OpCode(OpCodeName.BEQ, 0xF0, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BIT
		setOpCode(OpCode(OpCodeName.BIT, 0x24, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.BIT, 0x2C, AddressingMode.Absolute, 3, 4));
  
		// BMI
		setOpCode(OpCode(OpCodeName.BMI, 0x30, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BNE
		setOpCode(OpCode(OpCodeName.BNE, 0xD0, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BPL
		setOpCode(OpCode(OpCodeName.BPL, 0x10, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BRK
		setOpCode(OpCode(OpCodeName.BRK, 0x00, AddressingMode.Implicit, 1, 7));
  
		// BVC
		setOpCode(OpCode(OpCodeName.BVC, 0x50, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// BVS
		setOpCode(OpCode(OpCodeName.BVS, 0x70, AddressingMode.Relative, 2, 2)); // +1 if branch success +2 if to a new page
  
		// CLC
		setOpCode(OpCode(OpCodeName.CLC, 0x18, AddressingMode.Implicit, 1, 2));
  
		// CLD
		setOpCode(OpCode(OpCodeName.CLD, 0xD8, AddressingMode.Implicit, 1, 2));
  
		// CLI
		setOpCode(OpCode(OpCodeName.CLI, 0x58, AddressingMode.Implicit, 1, 2));
  
		// CLV
		setOpCode(OpCode(OpCodeName.CLV, 0xB8, AddressingMode.Implicit, 1, 2));
  
		// CMP
		setOpCode(OpCode(OpCodeName.CMP, 0xC9, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.CMP, 0xC5, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.CMP, 0xD5, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.CMP, 0xCD, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.CMP, 0xDD, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.CMP, 0xD9, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.CMP, 0xC1, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.CMP, 0xD1, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// CPX
		setOpCode(OpCode(OpCodeName.CPX, 0xE0, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.CPX, 0xE4, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.CPX, 0xEC, AddressingMode.Absolute, 3, 4));
  
		// CPY
		setOpCode(OpCode(OpCodeName.CPY, 0xC0, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.CPY, 0xC4, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.CPY, 0xCC, AddressingMode.Absolute, 3, 4));
  
		// DEC
		setOpCode(OpCode(OpCodeName.DEC, 0xC6, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.DEC, 0xD6, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.DEC, 0xCE, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.DEC, 0xDE, AddressingMode.AbsoluteX, 3, 7));
  
		// DEX
		setOpCode(OpCode(OpCodeName.DEX, 0xCA, AddressingMode.Implicit, 1, 2));
  
		// DEY
		setOpCode(OpCode(OpCodeName.DEY, 0x88, AddressingMode.Implicit, 1, 2));
  
		// EOR
		setOpCode(OpCode(OpCodeName.EOR, 0x49, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.EOR, 0x45, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.EOR, 0x55, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.EOR, 0x4D, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.EOR, 0x5D, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.EOR, 0x59, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.EOR, 0x41, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.EOR, 0x51, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// INC
		setOpCode(OpCode(OpCodeName.INC, 0xE6, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.INC, 0xF6, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.INC, 0xEE, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.INC, 0xFE, AddressingMode.AbsoluteX, 3, 7));
  
		// INX
		setOpCode(OpCode(OpCodeName.INX, 0xE8, AddressingMode.Implicit, 1, 2));
  
		// INY
		setOpCode(OpCode(OpCodeName.INY, 0xC8, AddressingMode.Implicit, 1, 2));
  
		// JMP
		setOpCode(OpCode(OpCodeName.JMP, 0x4C, AddressingMode.Absolute, 3, 3));
		setOpCode(OpCode(OpCodeName.JMP, 0x6C, AddressingMode.Indirect, 3, 5));
  
		// JSR
		setOpCode(OpCode(OpCodeName.JSR, 0x20, AddressingMode.Absolute, 3, 6));
  
		// LDA
		setOpCode(OpCode(OpCodeName.LDA, 0xA9, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.LDA, 0xA5, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.LDA, 0xB5, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.LDA, 0xAD, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.LDA, 0xBD, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.LDA, 0xB9, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.LDA, 0xA1, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.LDA, 0xB1, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// LDX
		setOpCode(OpCode(OpCodeName.LDX, 0xA2, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.LDX, 0xA6, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.LDX, 0xB6, AddressingMode.ZeroPageY, 2, 4));
		setOpCode(OpCode(OpCodeName.LDX, 0xAE, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.LDX, 0xBE, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
  
		// LDY
		setOpCode(OpCode(OpCodeName.LDY, 0xA0, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.LDY, 0xA4, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.LDY, 0xB4, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.LDY, 0xAC, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.LDY, 0xBC, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
  
		// LSR
		setOpCode(OpCode(OpCodeName.LSR, 0x4A, AddressingMode.Accumulator, 1, 2));
		setOpCode(OpCode(OpCodeName.LSR, 0x46, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.LSR, 0x56, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.LSR, 0x4E, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.LSR, 0x5E, AddressingMode.AbsoluteX, 3, 7));
  
		// NOP
		setOpCode(OpCode(OpCodeName.NOP, 0xEA, AddressingMode.Implicit, 1, 2));
  
		// ORA
		setOpCode(OpCode(OpCodeName.ORA, 0x09, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.ORA, 0x05, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.ORA, 0x15, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.ORA, 0x0D, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.ORA, 0x1D, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.ORA, 0x19, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.ORA, 0x01, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.ORA, 0x11, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// PHA
		setOpCode(OpCode(OpCodeName.PHA, 0x48, AddressingMode.Implicit, 1, 3));
  
		// PHP
		setOpCode(OpCode(OpCodeName.PHP, 0x08, AddressingMode.Implicit, 1, 3));
  
		// PLA
		setOpCode(OpCode(OpCodeName.PLA, 0x68, AddressingMode.Implicit, 1, 4));
  
		// PLP
		setOpCode(OpCode(OpCodeName.PLP, 0x28, AddressingMode.Implicit, 1, 4));
  
		// ROL
		setOpCode(OpCode(OpCodeName.ROL, 0x2A, AddressingMode.Accumulator, 1, 2));
		setOpCode(OpCode(OpCodeName.ROL, 0x26, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.ROL, 0x36, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.ROL, 0x2E, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.ROL, 0x3E, AddressingMode.AbsoluteX, 3, 7));
  
		// ROR
		setOpCode(OpCode(OpCodeName.ROR, 0x6A, AddressingMode.Accumulator, 1, 2));
		setOpCode(OpCode(OpCodeName.ROR, 0x66, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.ROR, 0x76, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.ROR, 0x6E, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.ROR, 0x7E, AddressingMode.AbsoluteX, 3, 7));
  
		// RTI
		setOpCode(OpCode(OpCodeName.RTI, 0x40, AddressingMode.Implicit, 1, 6));
  
		// RTS
		setOpCode(OpCode(OpCodeName.RTS, 0x60, AddressingMode.Implicit, 1, 6));
  
		// SBC
		setOpCode(OpCode(OpCodeName.SBC, 0xE9, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.SBC, 0xE5, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.SBC, 0xF5, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.SBC, 0xED, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.SBC, 0xFD, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.SBC, 0xF9, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.SBC, 0xE1, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.SBC, 0xF1, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// SEC
		setOpCode(OpCode(OpCodeName.SEC, 0x38, AddressingMode.Implicit, 1, 2));
  
		// SED
		setOpCode(OpCode(OpCodeName.SED, 0xF8, AddressingMode.Implicit, 1, 2));
  
		// SEI
		setOpCode(OpCode(OpCodeName.SEI, 0x78, AddressingMode.Implicit, 1, 2));
  
		// STA
		setOpCode(OpCode(OpCodeName.STA, 0x85, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.STA, 0x95, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.STA, 0x8D, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.STA, 0x9D, AddressingMode.AbsoluteX, 3, 5));
		setOpCode(OpCode(OpCodeName.STA, 0x99, AddressingMode.AbsoluteY, 3, 5));
		setOpCode(OpCode(OpCodeName.STA, 0x81, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.STA, 0x91, AddressingMode.IndirectY, 2, 6));
  
		// STX
		setOpCode(OpCode(OpCodeName.STX, 0x86, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.STX, 0x96, AddressingMode.ZeroPageY, 2, 4));
		setOpCode(OpCode(OpCodeName.STX, 0x8E, AddressingMode.Absolute, 3, 4));
  
		// STY
		setOpCode(OpCode(OpCodeName.STY, 0x84, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.STY, 0x94, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.STY, 0x8C, AddressingMode.Absolute, 3, 4));
  
		// TAX
		setOpCode(OpCode(OpCodeName.TAX, 0xAA, AddressingMode.Implicit, 1, 2));
  
		// TAY
		setOpCode(OpCode(OpCodeName.TAY, 0xA8, AddressingMode.Implicit, 1, 2));
  
		// TSX
		setOpCode(OpCode(OpCodeName.TSX, 0xBA, AddressingMode.Implicit, 1, 2));
  
		// TXA
		setOpCode(OpCode(OpCodeName.TXA, 0x8A, AddressingMode.Implicit, 1, 2));
  
		// TXS
		setOpCode(OpCode(OpCodeName.TXS, 0x9A, AddressingMode.Implicit, 1, 2));
  
		// TYA
		setOpCode(OpCode(OpCodeName.TYA, 0x98, AddressingMode.Implicit, 1, 2));
  
		// =====================================================================
		// ILLEGAL OPCODES
		// =====================================================================
		// AAC
		setOpCode(OpCode(OpCodeName.AAC, 0x0B, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.AAC, 0x2B, AddressingMode.Immediate, 2, 2));
  
		// AAX
		setOpCode(OpCode(OpCodeName.AAX, 0x87, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.AAX, 0x97, AddressingMode.ZeroPageY, 2, 4));
		setOpCode(OpCode(OpCodeName.AAX, 0x83, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.AAX, 0x8F, AddressingMode.Absolute, 3, 4));
  
		// ARR
		setOpCode(OpCode(OpCodeName.ARR, 0x6B, AddressingMode.Immediate, 2, 2));
  
		// ASR
		setOpCode(OpCode(OpCodeName.ASR, 0x4B, AddressingMode.Immediate, 2, 2));
  
		// ATX
		setOpCode(OpCode(OpCodeName.ATX, 0xAB, AddressingMode.Immediate, 2, 2));
  
		// AXA
		setOpCode(OpCode(OpCodeName.AXA, 0x9F, AddressingMode.AbsoluteY, 3, 5));
		setOpCode(OpCode(OpCodeName.AXA, 0x93, AddressingMode.IndirectY, 2, 6));
  
		// AXS
		setOpCode(OpCode(OpCodeName.AXS, 0xCB, AddressingMode.Immediate, 2, 2));
  
		// DCP
		setOpCode(OpCode(OpCodeName.DCP, 0xC7, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.DCP, 0xD7, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.DCP, 0xCF, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.DCP, 0xDF, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.DCP, 0xDB, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.DCP, 0xC3, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.DCP, 0xD3, AddressingMode.IndirectY, 2, 8));
  
		// NOP - double NOP
		setOpCode(OpCode(OpCodeName.NOP, 0x04, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.NOP, 0x14, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0x34, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0x44, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.NOP, 0x54, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0x64, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.NOP, 0x74, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0x80, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0x82, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0x89, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0xC2, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0xD4, AddressingMode.ZeroPageX, 2, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0xE2, AddressingMode.Immediate, 2, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0xF4, AddressingMode.ZeroPageX, 2, 4));
  
		// ISC
		setOpCode(OpCode(OpCodeName.ISC, 0xE7, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.ISC, 0xF7, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.ISC, 0xEF, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.ISC, 0xFF, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.ISC, 0xFB, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.ISC, 0xE3, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.ISC, 0xF3, AddressingMode.IndirectY, 2, 8));
  
		// KIL
		setOpCode(OpCode(OpCodeName.KIL, 0x02, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x12, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x22, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x32, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x42, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x52, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x62, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x72, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0x92, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0xB2, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0xD2, AddressingMode.Implicit, 1, 0));
		setOpCode(OpCode(OpCodeName.KIL, 0xF2, AddressingMode.Implicit, 1, 0));
  
		// LAR
		setOpCode(OpCode(OpCodeName.LAR, 0xBB, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
  
		// LAX
		setOpCode(OpCode(OpCodeName.LAX, 0xA7, AddressingMode.ZeroPage, 2, 3));
		setOpCode(OpCode(OpCodeName.LAX, 0xB7, AddressingMode.ZeroPageY, 2, 4));
		setOpCode(OpCode(OpCodeName.LAX, 0xAF, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.LAX, 0xBF, AddressingMode.AbsoluteY, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.LAX, 0xA3, AddressingMode.IndirectX, 2, 6));
		setOpCode(OpCode(OpCodeName.LAX, 0xB3, AddressingMode.IndirectY, 2, 5)); // +1 if to a new page
  
		// NOP
		setOpCode(OpCode(OpCodeName.NOP, 0x1A, AddressingMode.Implicit, 1, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0x3A, AddressingMode.Implicit, 1, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0x5A, AddressingMode.Implicit, 1, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0x7A, AddressingMode.Implicit, 1, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0xDA, AddressingMode.Implicit, 1, 2));
		setOpCode(OpCode(OpCodeName.NOP, 0xFA, AddressingMode.Implicit, 1, 2));
  
		// RLA
		setOpCode(OpCode(OpCodeName.RLA, 0x27, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.RLA, 0x37, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.RLA, 0x2F, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.RLA, 0x3F, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.RLA, 0x3B, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.RLA, 0x23, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.RLA, 0x33, AddressingMode.IndirectY, 2, 8));
  
		// RRA
		setOpCode(OpCode(OpCodeName.RRA, 0x67, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.RRA, 0x77, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.RRA, 0x6F, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.RRA, 0x7F, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.RRA, 0x7B, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.RRA, 0x63, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.RRA, 0x73, AddressingMode.IndirectY, 2, 8));
  
		// SBC
		setOpCode(OpCode(OpCodeName.SBC, 0xEB, AddressingMode.Immediate, 2, 2));
  
		// SLO
		setOpCode(OpCode(OpCodeName.SLO, 0x07, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.SLO, 0x17, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.SLO, 0x0F, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.SLO, 0x1F, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.SLO, 0x1B, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.SLO, 0x03, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.SLO, 0x13, AddressingMode.IndirectY, 2, 8));
  
		// SRE
		setOpCode(OpCode(OpCodeName.SRE, 0x47, AddressingMode.ZeroPage, 2, 5));
		setOpCode(OpCode(OpCodeName.SRE, 0x57, AddressingMode.ZeroPageX, 2, 6));
		setOpCode(OpCode(OpCodeName.SRE, 0x4F, AddressingMode.Absolute, 3, 6));
		setOpCode(OpCode(OpCodeName.SRE, 0x5F, AddressingMode.AbsoluteX, 3, 7));
		setOpCode(OpCode(OpCodeName.SRE, 0x5B, AddressingMode.AbsoluteY, 3, 7));
		setOpCode(OpCode(OpCodeName.SRE, 0x43, AddressingMode.IndirectX, 2, 8));
		setOpCode(OpCode(OpCodeName.SRE, 0x53, AddressingMode.IndirectY, 2, 8));
  
		// SXA
		setOpCode(OpCode(OpCodeName.SXA, 0x9E, AddressingMode.AbsoluteY, 3, 5));
  
		// SYA
		setOpCode(OpCode(OpCodeName.SYA, 0x9C, AddressingMode.AbsoluteY, 3, 5));
  
		// TOP - triple NOP
		setOpCode(OpCode(OpCodeName.NOP, 0x0C, AddressingMode.Absolute, 3, 4));
		setOpCode(OpCode(OpCodeName.NOP, 0x1C, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.NOP, 0x3C, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.NOP, 0x5C, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.NOP, 0x7C, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.NOP, 0xDC, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
		setOpCode(OpCode(OpCodeName.NOP, 0xFC, AddressingMode.AbsoluteX, 3, 4)); // +1 if to a new page
  
		// XAA
		setOpCode(OpCode(OpCodeName.XAA, 0x8B, AddressingMode.Immediate, 2, 2));
  
		// XAS
		setOpCode(OpCode(OpCodeName.XAS, 0x9B, AddressingMode.Immediate, 3, 5));
  }

}
