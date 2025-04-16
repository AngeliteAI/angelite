const std = @import("std");
const math = @import("math");
const vox = @import("vox.zig");
const Palette = @import("palette.zig").Palette;

// Vector types from math module
const Vec3 = math.vec.Vec3;
const IVec3 = math.vec.IVec3;
const UVec3 = math.vec.UVec3;
const Quat = math.quat.Quat;

// Import the types from trans.zig and brush.zig directly
const trans = @import("trans.zig");
const brush = @import("brush.zig");
const Transform = trans.Transform;
const Brush = brush.Brush;

// Volume struct matching the include definition
pub const Volume = extern struct {
    id: u64,
};

// Internal struct for tracking volume data
const VolumeData = struct {
    grid: *vox.VoxelGrid,
};

// Global volume map
var gpa = std.heap.GeneralPurposeAllocator(.{}){};  // For memory allocations
var volumes = std.AutoHashMap(u64, *VolumeData).init(gpa.allocator());

// Helper to generate a random ID
fn generateId() u64 {
    var rand = std.Random.DefaultPrng.init(@bitCast(std.time.milliTimestamp()));
    return rand.random().int(u64);
}

// Internal function to get volume data
fn getVolumeData(vol: *Volume) ?*VolumeData {
    return volumes.get(vol.id);
}

// Implementation of C-ABI functions

export fn createEmptyVolume(size_x: u32, size_y: u32, size_z: u32) *Volume {
    const allocator = gpa.allocator();
    
    // Create a palette with single value 0
    const palette = allocator.create(Palette) catch {
        std.debug.print("Failed to allocate palette\n", .{});
        return undefined; // Should handle errors better in production
    };
    palette.* = Palette.initSingle(allocator, 0, @as(usize, size_x * size_y * size_z)) catch {
        std.debug.print("Failed to initialize palette\n", .{});
        allocator.destroy(palette);
        return undefined;
    };
    
    // Create the voxel grid
    const size = UVec3{ .x = size_x, .y = size_y, .z = size_z };
    const grid = vox.VoxelGrid.init(allocator, palette, size) catch {
        std.debug.print("Failed to create voxel grid\n", .{});
        palette.deinit();
        allocator.destroy(palette);
        return undefined;
    };
    
    // Create the volume data
    const volume_data = allocator.create(VolumeData) catch {
        std.debug.print("Failed to allocate volume data\n", .{});
        grid.deinit(allocator);
        palette.deinit();
        allocator.destroy(palette);
        return undefined;
    };
    volume_data.* = .{
        .grid = grid,
    };
    
    // Create the external volume
    const volume = allocator.create(Volume) catch {
        std.debug.print("Failed to allocate volume\n", .{});
        allocator.destroy(volume_data);
        grid.deinit(allocator);
        palette.deinit();
        allocator.destroy(palette);
        return undefined;
    };
    
    // Generate a random ID
    const volume_id = generateId();
    volume.* = .{
        .id = volume_id,
    };
    
    // Store in volumes map
    volumes.put(volume_id, volume_data) catch {
        std.debug.print("Failed to store volume in map\n", .{});
        allocator.destroy(volume);
        allocator.destroy(volume_data);
        grid.deinit(allocator);
        palette.deinit();
        allocator.destroy(palette);
        return undefined;
    };
    
    std.debug.print("createEmptyVolume (Zig): size = ({}, {}, {}), id = {}\n", .{size_x, size_y, size_z, volume_id});
    return volume;
}

export fn createVolumeFromSDF(sdf: *anyopaque, brush: *Brush, position: [3]i32, size: [3]u32) *Volume {
    std.debug.print("createVolumeFromSDF (Zig stub)\n", .{});
    return @ptrCast(createEmptyVolume(size[0], size[1], size[2])); // Stub implementation
}

export fn cloneVolume(vol: *Volume) *Volume {
    std.debug.print("cloneVolume (Zig stub)\n", .{});
    // Stub implementation - just create an empty volume of size 1,1,1
    return @ptrCast(createEmptyVolume(1, 1, 1));
}

export fn releaseVolume(vol: *Volume) void {
    const allocator = gpa.allocator();
    const id = vol.id;
    
    if (volumes.get(id)) |volume_data| {
        // Remove from map
        _ = volumes.remove(id);
        
        // Clean up resources
        const grid = volume_data.grid;
        const palette = grid.getData();
        
        // Free everything
        grid.deinit(allocator);
        palette.deinit();
        allocator.destroy(palette);
        allocator.destroy(volume_data);
        allocator.destroy(vol);
        
        std.debug.print("releaseVolume (Zig): Released volume with id = {}\n", .{id});
    } else {
        std.debug.print("releaseVolume (Zig): Volume with id = {} not found in map\n", .{id});
        allocator.destroy(vol); // Still free the volume struct
    }
}

