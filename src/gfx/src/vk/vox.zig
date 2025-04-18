const std = @import("std");
const math = @import("math");
const Palette = @import("palette.zig").Palette;

// Reuse existing vector types
const Vec3 = math.vec.Vec3;
const IVec3 = math.vec.IVec3;
const UVec3 = math.vec.UVec3;
const Quat = math.quat.Quat;

// VoxelGrid struct
pub const VoxelGrid = struct {
    data: *Palette,
    origin: IVec3,
    size: UVec3,
    position: Vec3,
    rotation: Quat,
    dirty: bool,

    pub fn init(allocator: *std.mem.Allocator, data: *Palette, size: UVec3) !*VoxelGrid {
        const grid = try allocator.create(VoxelGrid);
        grid.* = .{
            .data = data,
            .size = size,
            .origin = math.vec.iv3Splat(0),
            .position = math.vec.v3Splat(0),
            .rotation = math.quat.qId(),
            .dirty = true,
        };
        return grid;
    }

    pub fn deinit(self: *VoxelGrid, allocator: *std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn setPos(self: *VoxelGrid, pos: Vec3) void {
        self.position = pos;
        self.markDirty();
    }

    pub fn setRot(self: *VoxelGrid, rot: Quat) void {
        self.rotation = rot;
        self.markDirty();
    }

    pub fn markDirty(self: *VoxelGrid) void {
        self.dirty = true;
    }

    pub fn isDirty(self: *const VoxelGrid) bool {
        return self.dirty;
    }

    pub fn clearDirty(self: *VoxelGrid) void {
        self.dirty = false;
    }

    pub fn getSize(self: *const VoxelGrid) UVec3 {
        return self.size;
    }

    pub fn getData(self: *const VoxelGrid) *Palette {
        return self.data;
    }
};
