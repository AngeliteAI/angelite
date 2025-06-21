use core::fmt;

use crate::{gfx::Gfx, tile};

mod mac;

pub enum Type {
    Mac,
}

pub const fn default_platform_type() -> Type {
    #[cfg(target_os = "macos")]
    Type::Mac
}
static mut ENGINE_TYPE: Type = default_platform_type();
static mut ENGINE: EngineCell = EngineCell::none();

//TODO implement actual thread cooperation
pub struct EngineCell {
    engine: Option<Box<dyn Engine>>,
}

impl EngineCell {
    pub const fn none() -> Self {
        Self { engine: None }
    }
    pub fn is_none(&self) -> bool {
        self.engine.is_none()
    }
}

#[cfg(target_os = "macos")]
pub fn mac() -> EngineCell {
    EngineCell {
        engine: Some(Box::new(mac::Engine::init())),
    }
}

unsafe impl Send for EngineCell {}
unsafe impl Sync for EngineCell {}

pub fn engine_seed_type(ty: Type) {
    unsafe { ENGINE_TYPE = ty };
}

#[allow(static_mut_refs)]
pub fn engine() -> &'static mut dyn Engine {
    unsafe {
        if ENGINE.is_none() {
            ENGINE = match ENGINE_TYPE {
                #[cfg(target_os = "macos")]
                Type::Mac => mac(),
            };
        }

        &mut **ENGINE.engine.as_mut().unwrap()
    }
}

#[derive(Hash, Clone, Copy, Debug, PartialEq, Eq)]
pub enum Button {
    ButtonA,
    ButtonB,
    ButtonX,
    ButtonY,
    ButtonLTrigger,
    ButtonRTrigger,
    ButtonLJoystick,
    ButtonRJoystick,
    ButtonMenu,
    KeyW,
    KeyA,
    KeyS,
    KeyD,
    KeySpace,
    KeyEnter,
    KeyEscape,
}

#[derive(Hash, Clone, Copy, Debug, PartialEq, Eq)]
pub enum Axis {
    Mouse,
    LeftJoystick,
    RightJoystick,
}

#[repr(u32)]
#[derive(Debug)]
pub enum Actor {
    Unknown,
    Player,
    Zombie,
    Turret,
    Ghost,
}

pub trait Surface {
    fn poll(&self);
}

pub trait Engine {
    fn surface_create(&self) -> Box<dyn Surface>;

    fn gfx_create(&self, surface: Box<dyn Surface>) -> Box<dyn Gfx>;

    fn set_focus_point(&self, x: f32, y: f32);
    fn set_origin(&self, x: i128, y: i128);
    fn cell_set(&self, x: i128, y: i128, tile: tile::Type);
    fn cell_frustum(&self) -> Frustum;

    fn actor_create(&self, ty: Actor) -> *mut Actor;
    fn actor_move(&self, actor: *mut Actor, x: f32, y: f32);

    fn input_binding_data(&self, bind: Binding) -> Data;
    fn input_binding_activate(&self, button: Button, activate: bool);
    fn input_binding_move(&self, axis: Axis, x: f32, y: f32);

    fn debug_value(&self, name: Box<dyn fmt::Display>);
}

#[derive(Debug, Clone, Copy)]
#[repr(C)]
pub struct Frustum {
    pub left: i128,
    pub right: i128,
    pub top: i128,
    pub bottom: i128,
}

#[derive(Clone, Copy)]
#[repr(C)]
pub enum Binding {
    MoveHorizontal,
    MoveVertical,
    Cursor,
    Select,
    Escape,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union Data {
    pub scalar: f32,
    pub pos: (f32, f32),
    pub activate: bool,
}
