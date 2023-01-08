use iz80::*;


pub struct MgcMachine {
    mem: [u8; 65536],
    io: [u8; 65536]
}

impl MgcMachine {
    pub fn new() -> MgcMachine {
        MgcMachine {
            mem: [0; 65536],
            io: [0; 65536]
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
        self.io[address as usize]
    }
    fn port_out(&mut self, address: u16, value: u8) {
        self.io[address as usize] = value;
    }
}

fn print_field(machine: &MgcMachine) {
    let field_mem_location = 0x8000;
    for y in 0..4 {
        for x in 0..20 {
            let val: u8 = machine.mem[field_mem_location+x+y*20];
            match val {
                0 => print!(" "),
                1 => print!("^"),
                2 => print!("v"),
                3 => print!("<"),
                4 => print!(">"),
                5 => print!("0"),
                _ => print!("?"),
            }
        }
        print!("\n")
    }
    print!("\n")
}

fn main() {
    let mut machine = MgcMachine::new();
    let mut cpu = Cpu::new();
    // cpu.set_trace(true);

    let args: Vec<String> = std::env::args().collect();
    let filename = args.get(1).expect("Give data filename as argument");
    let data = std::fs::read(filename).expect("Failed to read file");

    // let code = [0x3c, 0xc3, 0x00, 0x00]; // INC A, JP $0000
    for (i, byte) in data.iter().enumerate() {
        machine.poke(i as u16, *byte);
    }

    let mut timer = std::time::Instant::now();

    // Run emulation
    cpu.registers().set_pc(0x0000);
    loop {
        cpu.execute_instruction(&mut machine);

        if timer.elapsed().as_millis() > 33 { // 30 FPS
            timer = std::time::Instant::now();
            cpu.signal_nmi();

            print_field(&machine);
        }
    }
}

