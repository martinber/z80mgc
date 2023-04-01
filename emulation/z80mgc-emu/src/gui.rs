use iz80::Machine;
use gtk::prelude::*;
use std::cell::RefCell;

use crate::emulation;


fn print_field(
    machine: &emulation::MgcMachine,
    canvas: &gtk::DrawingArea,
    context: &gtk::cairo::Context
) {
    let mut screen: [bool; 128 * 64] = [false; 128 * 64];
    machine.lcd.draw(&mut screen);

    let canvas_w: i32 = canvas.allocated_width();
    let canvas_h: i32 = canvas.allocated_height();

    let pixbuf = gdk_pixbuf::Pixbuf::new(
        gdk_pixbuf::Colorspace::Rgb, false, 8, 128, 64
    ).unwrap();

    pixbuf.fill(0);
    for x in 0..128 {
        for y in 0..64 {
            if screen[x + y * 128] {
                pixbuf.put_pixel(x as u32, y as u32, 255, 255, 255, 255);
            }
        }
    }

    let pixbuf_scaled = pixbuf.scale_simple(
        canvas_w, canvas_h, gdk_pixbuf::InterpType::Nearest
    ).unwrap();

    context.set_source_pixbuf(&pixbuf_scaled, 0f64, 0f64);
    context.paint().unwrap();
}

struct EmulationState {
    machine: emulation::MgcMachine,
    cpu: iz80::Cpu,
    last_nmi_micros: i64,
}

struct GuiState {
    window: gtk::ApplicationWindow,
    button_reset: gtk::Button,
    canvas: gtk::DrawingArea,
}

thread_local!(
    static EMULATION_STATE: RefCell<Option<EmulationState>> = RefCell::new(None);
    static GUI_STATE: RefCell<Option<GuiState>> = RefCell::new(None);
);

pub fn main() {

    let application = gtk::Application::new(
        Some("ar.com.mbernardi.z80mgc-emu"),
        gio::ApplicationFlags::HANDLES_OPEN,
    );

    application.connect_open(start);

    application.run();
}


fn main_loop(
    emulation_state: &mut EmulationState,
    canvas: &gtk::DrawingArea,
    clock: &gdk::FrameClock
) {

    if clock.frame_time() - emulation_state.last_nmi_micros > 33333 {

        emulation_state.cpu.signal_nmi();
        while !emulation_state.cpu.is_halted() {
            emulation_state.cpu.execute_instruction(&mut emulation_state.machine);
        }
        canvas.queue_draw();
        emulation_state.last_nmi_micros = clock.frame_time();
        println!("------------ NMI -------------");
    }
}


fn start(application: &gtk::Application, files: &[gio::File], _hint: &str) {

    // Create machine and cpu, fill EEPROM with program

    let mut machine = emulation::MgcMachine::new();
    let mut cpu = iz80::Cpu::new();
    cpu.registers().set_pc(0x0000);
    cpu.set_trace(true);

    let filename = files[0].path().unwrap();
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
    let button_reset: gtk::Button = builder.object("button_reset").expect("Couldn't get button_reset");
    let canvas: gtk::DrawingArea = builder.object("canvas").expect("Couldn't get canvas");
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

    // Connect drawing of canvas

    // canvas.connect_draw(
    canvas.connect_draw(|canvas: &gtk::DrawingArea, context: &gtk::cairo::Context| {
        EMULATION_STATE.with(|global| {
            let mut emulation_state = global.borrow_mut();
            if let Some(s) = emulation_state.as_mut() {
                print_field(&s.machine, canvas, context);
            }
        });
        gtk::Inhibit(false)
    });

    // Move widgets to global state
    GUI_STATE.with(move |global| {
        *global.borrow_mut() = Some(GuiState {
            window,
            canvas,
            button_reset,
        })
    });

    window_copy.add_tick_callback(|_window: &gtk::ApplicationWindow, clock: &gdk::FrameClock| {
        EMULATION_STATE.with(|global| {
            let mut emulation_state_opt = global.borrow_mut();
            if let Some(emulation_state) = emulation_state_opt.as_mut() {

                GUI_STATE.with(move |global| {
                    let mut gui_state_opt = global.borrow_mut();
                    if let Some(gui_state) = gui_state_opt.as_mut() {

                        main_loop(emulation_state, &gui_state.canvas, clock);
                    }
                });
            } else {
                println!("Machine didnt start yet!");
            }
        });

        return Continue(true);
    });

    // button_up.connect_clicked(glib::clone!(@weak dialog => move |_| dialog.show_all()));
    window_copy.show_all();
}
