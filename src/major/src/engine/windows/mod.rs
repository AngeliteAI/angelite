use crate::{
    gfx::{Gfx, vk::Vulkan},
    surface::desktop::Desktop,
};

pub struct Engine {}

impl Engine {
    pub fn init() -> Self {
        Engine {}
    }
}

impl super::Engine for Engine {
    fn surface_create(&self) -> Box<dyn super::Surface> {
        Box::new(Desktop::open())
    }

    fn gfx_create(&self, surface: Box<dyn super::Surface>) -> Box<dyn Gfx> {
        Vulkan::new(surface)
    }

    fn set_origin(&self, origin: crate::math::Vector<i64, 3>) {
        todo!()
    }

    fn cell_set(&self, position: crate::math::Vector<i64, 3>, tile: crate::tile::Type) {
        todo!()
    }

    fn cell_frustum(&self) -> super::Frustum {
        todo!()
    }

    fn actor_create(&self, ty: super::Actor) -> *mut super::Actor {
        todo!()
    }

    fn actor_move(&self, actor: *mut super::Actor, position: crate::math::Vector<f32, 3>) {
        todo!()
    }

    fn actor_rotate(&self, actor: *mut super::Actor, rotation: crate::math::Quaternion<f32>) {
        todo!()
    }

    fn actor_position(&self, actor: *mut super::Actor) -> crate::math::Vector<f32, 3> {
        todo!()
    }

    fn actor_rotation(&self, actor: *mut super::Actor) -> crate::math::Quaternion<f32> {
        todo!()
    }

    fn input_binding_data(&self, bind: super::Binding) -> super::Data {
        todo!()
    }

    fn input_binding_activate(&self, button: super::Button, activate: bool) {
        todo!()
    }

    fn input_binding_move(&self, axis: super::Axis, x: f32, y: f32) {
        todo!()
    }

    fn debug_value(&self, name: Box<dyn core::fmt::Display>) {
        todo!()
    }
}
