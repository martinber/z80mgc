/// Only emulates the 8x16 english characters and not the chinese 16x16 chars
/// Icon RAM not emulated because I don't even know if that thing exists, documentation is awful

use rand;
use crate::lcd_font::LCD_FONT;


/// Number of characters in a row
const TEXT_W: usize = 16;
/// Number of rows of characters
const TEXT_H: usize = 4;
/// Char width in pixels
const CHAR_W: usize = 8;
/// Char height in pixels
const CHAR_H: usize = 16;
/// Screen width in pixels
const SCREEN_W: usize = 128;
/// Screen height in pixels
const SCREEN_H: usize = 64;

/// Character Generator RAM. 4 * 16 * 16 bits for 8 double width chars of 16x16px
type CGRam = [u8; CGRAM_LENGTH];
const CGRAM_LENGTH: usize = 128;
                                                              //
/// Display Data RAM: 8 * 4 * 2 words of 16 bits. Each word represents two english characters or one
/// CGRAM character. 2 banks of 4 rows by 8 columns (where each column is two english characters).
/// Actually I say "2 banks" but there is no division within banks, you can scroll and display half
/// of each for example.
/// - Data codes 0x02-0x7F are for english chars
/// - Data codes 0x0000, 0x0002, 0x0004 and 0x0006 are for CGRAM. Must write 2 bytes per char, where
///   first byte is always 0x00. The full double width 16x16 char will be drawn at once
/// - Data codes 0xA140-0xD75F are for BIG5 code and 0xA1A0-0xF7FF are for GB code (2 bytes per char,
///   for chinese characters and not emulated)
type DDRam = [u16; DDRAM_LENGTH];
const DDRAM_LENGTH: usize = 64;
/// Address of each DDRAM line. First 4 are on first bank and the other 4 on second bank
const DDRAM_LINE_ADDR: [usize; 8] = [0x00, 0x10, 0x08, 0x18, 0x20, 0x30, 0x28, 0x38];

/// Graphic RAM: 128 * 64 * 2 bits, for two banks of 128x64px graphics
/// Actually I say "2 banks" but there is no division within banks, you can scroll and display half
/// of each for example.
type GRam = [u8; GRAM_LENGTH];
const GRAM_LENGTH: usize = 64;

/// Rendered screen: 128x64 pixels
type Screen = [bool; SCREEN_W * SCREEN_H];

/// Indicates where the next write/read instruction will operate
enum Memory {
    CGRam,
    DDRam,
    GRam,
}

pub struct MgcLcd {
    cgram: CGRam,
    ddram: DDRam,
    gram: GRam,

    /// RE bit according to documentation. true if using extended instruction set
    extended_instr: bool,

    /// Address Counter AC
    address_counter: usize,

    /// I/D according to documentation. true if cursor moves right or bool if moves left
    direction_right: bool,

    /// Shift entire display on write
    shift_on: bool,

    display_on: bool,
    cursor_on: bool,
    blink_on: bool,
    graphic_on: bool,

    /// True if using 8bit interface or false for 4bit
    parallel_8: bool,

    /// Where next write/read operation will take place
    curr_memory: Memory,

    /// After setting the address, an extra dummy read is necessary. No need of something similar for writing
    dummy_read_necessary: bool,

    /// Byte writes should always come in pairs, similar for reads
    second_rw: bool,
}

impl MgcLcd {
    pub fn new() -> MgcLcd {
        let mut lcd = MgcLcd {
            cgram: [0x00; CGRAM_LENGTH],
            ddram: [0x2020; DDRAM_LENGTH],
            gram: [0x00; GRAM_LENGTH],
            extended_instr: false,
            address_counter: 0,
            direction_right: true,
            shift_on: false,
            display_on: false,
            cursor_on: false,
            blink_on: false,
            graphic_on: false,
            parallel_8: true,
            curr_memory: Memory::DDRam,
            dummy_read_necessary: false,
            second_rw: false,
        };
        // On my LCD, I observed that GRAM has random stuff when turned on
        for byte in lcd.gram.iter_mut() {
            *byte = rand::random::<u8>();
        }

        return lcd;
    }

