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
    // We can't directly convert Box<dyn Gfx> to Arc<dyn Gfx + Send + Sync>
    // For now, create a wrapper that holds the gfx reference
    // Note: This assumes the Gfx implementation is Send + Sync
    let vulkan_context = unsafe {
        std::sync::Arc::from_raw(std::mem::transmute::<*mut dyn major::gfx::Gfx, *const (dyn major::gfx::Gfx + Send + Sync)>(Box::into_raw(gfx)))
    };
    // For now, we'll skip physics since we can't clone it
    // TODO: Properly handle physics context sharing
    let physics_context: std::sync::Arc<std::sync::RwLock<dyn major::physx::Physx>> = 
        std::sync::Arc::new(std::sync::RwLock::new(DummyPhysics {}));
    
    let world_config = WorldConfig {
        chunk_size: 64, // Use 64x64x64 chunks to match mesh generator expectations
        region_size: 4,
        view_distance: 256.0,  // Full view distance
        physics_distance: 128.0,
        voxel_size: 1.0,
        enable_compression: true,
        enable_physics: has_physics,
        enable_lod: true,
        mesh_generator: voxel_world::MeshGeneratorType::SimpleCube, // Start with Minecraft-style rendering
    };
    
    // Create tokio runtime for async operations with multi-threading
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(4)
        .enable_all()
        .build()
        .unwrap();
    
    let mut voxel_world = VoxelWorld::new(vulkan_context.clone(), physics_context, world_config);
    
    // Create camera controller first
    let mut camera_controller = CameraController::new();
    
    // Generate initial world with camera position
    println!("Generating initial voxel world...");
    let initial_camera_pos = camera_controller.get_position();
    
    // Skip test terrain to allow actual world generation
    // voxel_world.create_test_terrain();
    
    // Initial world generation with timeout
    match runtime.block_on(async {
        tokio::time::timeout(
            tokio::time::Duration::from_secs(5),
            voxel_world.update(initial_camera_pos, 0.0)
        ).await
    }) {
        Ok(Ok(())) => println!("Initial world generation started"),
        Ok(Err(e)) => println!("Initial world generation error: {}", e),
        Err(_) => println!("Initial world generation timed out"),
    }

    // Create voxel chunk renderer  
    let mut voxel_renderer = VoxelChunkRenderer::new(vulkan_context.clone() as std::sync::Arc<dyn major::gfx::Gfx>);
    
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
        
        // Check for NaN
        if camera_pos[0].is_nan() || camera_pos[1].is_nan() || camera_pos[2].is_nan() {
            println!("ERROR: Camera position is NaN! [{}, {}, {}]", camera_pos[0], camera_pos[1], camera_pos[2]);
            println!("Resetting camera to origin...");
            camera_controller.set_position(math::Vec3f::xyz(0.0, -5.0, 5.0));
            let camera_pos = camera_controller.get_position();
        }
        
        // Update voxel world with timeout to allow spawned tasks to run
        match runtime.block_on(async {
            tokio::time::timeout(
                tokio::time::Duration::from_millis(100),
                voxel_world.update(camera_pos, delta_time)
            ).await
        }) {
            Ok(Ok(())) => {}, // Success
            Ok(Err(e)) => println!("Voxel world update error: {}", e),
            Err(_) => println!("Voxel world update timed out"),
        }
        
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
                match runtime.block_on(async {
                    tokio::time::timeout(
                        tokio::time::Duration::from_millis(50),
                        voxel_world.modify_voxels(vec![VoxelModification {
                            position: place_pos,
                            new_voxel: major::universe::Voxel(4), // Some material
                        }])
                    ).await
                }) {
                    Ok(Ok(())) => {},
                    Ok(Err(e)) => println!("Failed to place voxel: {}", e),
                    Err(_) => println!("Place voxel timed out"),
                }
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
                match runtime.block_on(async {
                    tokio::time::timeout(
                        tokio::time::Duration::from_millis(50),
                        voxel_world.modify_voxels(vec![VoxelModification {
                            position: hit.position,
                            new_voxel: major::universe::Voxel(0), // Air
                        }])
                    ).await
                }) {
                    Ok(Ok(())) => {},
                    Ok(Err(e)) => println!("Failed to remove voxel: {}", e),
                    Err(_) => println!("Remove voxel timed out"),
                }
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
        
        // Switch mesh generators using B button (crouch binding)
        static mut MESH_GENERATOR_TOGGLE: bool = false;
        let crouch_binding = unsafe { engine.input_binding_data(major::engine::Binding::Crouch) };
        let crouch_pressed = unsafe { crouch_binding.activate };
        
        if crouch_pressed && !unsafe { MESH_GENERATOR_TOGGLE } {
            // Toggle between mesh generators
            static mut CURRENT_GENERATOR: bool = false; // false = BinaryGreedy, true = SimpleCube
            unsafe {
                CURRENT_GENERATOR = !CURRENT_GENERATOR;
                if CURRENT_GENERATOR {
                    println!("Switching to Simple Cube mesh generator");
                    voxel_world.set_mesh_generator(voxel_world::MeshGeneratorType::SimpleCube);
                } else {
                    println!("Switching to Binary Greedy mesh generator");
                    voxel_world.set_mesh_generator(voxel_world::MeshGeneratorType::BinaryGreedy);
                }
            }
        }
        unsafe { MESH_GENERATOR_TOGGLE = crouch_pressed; }
        
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
                println!("Mesh Generator: {:?}", voxel_world.mesh_generator_type());
                println!("==================");
                println!("Controls:");
                println!("  WASD/Left Stick: Move");
                println!("  Mouse/Right Stick: Look");
                println!("  Left Click/RT: Place voxel");
                println!("  Right Click/LT: Remove voxel");
                println!("  B/Circle: Toggle mesh generator");
                println!("  Start/Menu: Save/Load world\n");
            }
        }
        
        // Render frame
        vulkan_context.frame_begin();
        vulkan_context.batch_queue_draw(voxel_renderer.get_batch());
        vulkan_context.frame_commit_draw();
        vulkan_context.frame_end();
    }
}
