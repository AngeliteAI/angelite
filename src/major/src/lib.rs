use core::fmt;

mod console;
mod ffi;
pub mod tile;

#[derive(Clone, Copy)]
pub enum Actor {
    Player,
    Zombie,
    Turret,
}

pub trait Engine {
    fn frame_begin(&self);
    fn frame_end(&self);

    fn set_focus_point(&self, x: f32, y: f32);
    fn set_origin(&self, x: i128, y: i128);
    fn cell_set(&self, x: i128, y: i128, tile: tile::Type);
    fn cell_frustum(&self) -> Frustum;

    fn actor_create(&self, ty: Actor) -> *mut Actor;
    fn actor_move(&self, actor: *mut Actor, x: f32, y: f32);
    fn actor_draw(&self, actor: *mut Actor);

    fn input_binding_data(&self, bind: Binding) -> Data;

    fn debug_value(&self, name: Box<dyn fmt::Display>);
}

pub struct Frustum {
    pub left: i128,
    pub right: i128,
    pub top: i128,
    pub bottom: i128,
}

#[derive(Clone, Copy)]
pub enum Binding {
    MoveHorizontal,
    MoveVertical,
    Cursor,
    Escape,
}

pub union Data {
    pub scalar: f32,
    pub pos: (f32, f32),
    pub activate: bool,
}

pub enum Type {
    Console,
}

pub fn engine(ty: Type) -> Box<dyn Engine> {
    match ty {
        Type::Console => Box::new(console::Console::new()),
    }
}
