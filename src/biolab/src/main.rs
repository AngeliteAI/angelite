#![feature(random)]
use std::{alloc::alloc, collections::HashMap, random::random, time::Duration};

use major::{create_rect, draw::Rect};

pub struct Tile {
    ty: Type,
}

#[derive(PartialEq, Eq, Clone, Copy)]
pub enum Type {
    Grass,
    Dirt,
    Stone,
}

pub struct Chunk {
    tiles: [Tile; 64],
}

pub trait Drawer {
    fn draw(self) -> Batch;
}

impl Drawer for Chunk {
    fn draw(self) -> Batch {
        let mut x = 0;
        let mut y = 0;
        let mut u = 0;
        let mut v = 0;
        let mut rects = vec![];

        let mut mask = [false; 64];

        fn all_drawn(mask: &[bool]) -> bool {
            mask.iter().all(|&b| b)
        }

        fn get_tile(chunk: &Chunk, u: usize, v: usize) -> &Tile {
            &chunk.tiles[u + v * 8]
        }

        fn rand() -> f32 {
            random::<u64>() as f32 / u64::MAX as f32
        }

        while !all_drawn(&mask) {
            let starter = get_tile(&self, x, y).ty;

            while u < 8 && get_tile(&self, x + u, y).ty == starter {
                mask[(x + u) + y * 8] = true;
                u += 1;
            }

            while v < 8 && (x..x + u).all(|i| get_tile(&self, i, y + v).ty == starter) {
                for i in x..x + u {
                    mask[(x + i) + (y + v) * 8] = true;
                }
                v += 1;
            }

            let mut rect = create_rect();
            rect.x(x as f32);
            rect.y(y as f32);
            rect.width(u as f32);
            rect.height(v as f32);
            rect.albedo([rand(), rand(), rand()]);
            rects.push(Box::new(rect) as Box<dyn Rect>);

            x += u;
            y += v;
        }

        return Batch { rects };
    }
}

pub struct Batch {
    pub rects: Vec<Box<dyn Rect>>,
}

pub struct World {
    chunks: HashMap<[i128; 2], Chunk>,
}

pub fn main() {
    // Import the necessary modules
    use major::{
        Key, create_colored_rect, create_input, create_rect, create_surface,
        graphics::RenderContext,
    };
    use std::{thread, time::Duration, time::Instant};

    println!("Starting Angelite example with camera controls");

    // Create a surface
    let surface = create_surface();

    // Create a rendering context
    let mut ctx = RenderContext::new(surface);

    // Create an input handler for keyboard input
    let input = create_input();

    // Open the window
    ctx.open();

    // Set initial camera position to center of world
    ctx.set_camera_position(0.0, 0.0);
    ctx.set_camera_zoom(0.001); // Start zoomed out to see more of the grid

    println!("Camera controls:");
    println!("  WASD or arrow keys - Move camera");
    println!("  Q/E - Zoom out/in");
    println!("Enter main loop - close window to exit");

    // Variables for camera movement
    let camera_speed = 10.0; // base pixels per frame
    let zoom_speed = 1.05; // 5% zoom change per keypress
    let frame_duration = Duration::from_millis(16); // ~60 FPS

    // Main loop - runs until window is closed
    while ctx.is_open() {
        // Clear previous rectangles
        ctx.clear();

        // Handle input for camera movement
        let horizontal = input.get_horizontal_movement();
        let vertical = input.get_vertical_movement();

        // Get current zoom to adjust movement speed
        let zoom = ctx.camera_zoom();
        // Scale camera speed inversely with zoom level to keep perceived movement consistent
        let adjusted_speed = camera_speed / zoom;
        // Update camera position based on input
        ctx.move_camera(horizontal * adjusted_speed, vertical * adjusted_speed);

        ctx.add_rect(rect);
        // Draw the frame
        ctx.draw_frame();

        // Display camera info
        let cam_x = ctx.camera_x();
        let cam_y = ctx.camera_y();
        let zoom = ctx.camera_zoom();
        // Only print occasionally to avoid console spam
        if std::time::Instant::now().elapsed().as_millis() % 1000 < 16 {
            println!("Camera: x={:.1}, y={:.1}, zoom={:.2}", cam_x, cam_y, zoom);
        }

        // Sleep to maintain frame rate
        thread::sleep(frame_duration);
    }

    // Window was closed, clean up
    println!("Window closed, exiting");
    ctx.close();

    println!("Example completed");
}
