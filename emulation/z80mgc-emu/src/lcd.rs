/// Only emulates the 8x16 english characters and not the chinese 16x16 chars
/// Icon RAM not emulated because I don't even know if that thing exists, documentation is awful
/// After each instruction it always becomes busy until two read instructions are done. This
/// way, we force the z80 code to be correct and to always check the busy status

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
/// I think the address is just a unsigned number pointing to GRAM, that is incremented each time a
/// byte is written. The layout I think is:
///
/// Lines 0 to 31:
/// 0x000 0x001 0x002 0x003 0x004 0x005 0x006 0x007 0x008 0x009 0x00A 0x00B 0x00C 0x00D 0x00E 0x00F
/// 0x020 0x021 0x022 0x023 0x024 0x025 0x026 0x027 0x028 0x029 0x02A 0x02B 0x02C 0x02D 0x02E 0x02F
/// 0x040 0x041 0x042 0x043 0x044 0x045 0x046 0x047 0x048 0x049 0x04A 0x04B 0x04C 0x04D 0x04E 0x04F
/// ...
/// 0x3A0 0x3A1 0x3A2 0x3A3 0x3A4 0x3A5 0x3A6 0x3A7 0x3A8 0x3A9 0x3AA 0x3AB 0x3AC 0x3AD 0x3AE 0x3AF
/// 0x3C0 0x3C1 0x3C2 0x3C3 0x3C4 0x3C5 0x3C6 0x3C7 0x3C8 0x3C9 0x3CA 0x3CB 0x3CC 0x3CD 0x3CE 0x3CF
/// 0x3E0 0x3E1 0x3E2 0x3E3 0x3E4 0x3E5 0x3E6 0x3E7 0x3E8 0x3E9 0x3EA 0x3EB 0x3EC 0x3ED 0x3EE 0x3EF
///
/// Lines 32 to 63
/// 0x010 0x011 0x012 0x013 0x014 0x015 0x016 0x017 0x018 0x019 0x01A 0x01B 0x01C 0x01D 0x01E 0x01F
/// 0x030 0x031 0x032 0x033 0x034 0x035 0x036 0x037 0x038 0x039 0x03A 0x03B 0x03C 0x03D 0x03E 0x03F
/// 0x050 0x051 0x052 0x053 0x054 0x055 0x056 0x057 0x058 0x059 0x05A 0x05B 0x05C 0x05D 0x05E 0x05F
/// ...
/// 0x3B0 0x3B1 0x3B2 0x3B3 0x3B4 0x3B5 0x3B6 0x3B7 0x3B8 0x3B9 0x3BA 0x3BB 0x3BC 0x3BD 0x3BE 0x3BF
/// 0x3D0 0x3D1 0x3D2 0x3D3 0x3D4 0x3D5 0x3D6 0x3D7 0x3D8 0x3D9 0x3DA 0x3DB 0x3DC 0x3DD 0x3DE 0x3DF
/// 0x3F0 0x3F1 0x3F2 0x3F3 0x3F4 0x3F5 0x3F6 0x3F7 0x3F8 0x3F9 0x3FA 0x3FB 0x3FC 0x3FD 0x3FE 0x3FF
type GRam = [u8; GRAM_LENGTH];
const GRAM_LENGTH: usize = 2048;

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

    /// True if currently busy
    busy: bool,

    /// RE bit according to documentation. true if using extended instruction set
    extended_instr: bool,

    /// Address Counter AC
    address_counter: usize,

    /// Current address in GRAM
    gram_address: u16,

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

    /// After setting the address, an extra dummy read is necessary. No need of something similar
    /// for writing
    dummy_read_necessary: bool,

    /// Byte writes should always come in pairs, similar for reads. This keeps track if we are
    /// doing the first or the second read/write
    second_rw: bool,

    /// When setting GRAM address, two bytes are sent. This keeps track of which one we are
    /// expecing
    second_gram_addr: bool,
}

impl MgcLcd {
    pub fn new() -> MgcLcd {
        let mut lcd = MgcLcd {
            cgram: [0x00; CGRAM_LENGTH],
            busy: false,
            ddram: [0x2020; DDRAM_LENGTH],
            gram: [0x00; GRAM_LENGTH],
            extended_instr: false,
            address_counter: 0,
            gram_address: 0,
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
            second_gram_addr: false,
        };
        // On my LCD, I observed that GRAM has random stuff when turned on
        for byte in lcd.gram.iter_mut() {
            *byte = rand::random::<u8>();
        }

        return lcd;
    }

