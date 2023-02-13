// Only emulates the 8x16 english characters and not the chinese 16x16 chars

const TEXT_W: usize = 16; /// Number of characters in a row
const TEXT_H: usize = 4; /// Number of rows of characters
const CHAR_W: usize = 8; /// Char width in pixels
const CHAR_H: usize = 16; /// Char height in pixels
const SCREEN_W: usize = 128; /// Screen width in pixels
const SCREEN_H: usize = 64; /// Screen height in pixels

// type TextBuffer = [[u8; WIDTH]; HEIGHT];
// type PxBuffer = [[bool; WIDTH_PX]; HEIGHT_PX];

/// Character Generator RAM. 4x16x16 bits for 8 chars
type GCRam = [u8; 128];

// DDRAM:
// - Data codes 0x02-0x7F are for half height alpha numeric fonts
// - Data codes 0x0000-0x0006 are for CGRAM (2 bytes per char)
// - Data codes 0xA140-0xD75F are for BIG5 code and 0xA1A0-0xF7FF are for GB code (2 bytes per char)
/// Display Data RAM: 64 * 2 bytes, but addresses start at 0x80 and not all ram is used
type DDRam = [u16; 64];

/// Graphic RAM: 64 * 256 bits
type GRam = [u8; 2048];

/// Icon RAM: 15 * 16 bits
type IRam = [u8; 30];

/// Indicates where the next write/read instruction will operate
enum Memory {
    CGRam,
    DDRam,
    GRam,
    IRam,
}

pub struct MgcLcd {
    ddram: DDRam,

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
        MgcLcd {
            ddram: [0x2020; 64],
            extended_instr: false,
            address_counter: 0,
            direction_right: true,
            shift_on: false,
            display_on: true,
            cursor_on: false,
            blink_on: false,
            parallel_8: true,
            curr_memory: Memory::DDRam,
            dummy_read_necessary: false,
            second_rw: false,
        }
    }

    pub fn display(&self) -> String {
        let mut text: String = String::from("");

        let addresses: [usize; 4] = [0x00, 0x10, 0x08, 0x18]; // Addreess of each line

        for y in 0..4 {
            if y > 0 {
                text.push('\n');
            }
            for x in 0..8 {
                let word: u16 = self.ddram[addresses[y] + x];
                text.push(char::from_u32(((word & 0xFF00) >> 8) as u32).unwrap());
                text.push(char::from_u32((word & 0x00FF) as u32).unwrap());
            }
        }

        return text;
    }

    /// rw is 0 for writing
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
                    self.parallel_8 = data & 0b0001_0000 != 0;
                    if !self.parallel_8 {
                        unimplemented!("4bit interface");
                    }
                    self.extended_instr = data & 0b0000_0100 != 0;
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
                    assert!(
                        (0x00 <= self.address_counter && self.address_counter <= 0x07) // Line 1
                        || (0x10 <= self.address_counter && self.address_counter <= 0x17) // Line 2
                        || (0x08 <= self.address_counter && self.address_counter <= 0x0F) // Line 3
                        || (0x18 <= self.address_counter && self.address_counter <= 0x1F) // Line 4
                    );
                }

                return None;
            },
            (false, false, true) => { // Standard instruction set, read instruction
                let result = self.address_counter;
                // Not setting the BUSY flag
                return Some(result as u8);
            },
            (false, true, false) => { // Standard instruction set, write data
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
            (true, true, false) => { // Standard instruction set, read data

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
            _ => unimplemented!("Other match mases"),
        }
    }
}
