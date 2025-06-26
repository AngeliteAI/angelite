#![feature(random, let_chains)]
use std::{
    ptr,
    time::{Duration, Instant},
};

use glam::Vec2;
use major::{
    engine::Binding,
    math,
};

mod camera_controller;
use camera_controller::CameraController;
use quadtree::{
    Point,
};

#[derive(Debug, Clone)]
pub struct Action {
    pub ty: Type,
}

#[derive(Clone, Debug)]
pub struct EntityAccel {
    pub index: usize,
    pub pos: Vec2,
}

impl Point for EntityAccel {
    fn point(&self) -> quadtree::P2 {
        quadtree::P2::new(self.pos.x as f64, self.pos.y as f64)
    }
}
#[derive(Debug, Clone)]
pub enum Type {
    Place(Box<Entity>),
    Set(major::tile::Type),
}

impl Default for Entity {
    fn default() -> Self {
        Entity {
            actor: ptr::null_mut(),
            action: None,
            action_cooldown: Duration::from_secs(0),
            action_last: Instant::now(),
            position: Vec2::new(0.0, 0.0),
        }
    }
}
#[derive(Debug, Clone)]
pub struct Entity {
    actor: *mut major::engine::Actor,
    action: Option<Action>,
    action_cooldown: Duration,
    action_last: Instant,
    position: glam::Vec2,
}

pub fn main() {
    let engine = major::current_engine();
    let surface = engine.surface_create();
    let gfx = engine.gfx_create(&*surface);
    
    // Get physics engine if available
    let has_physics = engine.physx().is_some();

    let mesh = gfx.mesh_create();
    
    // Create vertices for all 6 faces of a cube at position (0, 0, 0)
    // The geometry shader will expand each point into a face based on the normal direction
    let cube_center = math::Vector([0.0, 0.0, 0.0]);
    let vertices = vec![
        cube_center,  // Face 0: +X (normal_dir = 0)
        cube_center,  // Face 1: -X (normal_dir = 1)
        cube_center,  // Face 2: +Y (normal_dir = 2)
        cube_center,  // Face 3: -Y (normal_dir = 3)
        cube_center,  // Face 4: +Z (normal_dir = 4)
        cube_center,  // Face 5: -Z (normal_dir = 5)
    ];
    gfx.mesh_update_vertices(mesh, &vertices);
    
    // Set normal directions for each face (0=+X, 1=-X, 2=+Y, 3=-Y, 4=+Z, 5=-Z)
    let normal_dirs = vec![
        0u32,  // +X face
        1u32,  // -X face
        2u32,  // +Y face
        3u32,  // -Y face
        4u32,  // +Z face
        5u32,  // -Z face
    ];
    gfx.mesh_update_normal_dirs(mesh, &normal_dirs);
    
    // Set different colors for each face for better visualization
    let colors = vec![
        major::gfx::Color { r: 1.0, g: 0.0, b: 0.0, a: 1.0 },  // Red for +X
        major::gfx::Color { r: 0.5, g: 0.0, b: 0.0, a: 1.0 },  // Dark red for -X
        major::gfx::Color { r: 0.0, g: 1.0, b: 0.0, a: 1.0 },  // Green for +Y
        major::gfx::Color { r: 0.0, g: 0.5, b: 0.0, a: 1.0 },  // Dark green for -Y
        major::gfx::Color { r: 0.0, g: 0.0, b: 1.0, a: 1.0 },  // Blue for +Z
        major::gfx::Color { r: 0.0, g: 0.0, b: 0.5, a: 1.0 },  // Dark blue for -Z
    ];
    gfx.mesh_update_albedo(mesh, &colors);
    
    // No indices needed for point rendering - geometry shader generates the quads
    gfx.mesh_update_indices(mesh, &[]);

    let batch = gfx.batch_create();
    gfx.batch_add_mesh(batch, mesh);

    let camera = gfx.camera_create();
    
    // Set up perspective projection matrix
    let aspect_ratio = 16.0 / 9.0; // Assuming 16:9 aspect ratio
    let fov = std::f32::consts::PI / 4.0; // 45 degrees
    let near = 0.1;
    let far = 100.0;
    
    let projection_mat = math::Mat4f::perspective(fov, aspect_ratio, near, far);
    gfx.camera_set_projection(camera, &projection_mat.to_cols_array());
    
    // Create camera controller
    let mut camera_controller = CameraController::new();
    
    // Initialize physics for camera if available
    if has_physics {
        let physx = engine.physx().unwrap();
        camera_controller.init_physics(physx);
    }
    
    // Set initial camera transform
    gfx.camera_set_transform(camera, &camera_controller.get_view_matrix());
    gfx.camera_set_main(camera);
    
    let cube_body = if has_physics {
        let physx = engine.physx().unwrap();
        let body = physx.rigidbody_create();
        if !body.is_null() {
            // Set cube as static body (infinite mass)
            physx.rigidbody_mass(body, 0.0);
            physx.rigidbody_friction(body, 0.7);
            physx.rigidbody_restitution(body, 0.3);
            physx.rigidbody_set_half_extents(body, math::Vec3f::xyz(0.5, 0.5, 0.5)); // Unit cube
            
            // Set at origin
            physx.rigidbody_reposition(body, math::Vec3f::ZERO);
            
            println!("Created cube physics body");
            Some(body)
        } else {
            None
        }
    } else {
        None
    };
    
    // Track frame timing
    let mut last_frame_time = Instant::now();
    
    loop {
        // Calculate delta time
        let now = Instant::now();
        let delta_time = (now - last_frame_time).as_secs_f32();
        last_frame_time = now;
        
        // Process window messages
        surface.poll();
        
        // Update input system (polls controllers)
        engine.input_update();
        
        // Update camera (physics integration is now handled internally)
        camera_controller.update(engine, delta_time);
        
        // Update camera transform
        let view_matrix = camera_controller.get_view_matrix();
        gfx.camera_set_transform(camera, &view_matrix);
        
        // Debug output every second
        static mut DEBUG_TIMER: f32 = 0.0;
        unsafe {
            DEBUG_TIMER += delta_time;
            if DEBUG_TIMER > 1.0 {
                DEBUG_TIMER = 0.0;
                let pos = camera_controller.get_position();
                let euler = camera_controller.get_euler_angles();
                println!("\n=== Camera State ===");
                println!("Position: [{:.2}, {:.2}, {:.2}]", pos[0], pos[1], pos[2]);
                println!("Rotation: [Yaw: {:.1}°, Pitch: {:.1}°, Roll: {:.1}°]", euler.0, euler.1, euler.2);
                println!("==================\n");
            }
        }
        
        // Render frame
        gfx.frame_begin();
        gfx.batch_queue_draw(batch);
        gfx.frame_commit_draw();
        gfx.frame_end();
    }
}
