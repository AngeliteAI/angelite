use core::fmt;
use std::ffi::c_void;

use crate::{gfx::Gfx, math, tile, physx::Physx};

#[cfg(target_os = "macos")]
mod mac;
pub mod windows;

pub enum Type {
    #[cfg(target_os = "macos")]
    Mac,
    #[cfg(any(target_os = "windows", target_os = "linux"))]
    Windows,
}

pub const fn default_platform_type() -> Type {
    #[cfg(target_os = "macos")]
    return Type::Mac;
    #[cfg(target_os = "windows")]
    return Type::Windows;
    #[cfg(target_os = "linux")]
    return Type::Windows;
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
#[cfg(any(target_os = "windows", target_os = "linux"))]
pub fn windows() -> EngineCell {
    EngineCell {
        engine: Some(Box::new(windows::Engine::init())),
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
                #[cfg(any(target_os = "windows", target_os = "linux"))]
                Type::Windows => windows(),
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
    ButtonLShoulder,  // Left bumper
    ButtonRShoulder,  // Right bumper
    ButtonLJoystick,
    ButtonRJoystick,
    ButtonMenu,
    DPadUp,
    DPadDown,
    DPadLeft,
    DPadRight,
    KeyW,
    KeyA,
    KeyS,
    KeyD,
    KeyQ,
    KeyE,
    KeySpace,
    KeyEnter,
    KeyEscape,
    KeyShift,
    KeyControl,
    KeyTab,
    KeyI,
    KeyF,
    KeyG,
    MouseLeft,
    MouseRight,
    MouseMiddle,
}

#[derive(Hash, Clone, Copy, Debug, PartialEq, Eq)]
pub enum Axis {
    Mouse,
    LeftJoystick,
    RightJoystick,
    MouseWheel,
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
    fn raw(&self) -> *mut c_void;
}

pub trait Engine {
    fn surface_create(&self) -> Box<dyn Surface>;

    fn gfx_create(&self, surface: &dyn Surface) -> Box<dyn Gfx>;
    
    fn physx(&self) -> Option<&dyn Physx>;
    fn physx_mut(&mut self) -> Option<&mut (dyn Physx + '_)>;

    fn set_origin(&self, origin: math::Vec3<i64>);
    fn cell_set(&self, position: math::Vec3<i64>, tile: tile::Type);
    fn cell_frustum(&self) -> Frustum;

    fn actor_create(&self, ty: Actor) -> *mut Actor;
    fn actor_move(&self, actor: *mut Actor, position: math::Vec3f);
    fn actor_rotate(&self, actor: *mut Actor, rotation: math::Quat);
    fn actor_position(&self, actor: *mut Actor) -> math::Vec3f;
    fn actor_rotation(&self, actor: *mut Actor) -> math::Quat;

    fn input_update(&self);
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

#[derive(Clone, Copy, Hash, PartialEq, Eq)]
#[repr(C)]
pub enum Binding {
    MoveHorizontal,
    MoveVertical,
    MoveUpDown,  // For jetpack/vertical movement
    Cursor,
    Select,
    Escape,
    LookHorizontal,
    LookVertical,
    Jump,        // Space for jump/jetpack
    Sprint,      // Left trigger for sprint
    Use,         // X button for use/interact
    Build,       // B button for build mode
    Crouch,      // Right stick click for crouch
    Inventory,   // Y button for inventory
    Roll,        // For ship rolling
    Zoom,        // Mouse wheel zoom
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union Data {
    pub scalar: f32,
    pub pos: (f32, f32),
    pub activate: bool,
}
