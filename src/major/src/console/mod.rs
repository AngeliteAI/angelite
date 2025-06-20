use core::fmt;
use std::{
    cell::{Cell, RefCell},
    collections::HashMap,
    io::{Write, stdin, stdout},
    time::Duration,
};

use crate::tile::{self, Tile, Type};
use crossterm::{
    QueueableCommand,
    cursor::{self, RestorePosition, SavePosition, position},
    event::{self, Event, KeyCode, poll},
    style::{Color, Stylize},
    terminal::{Clear, ClearType, disable_raw_mode, enable_raw_mode, size},
};

use crate::{Binding, Data, Engine};

pub struct Actor {
    actor: super::Actor,
    pos: Cell<[f32; 2]>,
}

struct InputState {
    key_w_pressed: bool,
    key_a_pressed: bool,
    key_s_pressed: bool,
    key_d_pressed: bool,
    key_esc_pressed: bool,
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

pub struct Console {
    input_state: RefCell<InputState>,
    camera: RefCell<Camera>,
    chunk: RefCell<HashMap<[i128; 2], Chunk>>,
    cursor: Cell<[i128; 2]>,
    values_this_frame: Cell<usize>,
}

impl Console {
    pub fn new() -> Self {
        // Enable raw mode for input handling
        enable_raw_mode().expect("Failed to enable raw mode");

        Console {
            values_this_frame: 0.into(),
            input_state: RefCell::new(InputState {
                key_w_pressed: false,
                key_a_pressed: false,
                key_s_pressed: false,
                key_d_pressed: false,
                key_esc_pressed: false,
            }),
            camera: RefCell::new(Camera {
                pos: [0., 0.],
                origin: [0, 0],
            }),
            chunk: RefCell::new(HashMap::new()),
            cursor: [0, 0].into(),
        }
    }

    fn check_input(&self) {
        // Check for key events with a very short timeout to avoid blocking
        if poll(Duration::from_millis(1)).unwrap_or(false) {
            if let Ok(Event::Key(key_event)) = event::read() {
                let mut input = self.input_state.borrow_mut();
                let cursor = self.cursor.get();
                match key_event.code {
                    KeyCode::Char('w') | KeyCode::Char('W') => input.key_w_pressed = true,
                    KeyCode::Char('a') | KeyCode::Char('A') => input.key_a_pressed = true,
                    KeyCode::Char('s') | KeyCode::Char('S') => input.key_s_pressed = true,
                    KeyCode::Char('d') | KeyCode::Char('D') => input.key_d_pressed = true,
                    KeyCode::Up => self.cursor.set([cursor[0], cursor[1] - 1]),
                    KeyCode::Down => self.cursor.set([cursor[0], cursor[1] + 1]),
                    KeyCode::Left => self.cursor.set([cursor[0] - 1, cursor[1]]),
                    KeyCode::Right => self.cursor.set([cursor[0] + 1, cursor[1]]),
                    KeyCode::Esc => input.key_esc_pressed = true,
                    _ => {}
                }
            }
        }
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
        use crossterm::{QueueableCommand, cursor};
        use std::io::{Write, stdout};

        let mut stdout = stdout();
        let term_size = size().unwrap();
        let half_term_size = (term_size.0 / 2, term_size.1 / 2);
        stdout.flush();

        // Reset key states after each frame
        let mut input = self.input_state.borrow_mut();
        input.key_w_pressed = false;
        input.key_a_pressed = false;
        input.key_s_pressed = false;
        input.key_d_pressed = false;
        input.key_esc_pressed = false;
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
            let character = match actor.actor {
                super::Actor::Player => 'P'.with(Color::Green),
                super::Actor::Zombie => 'Z'.with(Color::Magenta),
                super::Actor::Turret => 'T'.with(Color::Yellow),
            };
            stdout().queue(crossterm::style::PrintStyledContent(character));
            stdout().queue(RestorePosition);
            stdout().flush();
        }
    }

    fn input_binding_data(&self, bind: Binding) -> crate::Data {
        let input = self.input_state.borrow();
        match bind {
            Binding::Cursor => Data {
                pos: (self.cursor.get()[0] as f32, self.cursor.get()[1] as f32),
            },
            Binding::MoveVertical => Data {
                scalar: if input.key_w_pressed {
                    1.0
                } else if input.key_s_pressed {
                    -1.0
                } else {
                    0.0
                },
            },
            Binding::MoveHorizontal => Data {
                scalar: if input.key_a_pressed {
                    -1.0
                } else if input.key_d_pressed {
                    1.0
                } else {
                    0.0
                },
            },
            Binding::Escape => Data {
                activate: input.key_esc_pressed,
            },
        }
    }

    fn cell_frustum(&self) -> crate::Frustum {
        let term_size = size().unwrap();
        let half_term_size = (term_size.0 as i128 / 2, term_size.1 as i128 / 2);
        let camera_pos = self.camera.borrow().pos;
        let camera_origin = self.camera.borrow().origin;

        crate::Frustum {
            left: (half_term_size.0 as i128 + camera_pos[0] as i128 - camera_origin[0] as i128),

            right: (half_term_size.0 as i128 + camera_pos[0] as i128 - camera_origin[0] as i128),
            top: (half_term_size.1 as i128 + camera_pos[1] as i128 - camera_origin[1] as i128),
            bottom: (half_term_size.1 as i128 + camera_pos[1] as i128 - camera_origin[1] as i128),
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
}
