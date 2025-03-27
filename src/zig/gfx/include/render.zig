const math = @import("../../math/root.zig");
const vox = @import("vox.zig");
const surface = @import("surface.zig");

const Surface = surface.Surface;

pub const Camera = extern struct {
    position: math.Vec3,
    rotation: math.Quat,
    projection: math.Mat4,
};

pub const RenderSettings = extern struct {
    view_distance: u32 = 16,
    enable_ao: bool = true,
};

pub const Renderer = extern struct { id: u64 };

pub extern fn init(surface: *Surface) *Renderer;
pub extern fn shutdown(renderer: *Renderer) void;

// Camera control
pub extern fn setCamera(renderer: *Renderer, camera: Camera) void;
pub extern fn setSettings(renderer: *Renderer, settings: RenderSettings) void;

// Simple chunk management - just add/remove voxel volumes
pub extern fn addVolume(renderer: *Renderer, voxels: vox.Volume, position: [3]i32) void;
pub extern fn removeVolume(renderer: *Renderer, position: [3]i32) void;
pub extern fn clearVolumes(renderer: *Renderer) void;

pub extern fn render(renderer: *Renderer) void;