export fn unionVolume(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume {
    std.debug.print("unionVolume (Zig stub)\n", .{});
    return vol; // Stub implementation - return the same volume
}

export fn subtractVolume(vol: *Volume, transform: *Transform, position: [3]i32) *Volume {
    std.debug.print("subtractVolume (Zig stub)\n", .{});
    return vol; // Stub implementation
}

export fn replaceVolume(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume {
    std.debug.print("replaceVolume (Zig stub)\n", .{});
    return vol; // Stub implementation
}

export fn paintVolumeRegion(vol: *Volume, transform: *Transform, brush: *Brush, position: [3]i32) *Volume {
    std.debug.print("paintVolumeRegion (Zig stub)\n", .{});
    return vol; // Stub implementation
}

export fn mergeVolumes(volumes_slice: []const *Volume) *Volume {
    std.debug.print("mergeVolumes (Zig stub)\n", .{});
    // Stub implementation - just create an empty volume
    return @ptrCast(createEmptyVolume(1, 1, 1));
}

export fn extractRegion(vol: *Volume, min_x: i32, min_y: i32, min_z: i32, max_x: i32, max_y: i32, max_z: i32) *Volume {
    std.debug.print("extractRegion (Zig stub)\n", .{});
    // Stub - create a new volume with the size of the region
    const size_x = @as(u32, @intCast(@max(0, max_x - min_x)));
    const size_y = @as(u32, @intCast(@max(0, max_y - min_y)));
    const size_z = @as(u32, @intCast(@max(0, max_z - min_z)));
    return @ptrCast(createEmptyVolume(size_x, size_y, size_z));
}

export fn registerStructure(vol: *Volume, name: []const u8) u32 {
    std.debug.print("registerStructure (Zig stub)\n", .{});
    return 0; // Stub implementation
}

export fn getStructure(id: u32) ?*Volume {
    std.debug.print("getStructure (Zig stub)\n", .{});
    return null; // Stub implementation
}

export fn placeStructure(world: *Volume, structure: *Volume, position: [3]i32, rotation: u8) *Volume {
    std.debug.print("placeStructure (Zig stub)\n", .{});
    return world; // Stub implementation
}

export fn saveVolume(vol: *Volume, path: []const u8) bool {
    std.debug.print("saveVolume (Zig stub)\n", .{});
    return false; // Stub implementation
}

export fn loadVolume(path: []const u8) ?*Volume {
    std.debug.print("loadVolume (Zig stub)\n", .{});
    return null; // Stub implementation
}

export fn getVoxel(vol: *Volume, positions: *const Vec3, out_blocks: *u16, count: usize) void {
    std.debug.print("getVoxel (Zig stub)\n", .{});
    if (getVolumeData(vol)) |volume_data| {
        const grid = volume_data.grid;
        const size = grid.getSize();
        
        // Zero out the output buffer
        @memset(out_blocks[0..count], 0);
    } else {
        // If volume not found, zero out buffer
        @memset(out_blocks[0..count], 0);
    }
}

export fn setVoxel(vol: *Volume, positions: *const Vec3, blocks: *const u16, count: usize) void {
    std.debug.print("setVoxel (Zig stub)\n", .{});
    // Stub implementation - does nothing
}

export fn getVolumeSize(vol: *Volume) [3]u32 {
    var result = [3]u32{ 0, 0, 0 };
    
    if (getVolumeData(vol)) |volume_data| {
        const size = volume_data.grid.getSize();
        result[0] = size.x;
        result[1] = size.y;
        result[2] = size.z;
    }
    
    return result;
}

export fn getVolumePosition(vol: *Volume) [3]i32 {
    var result = [3]i32{ 0, 0, 0 };
    
    if (getVolumeData(vol)) |volume_data| {
        const origin = volume_data.grid.origin;
        result[0] = origin.x;
        result[1] = origin.y;
        result[2] = origin.z;
    }
    
    return result;
}

export fn moveVolume(vol: *Volume, x: i32, y: i32, z: i32) *Volume {
    std.debug.print("moveVolume (Zig stub)\n", .{});
    return vol; // Stub implementation
}

export fn rotateVolume(vol: *Volume, rotation: u8) *Volume {
    std.debug.print("rotateVolume (Zig stub)\n", .{});
    return vol; // Stub implementation
}

export fn mirrorVolume(vol: *Volume, axis: u8) *Volume {
    std.debug.print("mirrorVolume (Zig stub)\n", .{});
    return vol; // Stub implementation
}