use std::ffi::c_void;
use std::pin::Pin;

use crate::{
    gfx::{Gfx, vk::Vulkan},
    surface::desktop::Desktop,
    physx::{Physx, vk::VulkanAccel},
};

#[cfg(any(target_os = "windows", target_os = "linux"))]
use crate::input::windows::{InputSystem, key_callback, mouse_move_callback, mouse_button_callback, mouse_wheel_callback};

pub struct Engine {
    input_system: InputSystem,
    physx: Option<Box<dyn Physx>>,
}

impl Engine {
    pub fn init() -> Self {
        println!("[DEBUG] Windows Engine::init called");
        
        // Try to create physics engine
        let physx = VulkanAccel::new().map(|p| Box::new(p) as Box<dyn Physx>);
        if physx.is_some() {
            println!("[DEBUG] Physics engine created successfully");
        } else {
            println!("[DEBUG] Failed to create physics engine, running without physics");
        }
        
        let engine = Engine {
            input_system: InputSystem::new(),
            physx,
        };
        println!("[DEBUG] Windows Engine created with InputSystem at {:?}", &engine.input_system as *const _);
        engine
    }
}

impl super::Engine for Engine {
    fn surface_create(&self) -> Box<dyn super::Surface> {
        let mut desktop = Desktop::open();
        
        // Set up input callbacks
        // IMPORTANT: We need a stable pointer to the InputSystem that won't move
        let input_system_ptr = &self.input_system as *const InputSystem as *mut InputSystem as *mut c_void;
        println!("[DEBUG] Engine::surface_create: input_system_ptr={:?}", input_system_ptr);
        
        desktop.setup_input_callbacks(
            input_system_ptr,
            key_callback,
            mouse_move_callback,
            mouse_button_callback,
            mouse_wheel_callback,
        );
        
        Box::new(desktop)
    }

    fn gfx_create(&self, surface: &dyn super::Surface) -> Box<dyn Gfx> {
        let gfx = Vulkan::new(surface);
        
        // Try to initialize GPU physics if we have both graphics and physics
        if let Some(physx) = self.physx.as_ref() {
            // Get the renderer pointer from Vulkan and initialize GPU physics
            if let Some(vk_accel) = physx.as_any().downcast_ref::<VulkanAccel>() {
                let renderer_ptr = gfx.as_any().downcast_ref::<Vulkan>()
                    .map(|v| v.get_renderer_ptr())
                    .unwrap_or(std::ptr::null_mut());
                
                if !renderer_ptr.is_null() {
                    vk_accel.init_from_renderer(renderer_ptr as *mut c_void);
                    println!("[DEBUG] GPU physics acceleration initialized");
                } else {
                    println!("[DEBUG] Failed to get renderer pointer for GPU physics");
                }
            }
        }
        
        gfx
    }
    
    fn physx(&self) -> Option<&dyn Physx> {
        self.physx.as_ref().map(|p| p.as_ref())
    }
    
    fn physx_mut(&mut self) -> Option<&mut (dyn Physx + '_)> {
        match self.physx.as_mut() {
            Some(p) => Some(p.as_mut()),
            None => None,
        }
    }

    fn set_origin(&self, _origin: crate::math::Vec3<i64>) {
        todo!()
    }

    fn cell_set(&self, position: crate::math::Vec3<i64>, tile: crate::tile::Type) {
        todo!()
    }

    fn cell_frustum(&self) -> super::Frustum {
        todo!()
    }

    fn actor_create(&self, ty: super::Actor) -> *mut super::Actor {
        todo!()
    }

    fn actor_move(&self, actor: *mut super::Actor, position: crate::math::Vec3f) {
        todo!()
    }

    fn actor_rotate(&self, actor: *mut super::Actor, rotation: crate::math::Quat) {
        todo!()
    }

    fn actor_position(&self, actor: *mut super::Actor) -> crate::math::Vec3f {
        todo!()
    }

    fn actor_rotation(&self, actor: *mut super::Actor) -> crate::math::Quat {
        todo!()
    }

    fn input_update(&self) {
        if let Ok(mut state) = self.input_system.state().lock() {
            state.update();
        }
    }

    fn input_binding_data(&self, bind: super::Binding) -> super::Data {
        if let Ok(state) = self.input_system.state().lock() {
            state.get_binding_data(bind)
        } else {
            match bind {
                super::Binding::Cursor => super::Data { pos: (0.0, 0.0) },
                super::Binding::MoveHorizontal | super::Binding::MoveVertical | 
                super::Binding::MoveUpDown | super::Binding::LookHorizontal | 
                super::Binding::LookVertical | super::Binding::Roll | 
                super::Binding::Zoom => super::Data { scalar: 0.0 },
                super::Binding::Select | super::Binding::Escape | 
                super::Binding::Jump | super::Binding::Sprint | 
                super::Binding::Use | super::Binding::Build | 
                super::Binding::Crouch | super::Binding::Inventory => super::Data { activate: false },
            }
        }
    }

    fn input_binding_activate(&self, button: super::Button, activate: bool) {
        if let Ok(mut state) = self.input_system.state().lock() {
            state.set_button_state(button, activate);
        }
    }

    fn input_binding_move(&self, axis: super::Axis, x: f32, y: f32) {
        if let Ok(mut state) = self.input_system.state().lock() {
            state.set_axis_state(axis, x, y);
        }
    }

    fn debug_value(&self, name: Box<dyn core::fmt::Display>) {
        todo!()
    }
}
