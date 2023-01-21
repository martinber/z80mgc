use iz80::{Cpu, Machine};
use std::cell::RefCell;
use gtk::prelude::*;
// use gio::prelude::*;
// use gdk::prelude::*;


pub struct MgcMachine {
    mem: [u8; 65536],
    clicked_up: bool,
    clicked_down: bool,
    clicked_left: bool,
    clicked_right: bool,
}

impl MgcMachine {
    pub fn new() -> MgcMachine {
        MgcMachine {
            mem: [0; 65536],
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

    fn port_in(&mut self, _address: u16) -> u8 {
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

    fn port_out(&mut self, _address: u16, _value: u8) { }
}

fn print_field(machine: &MgcMachine) {
    let mut text: String = String::from("");

    let field_mem_location = 0x8000;
    for y in 0..4 {
        if y > 0 {
            text.push('\n');
        }
        for x in 0..20 {
            let val: u8 = machine.mem[field_mem_location+x+y*20];
            match val {
                0 => text.push(' '),
                1 => text.push('^'),
                2 => text.push('v'),
                3 => text.push('<'),
                4 => text.push('>'),
                5 => text.push('0'),
                _ => text.push('?'),
            }
        }
    }


    GUI_STATE.with(move |global| {
        let mut gui_state = global.borrow_mut();
        if let Some(s) = gui_state.as_mut() {
            s.screen.buffer().unwrap().set_text(&text);
        }
    });
}

struct EmulationState {
    machine: MgcMachine,
    cpu: Cpu,
    last_nmi_micros: i64,
}

struct GuiState {
    window: gtk::ApplicationWindow,
    button_up: gtk::Button,
    button_down: gtk::Button,
    button_left: gtk::Button,
    button_right: gtk::Button,
    button_reset: gtk::Button,
    screen: gtk::TextView,
}

thread_local!(
    static EMULATION_STATE: RefCell<Option<EmulationState>> = RefCell::new(None);
    static GUI_STATE: RefCell<Option<GuiState>> = RefCell::new(None);
);

fn main() {

    // Init GTK

    let application = gtk::Application::new(
        Some("ar.com.mbernardi.z80mgc-emu"),
        gio::ApplicationFlags::HANDLES_OPEN,
    );

    application.connect_open(start);
    // application.connect_activate(build_ui);

    application.run();
}

fn main_loop(window: &gtk::ApplicationWindow, clock: &gdk::FrameClock) -> Continue {

    EMULATION_STATE.with(|global| {

        let mut emulation_state = global.borrow_mut();
        if let Some(s) = emulation_state.as_mut() {

            // if clock.frame_time() - s.last_nmi_micros > 33333 {
            if clock.frame_time() - s.last_nmi_micros > 333333 {

                s.cpu.signal_nmi();
                while !s.cpu.is_halted() {
                    s.cpu.execute_instruction(&mut s.machine);
                }
                print_field(&s.machine);
                s.last_nmi_micros = clock.frame_time();
                println!("------------ NMI -------------");
            }
        } else {
            println!("Machine didnt start yet!");
        }
    });

    return Continue(true);
}

fn start(application: &gtk::Application, files: &[gio::File], _hint: &str) {
    println!("START");
    let filename = files[0].path().unwrap();

    // Init machine

    let mut machine = MgcMachine::new();
    let mut cpu = Cpu::new();
    cpu.registers().set_pc(0x0000);
    cpu.set_trace(true);

    let data = std::fs::read(filename).expect("Failed to read file");

    for (i, byte) in data.iter().enumerate() {
        machine.poke(i as u16, *byte);
    }

    // Move machine to global state
    EMULATION_STATE.with(move |global| {
        *global.borrow_mut() = Some(EmulationState {
            machine,
            cpu,
            last_nmi_micros: 0,
        })
    });

    // Build UI

    let glade_src = include_str!("gui.glade");
    let builder = gtk::Builder::from_string(glade_src);

    let window: gtk::ApplicationWindow = builder.object("window").expect("Couldn't get window");
    let button_up: gtk::Button = builder.object("button_up").expect("Couldn't get button_up");
    let button_down: gtk::Button = builder.object("button_up").expect("Couldn't get button_up");
    let button_left: gtk::Button = builder.object("button_up").expect("Couldn't get button_up");
    let button_right: gtk::Button = builder.object("button_up").expect("Couldn't get button_up");
    let button_reset: gtk::Button = builder.object("button_reset").expect("Couldn't get button_reset");
    let screen: gtk::TextView = builder.object("screen").expect("Couldn't get screen");
    window.set_application(Some(application));

    let window_copy = window.clone();

    // Connect all buttons

    button_reset.connect_clicked(|_| {
        EMULATION_STATE.with(|global| {
            let mut emulation_state = global.borrow_mut();
            if let Some(s) = emulation_state.as_mut() {
                s.cpu.signal_reset();
            }
        });
    });

    window.connect("key_press_event", false, |values| {
        EMULATION_STATE.with(|global| {
            let mut emulation_state = global.borrow_mut();
            if let Some(s) = emulation_state.as_mut() {
                let raw_event = &values[1].get::<gdk::Event>().unwrap();
                match raw_event.downcast_ref::<gdk::EventKey>() {
                    Some(event) => {
                        match *event.keyval() {
                            65362 => s.machine.clicked_up = true,
                            65364 => s.machine.clicked_down = true,
                            65361 => s.machine.clicked_left = true,
                            65363 => s.machine.clicked_right = true,
                            _ => {},
                        }
                        // println!("key value: {:?}", *event.keyval());
                    },
                    None => {},
                }
            }
        });

        let result = glib::value::Value::from_type(glib::types::Type::BOOL);
        Some(result)
    });

    window.connect("key_release_event", false, |values| {
        EMULATION_STATE.with(|global| {
            let mut emulation_state = global.borrow_mut();
            if let Some(s) = emulation_state.as_mut() {
                let raw_event = &values[1].get::<gdk::Event>().unwrap();
                match raw_event.downcast_ref::<gdk::EventKey>() {
                    Some(event) => {
                        match *event.keyval() {
                            65362 => s.machine.clicked_up = false,
                            65364 => s.machine.clicked_down = false,
                            65361 => s.machine.clicked_left = false,
                            65363 => s.machine.clicked_right = false,
                            _ => {},
                        }
                    },
                    None => {},
                }
            }
        });

        let result = glib::value::Value::from_type(glib::types::Type::BOOL);
        Some(result)
    });

    // Move widgets to global state
    GUI_STATE.with(move |global| {
        *global.borrow_mut() = Some(GuiState {
            window,
            screen,
            button_up,
            button_down,
            button_left,
            button_right,
            button_reset,
        })
    });

    window_copy.add_tick_callback(main_loop);

    // button_up.connect_clicked(glib::clone!(@weak dialog => move |_| dialog.show_all()));
    window_copy.show_all();
}
