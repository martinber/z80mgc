use iz80::Machine;
use crate::lcd;
// use gio::prelude::*;
// use gdk::prelude::*;


pub const DEBUG_ADDR: usize = 0x8000; // Location of debug flag in RAM


pub struct MgcMachine {
    pub mem: [u8; 65536],
    pub lcd: lcd::MgcLcd,
    pub clicked_up: bool,
    pub clicked_down: bool,
    pub clicked_left: bool,
    pub clicked_right: bool,
}

impl MgcMachine {
    pub fn new() -> MgcMachine {
        MgcMachine {
            mem: [0; 65536],
            lcd: lcd::MgcLcd::new(),
            clicked_up: false,
            clicked_down: false,
            clicked_left: false,
            clicked_right: false,
        }
    }
}

impl Machine for MgcMachine {
    fn peek(&self, address: u16) -> u8 {
        self.mem[address as usize]
    }
    fn poke(&mut self, address: u16, value: u8) {
        self.mem[address as usize] = value;
    }

    fn port_in(&mut self, address: u16) -> u8 {
        if (address & 0b0000_0000_1110_0000) == 0b0000_0000_0000_0000
        {
            let mut out: u8 = 0b00000000;
            if self.clicked_up {
                out |= 0b00000001;
            }
            if self.clicked_down {
                out |= 0b00000010;
            }
            if self.clicked_left {
                out |= 0b00000100;
            }
            if self.clicked_right {
                out |= 0b00001000;
            }
            return out;
        }
        else if (address & 0b0000_0000_1110_0000) == 0b0000_0000_1000_0000 {
            return self.lcd.run(
                address & 0b0001 != 0,
                address & 0b0010 != 0,
                0,
            ).expect("LCD returned None");
        } else {
            unreachable!("No devices on this port: {:?}", address);
        }
    }

    fn port_out(&mut self, address: u16, value: u8) {
        if (address & 0b0000_0000_1110_0000) == 0b0000_0000_1000_0000 {
            self.lcd.run(
                address & 0b0001 != 0,
                address & 0b0010 != 0,
                value,
            );
        } else {
            unreachable!("No devices on this port: {:?}", address);
        }
    }
}
