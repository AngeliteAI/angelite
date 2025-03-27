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

pub extern fn init(surface: *Surface) bool;
pub extern fn shutdown() void;
pub extern fn supportsMultiple() bool;

// Camera control
pub extern fn setCamera(camera: *Camera) void;
pub extern fn setSettings(settings: *RenderSettings) void;

// Simple chunk management - just add/remove voxel volumes
pub extern fn addVolume(voxels: &vox.Volume, position: [3]i32) void;
pub extern fn removeVolume(position: [3]i32) void;
pub extern fn clearVolumes() void;

pub extern fn render() void;
