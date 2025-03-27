const trans = @import("trans.zig");
const brush = @import("brush.zig");
const vec = @import("vec.zig");

const Vec3 = vec.Vec3;

const Brush = brush.Brush;
const Transform = trans.Transform;

pub const Volume = extern struct {
    id: u64,
};

// *Volume creation and management
pub extern fn createEmptyVolume(size_x: u32, size_y: u32, size_z: u32) *Volume;
pub extern fn createVolumeFromSDF(sdf: *anyopaque, brush: *Brush, position: [3]i32, size: [3]u32) *Volume;
pub extern fn cloneVolume(vol: *Volume) *Volume;
pub extern fn releaseVolume(vol: *Volume) void;

// *Volume modification operations - one per operation type
pub extern fn unionVolume(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume;
pub extern fn subtractVolume(vol: *Volume, transform: *Transform, position: [3]i32) *Volume;
pub extern fn replaceVolume(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume;
pub extern fn paintVolumeRegion(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume;

// *Volume compositing
pub extern fn mergeVolumes(volumes: []const *Volume) *Volume;
pub extern fn extractRegion(vol: *Volume, min_x: i32, min_y: i32, min_z: i32, max_x: i32, max_y: i32, max_z: i32) *Volume;

// Structure management
pub extern fn registerStructure(vol: *Volume, name: []const u8) u32;
pub extern fn getStructure(id: u32) ?*Volume;
pub extern fn placeStructure(world: *Volume, structure: *Volume, position: [3]i32, rotation: u8) *Volume;

// Serialization
pub extern fn saveVolume(vol: *Volume, path: []const u8) bool;
pub extern fn loadVolume(path: []const u8) ?*Volume;

// Direct access
pub extern fn getVoxel(vol: *Volume, positions: *const Vec3, out_blocks: *u16, count: usize) void;
pub extern fn setVoxel(vol: *Volume, positions: *const Vec3, blocks: *const u16, count: usize) void;
pub extern fn getVolumeSize(vol: *Volume) [3]u32;
pub extern fn getVolumePosition(vol: *Volume) [3]i32;

// *Volume transformations
pub extern fn moveVolume(vol: *Volume, x: i32, y: i32, z: i32) *Volume;
pub extern fn rotateVolume(vol: *Volume, rotation: u8) *Volume;
pub extern fn mirrorVolume(vol: *Volume, axis: u8) *Volume;
