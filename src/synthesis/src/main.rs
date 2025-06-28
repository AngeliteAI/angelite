use std::{
    ptr,
    time::{Duration, Instant},
};

use glam::Vec2;
use major::{
    engine::Binding,
    math,
    physx::Physx,
};

mod camera_controller;
mod voxel_world;
mod voxel_renderer;

// Dummy physics implementation
struct DummyPhysics;

impl Physx for DummyPhysics {
    fn as_any(&self) -> &dyn std::any::Any { self }
    fn rigidbody_create(&self) -> *mut major::physx::Rigidbody { std::ptr::null_mut() }
    fn rigidbody_destroy(&self, _rigidbody: *mut major::physx::Rigidbody) {}
    fn rigidbody_mass(&self, _rigidbody: *mut major::physx::Rigidbody, _mass: f32) {}
    fn rigidbody_friction(&self, _rigidbody: *mut major::physx::Rigidbody, _friction: f32) {}
    fn rigidbody_restitution(&self, _rigidbody: *mut major::physx::Rigidbody, _restitution: f32) {}
    fn rigidbody_linear_damping(&self, _rigidbody: *mut major::physx::Rigidbody, _linear_damping: f32) {}
    fn rigidbody_angular_damping(&self, _rigidbody: *mut major::physx::Rigidbody, _angular_damping: f32) {}
    fn rigidbody_angular_moment(&self, _rigidbody: *mut major::physx::Rigidbody, _angular_moment: math::Vec3f) {}
    fn rigidbody_center_of_mass(&self, _rigidbody: *mut major::physx::Rigidbody, _center_of_mass: math::Vec3f) {}
    fn rigidbody_set_half_extents(&self, _rigidbody: *mut major::physx::Rigidbody, _half_extents: math::Vec3f) {}
    fn rigidbody_reposition(&self, _rigidbody: *mut major::physx::Rigidbody, _position: math::Vec3f) {}
    fn rigidbody_orient(&self, _rigidbody: *mut major::physx::Rigidbody, _orientation: math::Quat) {}
    fn rigidbody_move(&self, _rigidbody: *mut major::physx::Rigidbody, _velocity: math::Vec3f) {}
    fn rigidbody_accelerate(&self, _rigidbody: *mut major::physx::Rigidbody, _acceleration: math::Vec3f) {}
    fn rigidbody_impulse(&self, _rigidbody: *mut major::physx::Rigidbody, _impulse: math::Vec3f) {}
    fn rigidbody_angular_impulse(&self, _rigidbody: *mut major::physx::Rigidbody, _angular_impulse: math::Vec3f) {}
    fn rigidbody_apply_force_at_point(&self, _rigidbody: *mut major::physx::Rigidbody, _force: math::Vec3f, _point: math::Vec3f) {}
    fn rigidbody_apply_impulse_at_point(&self, _rigidbody: *mut major::physx::Rigidbody, _impulse: math::Vec3f, _point: math::Vec3f) {}
    fn rigidbody_get_position(&self, _rigidbody: *mut major::physx::Rigidbody) -> math::Vec3f { math::Vec3f::zero() }
    fn rigidbody_get_orientation(&self, _rigidbody: *mut major::physx::Rigidbody) -> math::Quat { math::Quat::identity() }
    fn rigidbody_get_linear_velocity(&self, _rigidbody: *mut major::physx::Rigidbody) -> math::Vec3f { math::Vec3f::zero() }
    fn rigidbody_get_angular_velocity(&self, _rigidbody: *mut major::physx::Rigidbody) -> math::Vec3f { math::Vec3f::zero() }
    fn step(&self, _delta_time: f32) {}
}

use camera_controller::CameraController;
use voxel_world::{VoxelWorld, WorldConfig, VoxelModification};
use voxel_renderer::VoxelChunkRenderer;
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

