pub const Transform = struct { id: u64 };

pub const Dim = enum { X, Y, Z };

pub const Noise = extern struct {
    seed: u64 = 12345,
    frequency: f32 = 0.1,
    amplitude: f32 = 1.0,
    octaves: u32 = 1,
    lacunarity: f32 = 2.0,
    persistence: f32 = 0.5,
};

pub const Bias = extern struct {
    dimension: Dim,
    squish_factor: f32 = 1.0, // Compression factor (< 1.0 compresses, > 1.0 expands)
    height_offset: f32 = 0.0, // Global height shift
    scale_y: f32 = 1.0, // Vertical scale multiplier
    scale_factor: f32 = 1.0, // Overall terrain scale factor
};

pub extern fn box(width: f32, height: f32, depth: f32) *Transform;
pub extern fn sphere(radius: f32) *Transform;
pub extern fn cylinder(radius: f32, height: f32) *Transform;
pub extern fn cone(radius: f32, height: f32) *Transform;
pub extern fn capsule(radius: f32, height: f32) *Transform;
pub extern fn torus(major_radius: f32, minor_radius: f32) *Transform;

pub extern fn plane(height: f32) *Transform;
pub extern fn heightmap(size: f32, height: f32) *Transform;

pub extern fn translate(vol: *Transform, x: f32, y: f32, z: f32) *Transform;
pub extern fn rotate(vol: *Transform, x: f32, y: f32, z: f32, angle: f32) *Transform;
pub extern fn scale(vol: *Transform, x: f32, y: f32, z: f32) *Transform;

pub extern fn bias(vol: *Transform, bias: Bias) *Transform;
pub extern fn flattenBelow(vol: *Transform, height: f32, transition: f32) *Transform;
pub extern fn amplifyAbove(vol: *Transform, height: f32, factor: f32, transition: f32) *Transform;

pub extern fn join(a: *Transform, b: *Transform) *Transform;
pub extern fn cut(a: *Transform, b: *Transform) *Transform;
pub extern fn intersect(a: *Transform, b: *Transform) *Transform;
pub extern fn blend(a: *Transform, b: *Transform, smoothness: f32) *Transform;

pub extern fn elongate(vol: *Transform, x: f32, y: f32, z: f32) *Transform;
pub extern fn round(vol: *Transform, radius: f32) *Transform;
pub extern fn shell(vol: *Transform, thickness: f32) *Transform;

pub extern fn perlinNoise(params: *Noise) *Transform;
pub extern fn simplexNoise(params: *Noise) *Transform;
pub extern fn worleyNoise(params: *Noise) *Transform;
pub extern fn ridgedNoise(params: *Noise) *Transform;

pub extern fn displace(vol: *Transform, noise: *Transform, strength: f32) *Transform;
pub extern fn warp(vol: *Transform, noise: *Transform, strength: f32) *Transform;
pub extern fn bend(vol: *Transform, angle: f32, axis: u8) *Transform;
pub extern fn twist(vol: *Transform, strength: f32, axis: u8) *Transform;

pub extern fn repeat(vol: *Transform, x: f32, y: f32, z: f32) *Transform;
pub extern fn repeatLimited(vol: *Transform, x: f32, y: f32, z: f32, count: u32) *Transform;

pub extern fn generate(vol: *Transform, size_x: u32, size_y: u32, size_z: u32) ?*anyopaque;
pub extern fn release(sdf: *anyopaque) void;