    pub fn draw(&self, screen: &mut Screen) {
        if !self.display_on {
            return;
        }

        // Draw text
        for x in 0..TEXT_W {
            for y in 0..TEXT_H {

                let ddram_addr: usize = DDRAM_LINE_ADDR[y] + x / 2;
                let ddram_byte = match x % 2 {
                    0 => (self.ddram[ddram_addr] & 0xFF00) >> 8,
                    1 => self.ddram[ddram_addr] & 0x00FF,
                    _ => unreachable!(),
                };

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

        if self.graphic_on {
            // Draw graphics
            for addr in 0..(16*64) {
                // Each word in GRAM is two bytes shown side by side
                let mut word = self.gram[addr];

                for word_px_x in 0..8 {
                    let screen_px_x = (addr & 0x00F) * 8 + word_px_x;
                    let mut screen_px_y = addr >> 5;
                    if addr & 0x10 != 0 {
                        screen_px_y += 32;
                    }

                    if word & (0b10000000 >> word_px_x) != 0 {
                        screen[screen_px_x + screen_px_y * SCREEN_W] = true;
                    }
                }
            }
        }
    }

    /// Send command or data to LCD.
    ///
    /// Which means, emulate what happens when enabling the LCD.
    /// Pin RW set to 0 is for writing, and pin RS set to 0 is for instructions.
    pub fn run(&mut self, rs: bool, rw: bool, data: u8) -> Option<u8> {

        match (self.extended_instr, rs, rw) {

            (false, false, false) => { // Standard instruction set, write instructions

                assert!(!self.busy, "LCD is busy");

                if data == 0b0000_0001 {
                    // Clear
                    for word in self.ddram.iter_mut() {
                        *word = 0x2020; // Wto 0x20 chars
                    }
                    self.address_counter = 0;
                    self.curr_memory = Memory::DDRam;
                    self.second_rw = false;
                    self.second_gram_addr = false;
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
                    self.second_rw = false;
                    self.second_gram_addr = false;
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
                    self.second_gram_addr = false;
                    assert!(
                        (0x00 <= self.address_counter && self.address_counter <= 0x07) // Line 1
                        || (0x10 <= self.address_counter && self.address_counter <= 0x17) // Line 2
                        || (0x08 <= self.address_counter && self.address_counter <= 0x0F) // Line 3
                        || (0x18 <= self.address_counter && self.address_counter <= 0x1F) // Line 4
                    );
                }

                self.busy = true;

                return None;
            },
            (true, false, false) => { // Extended instruction set, write instructions

                assert!(!self.busy, "LCD is busy");

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
                    self.curr_memory = Memory::GRam;
                    if !self.second_gram_addr {
                        self.gram_address = ((data & 0b0111_1111) as u16) << 5;
                        self.second_gram_addr = true;
                    } else {
                        self.gram_address |= ((data & 0b0000_1111) as u16) << 1;
                        self.second_gram_addr = false;
                    }
                    self.dummy_read_necessary = true;
                    self.second_rw = false;
                }

                self.busy = true;

                return None;
            },
            (_, false, true) => { // Any instruction set, read instruction
                let mut result: u8 = self.address_counter as u8;
                if self.busy {
                    result |= 0b1000_0000;
                }
                self.busy = false;
                return Some(result);
            },
            (_, true, false) => { // Any instruction set, write data

                assert!(!self.busy, "LCD is busy");

                match self.curr_memory {

                    Memory::DDRam => {
                        let mut word: u16 = self.ddram[self.address_counter];

                        if self.second_rw { // Put data in less significative bits
                            word &= 0xFF00;
                            word |= data as u16;
                        } else { // Put data in most significative bits
                            word &= 0x00FF;
                            word |= (data as u16) << 8;
                        }

                        self.ddram[self.address_counter] = word;

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
                    },

                    Memory::GRam => {
                        self.gram[self.gram_address as usize] = data;
                        self.gram_address += 1;
                    },

                    _ => unimplemented!("Writing other memories"),
                }

                self.busy = true;

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