#[derive(Debug, Clone)]
pub struct Entity {
    actor: *mut major::engine::Actor,
    action: Option<Action>,
    action_cooldown: Duration,
    action_last: Instant,
    position: glam::Vec2,
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

pub fn main() {
    let engine = major::current_engine();
    let surface = engine.surface_create();
    let gfx = engine.gfx_create(&*surface);
    
    // Get physics engine if available
    let has_physics = engine.physx().is_some();
    
    // Initialize voxel world
    let vulkan_context: std::sync::Arc<dyn major::gfx::Gfx> = std::sync::Arc::from(gfx);
    // For now, we'll skip physics since we can't clone it
    // TODO: Properly handle physics context sharing
    let physics_context: std::sync::Arc<std::sync::RwLock<dyn major::physx::Physx>> = 
        std::sync::Arc::new(std::sync::RwLock::new(DummyPhysics {}));
    
    let world_config = WorldConfig {
        chunk_size: 32,
        region_size: 4,
        view_distance: 256.0,
        physics_distance: 128.0,
        voxel_size: 1.0,
        enable_compression: true,
        enable_physics: has_physics,
        enable_lod: true,
    };
    
    // Create tokio runtime for async operations
    let runtime = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    
    let mut voxel_world = VoxelWorld::new(vulkan_context.clone(), physics_context, world_config);
    
    // Generate initial world
    println!("Generating initial voxel world...");
    runtime.block_on(async {
        voxel_world.update(math::Vec3f::xyz(0.0, 0.0, 5.0), 0.0).await.unwrap();
    });

    // Create voxel chunk renderer
    let mut voxel_renderer = VoxelChunkRenderer::new(vulkan_context.clone());
    
    // Get initial chunk data and update renderer
    if let Some(chunks) = voxel_world.get_chunks_for_rendering() {
        for (chunk_pos, vertices) in chunks {
            let chunk_id = voxel_renderer::ChunkId(chunk_pos.0, chunk_pos.1, chunk_pos.2);
            voxel_renderer.update_chunk(chunk_id, vertices);
        }
    }

    // Track when chunks change
    let mut last_chunk_update = std::time::Instant::now();

    let camera = vulkan_context.camera_create();
    
    // Set up perspective projection matrix
    let aspect_ratio = 16.0 / 9.0; // Assuming 16:9 aspect ratio
    let fov = std::f32::consts::PI / 4.0; // 45 degrees
    let near = 0.1;
    let far = 100.0;
    
    let projection_mat = math::Mat4f::perspective(fov, aspect_ratio, near, far);
    // Convert column-major [[f32; 4]; 4] to flat [f32; 16]
    let proj_data = projection_mat.to_array();
    let mut proj_flat = [0.0f32; 16];
    let mut idx = 0;
    for col in 0..4 {
        for row in 0..4 {
            proj_flat[idx] = proj_data[col][row];
            idx += 1;
        }
    }
    vulkan_context.camera_set_projection(camera, &proj_flat);
    
    // Create camera controller
    let mut camera_controller = CameraController::new();
    
    // Initialize physics for camera if available
    if has_physics {
        let physx = engine.physx().unwrap();
        camera_controller.init_physics(physx);
    }
    
    // Set initial camera transform
    vulkan_context.camera_set_transform(camera, &camera_controller.get_view_matrix());
    vulkan_context.camera_set_main(camera);
    
    // Key press state to prevent repeated actions
    let mut menu_key_was_pressed = false;
    
    let _cube_body = if has_physics {
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
        vulkan_context.camera_set_transform(camera, &view_matrix);
        
        // Update voxel world
        let camera_pos = camera_controller.get_position();
        runtime.block_on(async {
            voxel_world.update(camera_pos, delta_time).await.unwrap();
        });
        
        // Only regenerate mesh when chunks have been modified
        let needs_mesh_update = voxel_world.chunks_modified_since(&last_chunk_update);
        
        if needs_mesh_update {
            // Get updated chunk data and update renderer
            if let Some(chunks) = voxel_world.get_chunks_for_rendering() {
                for (chunk_pos, vertices) in chunks {
                    let chunk_id = voxel_renderer::ChunkId(chunk_pos.0, chunk_pos.1, chunk_pos.2);
                    voxel_renderer.update_chunk(chunk_id, vertices);
                }
            }
            last_chunk_update = std::time::Instant::now();
        }
        
        // Handle voxel interactions
        let select_binding = unsafe { engine.input_binding_data(major::engine::Binding::Select) };
        if unsafe { select_binding.activate } {
            // Place voxel
            let camera_pos = camera_controller.get_position();
            let camera_forward = camera_controller.get_forward_vector();
            
            if let Some(hit) = voxel_world.raycast(camera_pos, camera_forward, 100.0) {
                // Place a voxel adjacent to the hit
                let place_pos = hit.position + hit.normal * voxel_world.voxel_size();
                runtime.block_on(async {
                    voxel_world.modify_voxels(vec![VoxelModification {
                        position: place_pos,
                        new_voxel: major::universe::Voxel(4), // Some material
                    }]).await.unwrap();
                });
            }
        }
        
        // Use a different binding for right click
        engine.input_binding_activate(major::engine::Button::MouseRight, true);
        let use_binding = unsafe { engine.input_binding_data(major::engine::Binding::Use) };
        if unsafe { use_binding.activate } {
            // Remove voxel
            let camera_pos = camera_controller.get_position();
            let camera_forward = camera_controller.get_forward_vector();
            
            if let Some(hit) = voxel_world.raycast(camera_pos, camera_forward, 100.0) {
                runtime.block_on(async {
                    voxel_world.modify_voxels(vec![VoxelModification {
                        position: hit.position,
                        new_voxel: major::universe::Voxel(0), // Air
                    }]).await.unwrap();
                });
            }
        }
        
        // Save/Load using controller menu button (START button)
        // We'll use the Escape binding which includes the menu button
        let menu_binding = unsafe { engine.input_binding_data(major::engine::Binding::Escape) };
        let menu_pressed = unsafe { menu_binding.activate };
        
        // Check for menu button press (not held)
        if menu_pressed && !menu_key_was_pressed {
            // Toggle between save and load based on a simple state
            static mut MENU_ACTION_STATE: bool = false;
            unsafe {
                if MENU_ACTION_STATE {
                    // Save world
                    runtime.block_on(async {
                        match voxel_world.save_world("world.save").await {
                            Ok(_) => println!("World saved successfully"),
                            Err(e) => println!("Failed to save world: {}", e),
                        }
                    });
                } else {
                    // Load world
                    runtime.block_on(async {
                        match voxel_world.load_world("world.save").await {
                            Ok(_) => println!("World loaded successfully"),
                            Err(e) => println!("Failed to load world: {}", e),
                        }
                    });
                }
                MENU_ACTION_STATE = !MENU_ACTION_STATE;
            }
        }
        menu_key_was_pressed = menu_pressed;
        
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
        vulkan_context.frame_begin();
        vulkan_context.batch_queue_draw(voxel_renderer.get_batch());
        vulkan_context.frame_commit_draw();
        vulkan_context.frame_end();
    }
}
