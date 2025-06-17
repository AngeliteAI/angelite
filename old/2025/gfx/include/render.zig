const math = @import("math");
const vol = @import("vol.zig");
// Import surface from the dependency instead of a local file
const surface = @import("surface").include.surface;

const Surface = surface.Surface;
const Volume = vol.Volume;

pub const Camera = extern struct {
    position: math.vec.Vec3,
    rotation: math.quat.Quat,
    projection: math.mat.Mat4,
};

pub const RenderSettings = extern struct {
    view_distance: u32 = 16,
    enable_ao: bool = true,
};

pub const Renderer = extern struct { id: u64 };

pub extern fn init(surface: *Surface) bool;
pub extern fn shutdown() void;
pub extern fn supportsMultiple() bool;

pub extern fn hotReload(renderer: *Renderer) void;

// Camera control
pub extern fn setCamera(renderer: *Renderer, camera: *Camera) void;
pub extern fn setSettings(renderer: *Renderer, settings: *RenderSettings) void;

// Simple chunk management - just add/remove voxel volumes
pub extern fn addVolume(renderer: *Renderer, volume: *vol.Volume, position: [3]i32) void;
pub extern fn removeVolume(renderer: *Renderer, position: [3]i32) void;
pub extern fn clearVolumes(renderer: *Renderer) void;

pub extern fn render(renderer: *Renderer) void;
