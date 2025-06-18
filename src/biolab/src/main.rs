use std::{thread, time::Duration};

use major::{create_input, create_rect, create_surface, draw::Rect, graphics::RenderContext};

pub fn main() {
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
    ctx.set_camera_zoom(0.5); // Start zoomed out to see more of the grid

    // Create static rectangles
    let mut red_rect = create_rect();
    red_rect.width(100);
    red_rect.height(100);
    red_rect.x(100);
    red_rect.y(100);
    red_rect.albedo([1.0, 0.0, 0.0]); // Red

    let mut green_rect = create_rect();
    green_rect.width(90);
    green_rect.height(80);
    green_rect.x(300);
    green_rect.y(150);
    green_rect.albedo([0.0, 1.0, 0.0]); // Green
    green_rect.alpha(0.8); // Slightly transparent

    let mut blue_rect = create_rect();
    blue_rect.width(120);
    blue_rect.height(60);
    blue_rect.x(200);
    blue_rect.y(250);
    blue_rect.albedo([0.0, 0.0, 1.0]); // Blue

    println!("Camera controls:");
    println!("  WASD or arrow keys - Move camera");
    println!("  Q/E - Zoom out/in");
    println!("Enter main loop - close window to exit");

    // Variables for camera movement
    let camera_speed = 10.0; // base pixels per frame
    let zoom_speed = 1.05; // 5% zoom change per keypress
    let frame_duration = Duration::from_millis(16); // ~60 FPS

    // Create a grid of colored rectangles in world space
    // Store (x, y, color) for each rectangle
    let mut world_rects: Vec<(i32, i32, [f32; 3])> = Vec::new();

    // Create a grid of rectangles using world coordinates
    // (0,0) is the center of the world
    for x in -50..=50 {
        for y in -50..=50 {
            // Create rectangles every 100 units for a more visible grid
            if x % 10 == 0 || y % 10 == 0 {
                let world_x = x * 50; // 50 units between grid cells
                let world_y = y * 50;

                // Different colors based on position
                let r = (x as f32 + 50.0) / 100.0;
                let g = (y as f32 + 50.0) / 100.0;
                let b = ((x + y) as f32 + 100.0) / 200.0;

                // Store position and color for later recreation
                world_rects.push((world_x, world_y, [r, g, b]));
            }
        }
    }

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

        // Add a stationary player marker at the center of the world (0,0)
        let mut player_rect = create_rect();
        player_rect.width(40);
        player_rect.height(40);
        player_rect.x(0);
        player_rect.y(0);
        player_rect.albedo([1.0, 1.0, 0.0]); // Yellow
        ctx.add_rect(player_rect);

        // Add all the grid rectangles
        for &(x, y, color) in &world_rects {
            // x and y are already in world coordinates (can be negative)
            let mut rect = create_rect();
            rect.width(40);
            rect.height(40);
            rect.x(x);
            rect.y(y);
            rect.albedo(color);
            ctx.add_rect(rect);
        }

        // Add coordinate axes for reference
        // X-axis (horizontal, centered at y=0)
        let mut x_axis = create_rect();
        x_axis.width(5000);
        x_axis.height(2);
        x_axis.x(0);
        x_axis.y(0);
        x_axis.albedo([1.0, 0.0, 0.0]); // Red X-axis
        ctx.add_rect(x_axis);

        // Y-axis (vertical, centered at x=0)
        let mut y_axis = create_rect();
        y_axis.width(2);
        y_axis.height(5000);
        y_axis.x(0);
        y_axis.y(0);
        y_axis.albedo([0.0, 1.0, 0.0]); // Green Y-axis
        ctx.add_rect(y_axis);

        // Draw grid markings on the axes every 100 units
        for i in -20..=20 {
            if i == 0 {
                continue; // Skip origin
            }

            let pos = i * 100;

            // X-axis markers
            let mut x_marker = create_rect();
            x_marker.width(2);
            x_marker.height(10);
            x_marker.x(pos);
            x_marker.y(0);
            x_marker.albedo([1.0, 0.0, 0.0]);
            ctx.add_rect(x_marker);

            // Y-axis markers
            let mut y_marker = create_rect();
            y_marker.width(10);
            y_marker.height(2);
            y_marker.x(0);
            y_marker.y(pos);
            y_marker.albedo([0.0, 1.0, 0.0]);
            ctx.add_rect(y_marker);
        }

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
