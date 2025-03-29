const vec = @import("math/include/vec.zig");
const mat = @import("math/include/mat.zig");
const quat = @import("math/include/quat.zig");
const vol = @import("vol.zig");
const surface = @import("surface.zig");

const Surface = surface.Surface;
const Volume = vol.Volume;

pub const Camera = extern struct {
    position: vec.Vec3,
    rotation: quat.Quat,
    projection: mat.Mat4,
};

pub const RenderSettings = extern struct {
    view_distance: u32 = 16,
    enable_ao: bool = true,
};

pub const Renderer = extern struct { id: u64 };

pub extern fn init(surface: *Surface) bool;
pub extern fn shutdown() void;
pub extern fn supportsMultiple() bool;

// Camera control
pub extern fn setCamera(renderer: *Renderer, camera: *Camera) void;
pub extern fn setSettings(renderer: *Renderer, settings: *RenderSettings) void;

// Simple chunk management - just add/remove voxel volumes
pub extern fn addVolume(renderer: *Renderer, volume: *vol.Volume, position: [3]i32) void;
pub extern fn removeVolume(renderer: *Renderer, position: [3]i32) void;
pub extern fn clearVolumes(renderer: *Renderer) void;

pub extern fn render(renderer: *Renderer) void;