    pub fn draw(&self, screen: &mut Screen) {
        for x in 0..TEXT_W {
            for y in 0..TEXT_H {

                let ddram_addr: usize = DDRAM_LINE_ADDR[y] + x / 2;
                let ddram_byte = match x % 2 {
                    0 => (self.ddram[ddram_addr] & 0xFF00) >> 8,
                    1 => self.ddram[ddram_addr] & 0x00FF,
                    _ => unreachable!(),
                };
                // let ddram_word: u8 = self.ddram[(DDRAM_LINE_ADDR[y] + x) as usize]
                // let character: usize = self.ddram[(DDRAM_LINE_ADDR[y] + x) as usize] as usize;

                for char_px_x in 0..CHAR_W {
                    for char_px_y in 0..CHAR_H {
                        let screen_px_x = x * CHAR_W + char_px_x;
                        let screen_px_y = y * CHAR_H + char_px_y;
                        screen[screen_px_x + screen_px_y * SCREEN_W]
                            = LCD_FONT[ddram_byte as usize][char_px_y] & (0b10000000 >> char_px_x) != 0;
                    }
                }


            }
        }



        // let mut text: String = String::from("");
        //
        // // TODO: Handle second bank correctly
        // for y in 0..4 {
        //     if y > 0 {
        //         text.push('\n');
        //     }
        //     for x in 0..8 {
        //         let word: u16 = self.ddram[CGRAM_LINE_ADDR[y] + x];
        //         text.push(char::from_u32(((word & 0xFF00) >> 8) as u32).unwrap());
        //         text.push(char::from_u32((word & 0x00FF) as u32).unwrap());
        //     }
        // }
    }

