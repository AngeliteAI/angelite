use core::fmt;
use std::{
    cell::{Cell, OnceCell, Ref, RefCell},
    collections::HashMap,
    hash::Hash,
    io::{Write, stdin, stdout},
    sync::OnceLock,
    time::Duration,
};

use crate::{
    Axis, Button,
    controller::{
        self,
        macos::{BUTTON_X, Controllers, axis_binding, button_binding},
    },
    engine,
    tile::{self, Tile, Type},
};
use crossterm::{
    QueueableCommand,
    cursor::{self, RestorePosition, SavePosition, position},
    event::{self, Event, KeyCode, poll},
    style::{Color, StyledContent, Stylize},
    terminal::{Clear, ClearType, disable_raw_mode, enable_raw_mode, size},
};

use crate::{Binding, Data, Engine};

#[repr(C)]
pub struct Actor {
    actor: super::Actor,
    pos: Cell<[f32; 2]>,
}

pub struct Camera {
    pos: [f32; 2],
    origin: [i128; 2],
}

pub struct Chunk {
    tile: [Tile; Self::SIZE * Self::SIZE],
}

impl Chunk {
    pub const SIZE: usize = 16;
    fn new() -> Self {
        Chunk {
            tile: core::array::from_fn(|_| Tile { ty: Type::Grass }),
        }
    }
}

#[derive(Default)]
pub struct InputState {
    buttons: HashMap<Button, bool>,
    axes: HashMap<Axis, [f32; 2]>,
}

//TODO this has to be some sort of dictionary somewhere so that it can be changed

pub extern "C" fn button_callback(button: u32, activated: bool) {
    dbg!("deez");
    engine().input_binding_activate(button_binding(button), activated);
}

pub extern "C" fn analog_callback(axis: u32, x: f32, y: f32) {
    engine().input_binding_move(axis_binding(axis), x, y);
}
pub struct Console {
    input_state: RefCell<InputState>,
    camera: RefCell<Camera>,
    chunk: RefCell<HashMap<[i128; 2], Chunk>>,
    cursor: Cell<[f32; 2]>,
    values_this_frame: Cell<usize>,
    controllers: Controllers,
}

impl Console {
    pub fn new() -> Self {
        // Enable raw mode for input handling
        enable_raw_mode().expect("Failed to enable raw mode");
        let controllers = Controllers::new();
        controllers.set_analog_callback(analog_callback);
        controllers.set_button_callback(button_callback);
        controllers.start_discovery();

        Console {
            input_state: RefCell::new(InputState::default()),
            values_this_frame: 0.into(),

            camera: RefCell::new(Camera {
                pos: [0., 0.],
                origin: [0, 0],
            }),
            chunk: RefCell::new(HashMap::new()),
            cursor: [0.5, 0.5].into(),
            controllers,
        }
    }

    fn check_input(&self) {
        // Check for key events with a very short timeout to avoid blocking
        // if poll(Duration::from_millis(1)).unwrap_or(false) {
        //     if let Ok(Event::Key(key_event)) = event::read() {
        //         let mut input = self.input_state.borrow_mut();
        //         let cursor = self.cursor.get();
        //         match key_event.code {
        //             KeyCode::Char('w') | KeyCode::Char('W') => input.key_w_pressed = true,
        //             KeyCode::Char('a') | KeyCode::Char('A') => input.key_a_pressed = true,
        //             KeyCode::Char('s') | KeyCode::Char('S') => input.key_s_pressed = true,
        //             KeyCode::Char('d') | KeyCode::Char('D') => input.key_d_pressed = true,
        //             KeyCode::Up => self.cursor.set([cursor[0], cursor[1] - 0.01]),
        //             KeyCode::Down => self.cursor.set([cursor[0], cursor[1] + 0.01]),
        //             KeyCode::Left => self.cursor.set([cursor[0] - 0.01, cursor[1]]),
        //             KeyCode::Right => self.cursor.set([cursor[0] + 0.01, cursor[1]]),
        //             KeyCode::Esc => input.key_esc_pressed = true,
        //             KeyCode::Enter => input.key_enter_pressed = true,
        //             _ => {}
        //         }
        //     }
        // }
    }
}

impl Drop for Console {
    fn drop(&mut self) {
        // Disable raw mode when Console is dropped
        let _ = disable_raw_mode();
    }
}

impl Engine for Console {
    fn frame_begin(&self) {
        // Check for input using RefCell
        self.check_input();

        let mut stdout = stdout();
        stdout.queue(Clear(ClearType::All));
    }

    fn frame_end(&self) {
        self.debug_value(Box::new(format!(
            "{} deez",
            self.controllers.get_controller_name(0)
        )));
        use crossterm::{QueueableCommand, cursor};
        use std::io::{Write, stdout};
        self.values_this_frame.set(0);
        let mut stdout = stdout();
        let term_size = size().unwrap();
        let half_term_size = (term_size.0 / 2, term_size.1 / 2);
        stdout.flush();

        // Reset key states after each frame
    }

