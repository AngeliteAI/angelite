use libc;
use std::ffi::c_void;
use std::fmt;

use crate::{
    gfx::{Gfx, metal::MetalRenderer},
    surface::desktop::Desktop,
    tile,
};

use super::{Actor, Data, Frustum};

pub struct Engine {}

impl Engine {
    pub fn init() -> Self {
        unsafe {
            engine_create();
        }
        Engine {}
    }
}
unsafe extern "C" {
    fn engine_create();
    fn engine_set_focus_point(x: f32, y: f32);
    fn engine_set_origin(x: i128, y: i128);
    fn engine_cell_set(x: i128, y: i128, tile: u32);
    fn engine_cell_frustum() -> Frustum;
    fn engine_actor_create(ty: Actor) -> *mut Actor;
    fn engine_actor_move(actor: *mut Actor, x: f32, y: f32);
    fn engine_input_binding_data(bind: u32) -> Data;
    fn engine_input_binding_activate(button: u32, activate: bool);
    fn engine_input_binding_move(axis: u32, x: f32, y: f32);
    fn engine_debug_value(name: *const i8);
}

impl super::Engine for Engine {
    fn set_focus_point(&self, x: f32, y: f32) {
        unsafe {
            engine_set_focus_point(x, y);
        }
    }

    fn set_origin(&self, x: i128, y: i128) {
        unsafe {
            engine_set_origin(x, y);
        }
    }

    fn cell_set(&self, x: i128, y: i128, tile: tile::Type) {
        unsafe {
            engine_cell_set(x, y, tile as u32);
        }
    }

    fn cell_frustum(&self) -> super::Frustum {
        unsafe {
            let mut frustum_ptr = engine_cell_frustum();
            let frustum = *(&mut frustum_ptr as *mut super::Frustum);
            // Free the memory allocated by Swift
            frustum
        }
    }

    fn actor_create(&self, ty: Actor) -> *mut super::Actor {
        unsafe { engine_actor_create(ty.into()) }
    }

    fn actor_move(&self, actor: *mut Actor, x: f32, y: f32) {
        unsafe {
            engine_actor_move(actor, x, y);
        }
    }

    fn input_binding_data(&self, bind: super::Binding) -> super::Data {
        unsafe {
            let mut data_ptr = engine_input_binding_data(bind as u32);
            let data = *(&mut data_ptr as *mut super::Data);
            // Free the memory allocated by Swift
            data
        }
    }

    fn input_binding_activate(&self, button: super::Button, activate: bool) {
        unsafe {
            engine_input_binding_activate(button as u32, activate);
        }
    }

    fn input_binding_move(&self, axis: super::Axis, x: f32, y: f32) {
        unsafe {
            engine_input_binding_move(axis as u32, x, y);
        }
    }

    fn debug_value(&self, name: Box<dyn fmt::Display>) {
        unsafe {
            engine_debug_value(format!("{}", name).as_str().as_ptr() as *const i8);
        }
    }

    fn surface_create(&self) -> Box<dyn super::Surface> {
        Box::new(Desktop::open())
    }

    fn gfx_create(&self, surface: Box<dyn super::Surface>) -> Box<dyn crate::gfx::Gfx> {
        MetalRenderer::new(surface)
    }
}
