const trans = @import("trans.zig");

const Transform = trans.Transform;

pub const Brush = extern struct {
    id: u64,
};

pub const Condition = extern struct {
    id: u64,
};

// Create brushes
pub extern fn brush(name: []const u8) *Brush;

// Apply a material when a condition is met
pub extern fn when(brush: *Brush, condition: *Condition, material: u16) *Brush;

// Combine brushes (later brushes override earlier ones)
pub extern fn layer(brushes: []const Brush) *Brush;

// Create conditions
pub extern fn depth(min: f32, max: f32) *Condition;
pub extern fn height(min: f32, max: f32) *Condition;
pub extern fn slope(min: f32, max: f32) *Condition;
pub extern fn noise(seed: u64, threshold: f32, scale: f32) *Condition;
pub extern fn curvature(min: f32, max: f32) *Condition;
pub extern fn distance(point_x: f32, point_y: f32, point_z: f32, min: f32, max: f32) *Condition;

// Logical operators for conditions
pub extern fn logical_and(a: *Condition, b: *Condition) *Condition;
pub extern fn logical_or(a: *Condition, b: *Condition) *Condition;
pub extern fn logical_not(condition: *Condition) *Condition;

// Special brush operations
pub extern fn scatter(base_brush: *Brush, feature_brush: *Brush, density: f32, seed: u64) *Brush;

// Apply brushes to an SDF to generate material data
pub extern fn paint(sdf: *anyopaque, size_x: u32, size_y: u32, size_z: u32, brush: *Brush) ?*anyopaque;