    fn set_focus_point(&self, x: f32, y: f32) {
        self.camera.borrow_mut().pos = [x, y];
    }

    fn set_origin(&self, x: i128, y: i128) {
        self.camera.borrow_mut().origin = [x, y];
    }

    fn cell_set(&self, x: i128, y: i128, tile: tile::Type) {
        let chunk_key = [x / Chunk::SIZE as i128, y / Chunk::SIZE as i128];
        let mut chunks = self.chunk.borrow_mut();
        let mut chunk = chunks.entry(chunk_key).or_insert_with(Chunk::new);
        chunk.tile[x.rem_euclid(Chunk::SIZE as i128) as usize
            + Chunk::SIZE as usize * (y.rem_euclid(Chunk::SIZE as i128) as usize)] =
            Tile { ty: tile };
    }
    fn cell_frustum(&self) -> crate::Frustum {
        let term_size = size().unwrap();
        let half_term_size = (term_size.0 as i128 / 2, term_size.1 as i128 / 2);
        let camera_pos = self.camera.borrow().pos;
        let camera_origin = self.camera.borrow().origin;

        crate::Frustum {
            left: (-half_term_size.0 as i128 + camera_pos[0] as i128 - camera_origin[0] as i128),

            right: (half_term_size.0 as i128 + camera_pos[0] as i128 - camera_origin[0] as i128),
            top: (half_term_size.1 as i128 + camera_pos[1] as i128 - camera_origin[1] as i128),
            bottom: (-half_term_size.1 as i128 + camera_pos[1] as i128 - camera_origin[1] as i128),
        }
    }
    fn actor_create(&self, ty: super::Actor) -> *mut super::Actor {
        let actor = Box::new(Actor {
            actor: ty,
            pos: [0., 0.].into(),
        });
        let ptr = Box::into_raw(actor) as *mut _;
        ptr
    }

    fn actor_move(&self, actor: *mut super::Actor, x: f32, y: f32) {
        unsafe {
            (actor as *mut Actor).as_ref().unwrap().pos.set([x, y]);
        }
    }

    fn actor_draw(&self, actor: *mut super::Actor) {
        unsafe {
            let actor = (actor as *mut Actor).as_ref().unwrap();
            let term_size = size().unwrap();
            let half_term_size = (term_size.0 / 2, term_size.1 / 2);
            stdout().queue(SavePosition);
            stdout().queue(cursor::MoveTo(
                (half_term_size.0 as i128 + actor.pos.get()[0] as i128
                    - self.camera.borrow().pos[0] as i128
                    - self.camera.borrow().origin[0]) as u16,
                (half_term_size.1 as i128 + actor.pos.get()[1] as i128
                    - self.camera.borrow().pos[1] as i128
                    - self.camera.borrow().origin[1]) as u16,
            ));
            fn actor_draw_character(actor: &super::Actor) -> StyledContent<char> {
                match actor {
                    super::Actor::Player => 'P'.with(Color::Green),
                    super::Actor::Zombie => 'Z'.with(Color::Magenta),
                    super::Actor::Turret => 'T'.with(Color::Yellow),
                    super::Actor::Ghost(ghost) => actor_draw_character(&*ghost).with(Color::Grey),
                }
            }
            let character = actor_draw_character(&actor.actor);
            stdout().queue(crossterm::style::PrintStyledContent(character));
            stdout().queue(RestorePosition);
            stdout().flush();
        }
    }

    fn input_binding_data(&self, bind: Binding) -> crate::Data {
        let mut input = self.input_state.borrow_mut();
        match bind {
            Binding::Select => Data {
                activate: *input.buttons.entry(Button::ButtonMenu).or_default(),
            },
            Binding::Escape => Data {
                activate: *input.buttons.entry(Button::ButtonMenu).or_default(),
            },
            Binding::MoveHorizontal => Data {
                scalar: input.axes.entry(Axis::LeftJoystick).or_default()[0],
            },
            Binding::MoveVertical => Data {
                scalar: input.axes.entry(Axis::LeftJoystick).or_default()[1],
            },
            Binding::Cursor => Data { activate: false },
        }
    }

    fn debug_value(&self, name: Box<dyn fmt::Display>) {
        stdout().queue(SavePosition);
        stdout().queue(cursor::MoveTo(0, self.values_this_frame.get() as u16));
        self.values_this_frame.set(self.values_this_frame.get() + 1);
        stdout().queue(crossterm::style::PrintStyledContent(
            format!("{}", name).with(Color::Red),
        ));
        stdout().queue(RestorePosition);
        stdout().flush();
    }

    fn input_binding_activate(&self, button: Button, activate: bool) {}

    fn input_binding_move(&self, axis: crate::Axis, x: f32, y: f32) {}
}
