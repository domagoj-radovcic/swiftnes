//
//  ViewController.swift
//  SwiftNES
//
//  Created by Domagoj Radovčić on 20/04/16.
//  Copyright © 2016 Domagoj Radovcic. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
  
  let cpu: CPU = CPU();
  let cartridge: Cartridge = Cartridge();

  override func viewDidLoad() {
    super.viewDidLoad();
    cartridge.setCpu(cpu);
    var i = 0;
    if (cartridge.loadCartridge()) {
      repeat {
        cpu.emulate();
        i++;
        if (i == 8991) {
          exit(0);
        }
      } while (true);
    }
  }

  override var representedObject: AnyObject? {
    didSet {
    // Update the view, if already loaded.
    }
  }


}

