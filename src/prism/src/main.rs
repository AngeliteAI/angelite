use crate::ffi::gfx::{render, surface};
use std::{f32::consts::PI, ptr};

mod ffi;

fn main() {
    // Create a surface
    let surface_ptr = unsafe { surface::createSurface() };
    if surface_ptr.is_null() {
        return;
    }

    // Initialize the renderer with our surface
    // // Get a reference to the renderer (assuming init creates it internally)
    // // In a real implementation, you might get this from the init function
    let renderer_ptr = unsafe { render::init(surface_ptr) };
    let camera = render::Camera::new();
    dbg!(renderer_ptr);
    if renderer_ptr.is_null() {
        unsafe {
            render::shutdown(renderer_ptr);
            surface::destroySurface(surface_ptr);
        };
        return;
    }

    // // Main game loop
    loop {
        // Poll for window events
        unsafe { surface::pollSurface() };

        camera.projection = m4Persp(PI / 2.0, 1.0, 0.1, 100.0);

        unsafe {
            render::update_camera(renderer_ptr, &camera);
        }

        // Render the frame
        unsafe { render::render(renderer_ptr) };

        // Here you would typically add:
        // 1. Check for exit condition
        // 2. Update game state
        // 3. Handle input
        // 4. Fixed time step logic
    }

    // // Cleanup (in a real app, we'd need to handle Ctrl+C/signal interruption)
    // unsafe {
    //     render::shutdown();
    //     surface::destroySurface(surface_ptr);
    // }
}