    /// Send command or data to LCD.
    ///
    /// Which means, emulate what happens when enabling the LCD.
    /// Pin RW set to 0 is for writing, and pin RS set to 0 is for instructions.
    pub fn run(&mut self, rs: bool, rw: bool, data: u8) -> Option<u8> {

        match (self.extended_instr, rs, rw) {

            (false, false, false) => { // Standard instruction set, write instructions

                if data == 0b0000_0001 {
                    // Clear
                    for word in self.ddram.iter_mut() {
                        *word = 0x2020; // Wto 0x20 chars
                    }
                    self.address_counter = 0;
                } else if (data & 0b1111_1110) == 0b0000_0010 {
                    // Home
                    self.address_counter = 0;
                } else if (data & 0b1111_1100) == 0b0000_0100 {
                    // Set direction and shift
                    self.direction_right = data & 0b0000_0010 != 0;
                    self.shift_on = data & 0b0000_0001 != 0;
                } else if (data & 0b1111_1000) == 0b0000_1000 {
                    // Display on/off
                    self.display_on = data & 0b0000_0100 != 0;
                    self.cursor_on = data & 0b0000_0010 != 0;
                    self.blink_on = data & 0b0000_0001 != 0;
                } else if (data & 0b1111_0000) == 0b0001_0000 {
                    // Move cursor and shift
                    let move_right = data & 0b0000_0100 != 0;
                    let shift_display = data & 0b0000_1000 != 0;
                    if shift_display {
                        unimplemented!("Shift display and move cursor to follow shift")
                    } else {
                        if move_right {
                            self.address_counter = self.address_counter.wrapping_add(1);
                        } else {
                            self.address_counter = self.address_counter.wrapping_sub(1);
                        }
                    }
                } else if (data & 0b1110_0000) == 0b0010_0000 {
                    // Set extended mode
                    let new_mode: bool = data & 0b0000_0100 != 0;
                    if new_mode != self.extended_instr {
                        // Change mode and do nothing else
                        self.extended_instr = new_mode;
                    } else {
                        // Set other values
                        self.parallel_8 = data & 0b0001_0000 != 0;
                        if !self.parallel_8 {
                            unimplemented!("4bit interface");
                        }
                    }
                } else if (data & 0b1100_0000) == 0b0100_0000 {
                    // Set CGRAM address
                    // Not sure if modifies address_counter or if it is another address variable
                    self.address_counter = (data & 0b0011_1111) as usize;
                    self.curr_memory = Memory::CGRam;
                    self.dummy_read_necessary = true;
                    assert!(self.address_counter <= 0x3F); // Documentation says this
                    // assert!(self.s_address == false); // Documentation says this
                    unimplemented!("s_address");
                } else if (data & 0b1000_0000) == 0b1000_0000 {
                    // Set DDRAM address
                    // Not sure if modifies address_counter or if it is another address variable
                    self.address_counter = (data & 0b0011_1111) as usize;
                    self.curr_memory = Memory::DDRam;
                    self.dummy_read_necessary = true;
                    self.second_rw = false;
                    assert!(
                        (0x00 <= self.address_counter && self.address_counter <= 0x07) // Line 1
                        || (0x10 <= self.address_counter && self.address_counter <= 0x17) // Line 2
                        || (0x08 <= self.address_counter && self.address_counter <= 0x0F) // Line 3
                        || (0x18 <= self.address_counter && self.address_counter <= 0x1F) // Line 4
                    );
                }

                return None;
            },
            (true, false, false) => { // Extended instruction set, write instructions

                if data == 0b0000_0001 {
                    // Stand by
                    unimplemented!("Stand by");
                } else if (data & 0b1111_1110) == 0b0000_0010 {
                    // Vertical scroll position
                    unimplemented!("Vertical scroll position");
                } else if (data & 0b1111_1100) == 0b0000_0100 {
                    // Reverse
                    unimplemented!("Reverse line");
                } else if (data & 0b1111_1000) == 0b0000_1000 {
                    // Display on/off, same as basic instruction set?
                    self.display_on = data & 0b0000_0100 != 0;
                    self.cursor_on = data & 0b0000_0010 != 0;
                    self.blink_on = data & 0b0000_0001 != 0;
                    print!("Warning, not sure if this LCD instruction exists");
                } else if (data & 0b1111_0000) == 0b0001_0000 {
                    // Move cursor and shift
                    let move_right = data & 0b0000_0100 != 0;
                    let shift_display = data & 0b0000_1000 != 0;
                    if shift_display {
                        unimplemented!("Shift display and move cursor to follow shift")
                    } else {
                        if move_right {
                            self.address_counter = self.address_counter.wrapping_add(1);
                        } else {
                            self.address_counter = self.address_counter.wrapping_sub(1);
                        }
                    }
                    print!("Warning, not sure if this LCD instruction exists");
                } else if (data & 0b1110_0000) == 0b0010_0000 {
                    // Set extended mode
                    let new_mode: bool = data & 0b0000_0100 != 0;
                    if new_mode != self.extended_instr {
                        // Change mode and do nothing else
                        self.extended_instr = new_mode;
                    } else {
                        // Set other values
                        self.parallel_8 = data & 0b0001_0000 != 0;
                        self.graphic_on = data & 0b0000_0010 != 0;
                        if !self.parallel_8 {
                            unimplemented!("4bit interface");
                        }
                    }
                } else if (data & 0b1100_0000) == 0b0100_0000 {
                    unimplemented!("s_address");
                } else if (data & 0b1000_0000) == 0b1000_0000 {
                    // Set GRAM address
                    unimplemented!("GRAM address");
                }

                return None;
            },
            (false, false, true) => { // Standard instruction set, read instruction
                let result = self.address_counter;
                // Not setting the BUSY flag
                return Some(result as u8);
            },
            (true, false, true) => { // Extended instruction set, read instruction
                let result = self.address_counter;
                // Not setting the BUSY flag
                return Some(result as u8);
            },
            (_, true, false) => { // Any instruction set, write data
                let mut word: u16 = match self.curr_memory {
                    Memory::DDRam => self.ddram[self.address_counter],
                    _ => unimplemented!("Reading other memories"),
                };

                if self.second_rw { // Put data in less significative bits
                    word &= 0xFF00;
                    word |= data as u16;
                } else { // Put data in most significative bits
                    word &= 0x00FF;
                    word |= (data as u16) << 8;
                }

                match self.curr_memory {
                    Memory::DDRam => self.ddram[self.address_counter] = word,
                    _ => unimplemented!("Writing other memories"),
                }

                if self.direction_right {
                    if self.second_rw {
                        self.address_counter = self.address_counter.wrapping_add(1);
                    }
                    if self.shift_on {
                        unimplemented!("Shift everything left");
                    }
                } else {
                    if self.second_rw {
                        self.address_counter = self.address_counter.wrapping_sub(1);
                    }
                    if self.shift_on {
                        unimplemented!("Shift everything right");
                    }
                }
                self.second_rw = !self.second_rw;

                return None;
            },
            (_, true, true) => { // Any instruction set, read data

                let word: u16 = match self.curr_memory {
                    Memory::DDRam => self.ddram[self.address_counter],
                    _ => unimplemented!("Reading other memories"),
                };

                let result: u8 = match self.second_rw {
                    true => word as u8,
                    false => (word >> 8) as u8,
                };

                if self.second_rw {
                    if self.direction_right {
                        self.address_counter = self.address_counter.wrapping_add(1);
                    } else {
                        self.address_counter = self.address_counter.wrapping_sub(1);
                    }
                }
                self.second_rw = !self.second_rw;

                return Some(result);
            }
        }
    }
}
