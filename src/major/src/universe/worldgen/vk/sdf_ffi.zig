const std = @import("std");
const worldgen = @import("worldgen.zig");
const c = @cImport({
    @cInclude("stdint.h");
    @cInclude("stdbool.h");
});

// FFI structures matching Rust types
const Vec3 = extern struct {
    data: [3]f32,
};

const WorldBounds = extern struct {
    min: Vec3,
    max: Vec3,
    voxel_size: f32,
};

const GenerationParams = extern struct {
    sdf_resolution: [3]u32,
    brush_schema: *anyopaque, // Opaque pointer to BrushSchema
    post_processes: *anyopaque,
    lod_levels: *anyopaque,
};

const VoxelWorkspace = extern struct {
    bounds: WorldBounds,
    voxels: [*]u32, // Voxel array
    dimensions: [3]u32,
    metadata: *anyopaque, // Opaque pointer to metadata
};

const SdfPlaneGenerator = extern struct {
    plane_sdf: *anyopaque, // Opaque pointer to Plane SDF
    brush_schema: *anyopaque, // Opaque pointer to BrushSchema
};

// GPU compute state
const GpuSdfWorldgen = struct {
    gpu_worldgen: *worldgen.GpuWorldgen,
    allocator: std.mem.Allocator,
    
    // Cached GPU buffers
    sdf_buffer: ?*anyopaque,
    brush_buffer: ?*anyopaque,
    output_buffer: ?*anyopaque,
};

var global_gpu_state: ?*GpuSdfWorldgen = null;

// Initialize GPU worldgen system
export fn worldgen_init_gpu(device: *anyopaque) bool {
    const allocator = std.heap.c_allocator;
    
    const state = allocator.create(GpuSdfWorldgen) catch return false;
    state.* = .{
        .gpu_worldgen = worldgen.GpuWorldgen.init(@ptrCast(device), allocator) catch {
            allocator.destroy(state);
            return false;
        },
        .allocator = allocator,
        .sdf_buffer = null,
        .brush_buffer = null,
        .output_buffer = null,
    };
    
    global_gpu_state = state;
    return true;
}

// Cleanup GPU worldgen system
export fn worldgen_cleanup_gpu() void {
    if (global_gpu_state) |state| {
        state.gpu_worldgen.deinit();
        state.allocator.destroy(state);
        global_gpu_state = null;
    }
}

// Generate SDF plane using GPU compute
export fn worldgen_generate_sdf_plane(
    generator: *const SdfPlaneGenerator,
    bounds: *const WorldBounds,
    params: *const GenerationParams,
) ?*VoxelWorkspace {
    const state = global_gpu_state orelse return null;
    const allocator = state.allocator;
    
    // Calculate dimensions
    const size = Vec3{
        .data = .{
            bounds.max.data[0] - bounds.min.data[0],
            bounds.max.data[1] - bounds.min.data[1],
            bounds.max.data[2] - bounds.min.data[2],
        },
    };
    
    const dimensions = [3]u32{
        @intFromFloat(@ceil(size.data[0] / bounds.voxel_size)),
        @intFromFloat(@ceil(size.data[1] / bounds.voxel_size)),
        @intFromFloat(@ceil(size.data[2] / bounds.voxel_size)),
    };
    
    const voxel_count = dimensions[0] * dimensions[1] * dimensions[2];
    
    // Allocate workspace
    const workspace = allocator.create(VoxelWorkspace) catch return null;
    const voxels = allocator.alloc(u32, voxel_count) catch {
        allocator.destroy(workspace);
        return null;
    };
    
    // Prepare GPU parameters
    const gpu_bounds = worldgen.WorldBounds{
        .min = .{ bounds.min.data[0], bounds.min.data[1], bounds.min.data[2] },
        .max = .{ bounds.max.data[0], bounds.max.data[1], bounds.max.data[2] },
        .resolution = dimensions,
        .voxel_size = bounds.voxel_size,
    };
    
    // Execute GPU compute pipeline
    if (!executeGpuPipeline(state, generator, gpu_bounds, voxels.ptr, voxel_count)) {
        allocator.free(voxels);
        allocator.destroy(workspace);
        return null;
    }
    
    // Fill workspace
    workspace.* = .{
        .bounds = bounds.*,
        .voxels = voxels.ptr,
        .dimensions = dimensions,
        .metadata = null, // Metadata will be computed on Rust side
    };
    
    return workspace;
}

// Free workspace allocated by FFI
export fn worldgen_free_workspace(workspace: *VoxelWorkspace) void {
    const allocator = std.heap.c_allocator;
    if (workspace.voxels != null) {
        const voxel_count = workspace.dimensions[0] * workspace.dimensions[1] * workspace.dimensions[2];
        const voxels = workspace.voxels[0..voxel_count];
        allocator.free(voxels);
    }
    allocator.destroy(workspace);
}

// Execute the GPU compute pipeline
fn executeGpuPipeline(
    state: *GpuSdfWorldgen,
    generator: *const SdfPlaneGenerator,
    bounds: worldgen.WorldBounds,
    output: [*]u32,
    voxel_count: usize,
) bool {
    // This would normally:
    // 1. Upload SDF parameters to GPU
    // 2. Upload brush conditions to GPU
    // 3. Dispatch compute shaders for SDF evaluation
    // 4. Dispatch compute shaders for brush evaluation
    // 5. Apply palette compression
    // 6. Read back results
    
    // For now, generate a simple plane on CPU as fallback
    const dims = bounds.resolution;
    var idx: usize = 0;
    
    var z: u32 = 0;
    while (z < dims[2]) : (z += 1) {
        var y: u32 = 0;
        while (y < dims[1]) : (y += 1) {
            var x: u32 = 0;
            while (x < dims[0]) : (x += 1) {
                const world_y = bounds.min[1] + @as(f32, @floatFromInt(y)) * bounds.voxel_size;
                
                // Simple plane at y=0 using SDF logic
                const distance_to_plane = world_y; // Distance to y=0 plane
                
                // Apply brush conditions based on depth
                const voxel = if (distance_to_plane < -2.0) 
                    1  // Stone (deep below surface)
                else if (distance_to_plane < -0.5)
                    2  // Dirt (near surface)
                else if (distance_to_plane < 0.5)
                    3  // Grass (at surface)
                else
                    0; // Air (above surface)
                
                output[idx] = voxel;
                idx += 1;
            }
        }
    }
    
    return true;
}

// Additional FFI exports for simple plane generator (backward compatibility)
export fn worldgen_create_simple() ?*anyopaque {
    return @ptrCast(&global_gpu_state);
}

export fn worldgen_destroy_simple(worldgen_ptr: *anyopaque) void {
    // No-op, global state is managed separately
    _ = worldgen_ptr;
}

export fn worldgen_generate_plane(
    worldgen_ptr: *anyopaque,
    min_x: f32, min_y: f32, min_z: f32,
    max_x: f32, max_y: f32, max_z: f32,
    voxel_size: f32,
    plane_height: f32,
    output_ptr: [*]u32,
    output_size: usize,
) bool {
    _ = worldgen_ptr;
    _ = plane_height;
    
    const bounds = WorldBounds{
        .min = Vec3{ .data = .{ min_x, min_y, min_z } },
        .max = Vec3{ .data = .{ max_x, max_y, max_z } },
        .voxel_size = voxel_size,
    };
    
    const dims = [3]u32{
        @intFromFloat(@ceil((max_x - min_x) / voxel_size)),
        @intFromFloat(@ceil((max_y - min_y) / voxel_size)),
        @intFromFloat(@ceil((max_z - min_z) / voxel_size)),
    };
    
    const expected_size = dims[0] * dims[1] * dims[2];
    if (output_size != expected_size) return false;
    
    // Generate using simple logic
    var idx: usize = 0;
    var z: u32 = 0;
    while (z < dims[2]) : (z += 1) {
        var y: u32 = 0;
        while (y < dims[1]) : (y += 1) {
            var x: u32 = 0;
            while (x < dims[0]) : (x += 1) {
                const world_y = min_y + @as(f32, @floatFromInt(y)) * voxel_size;
                
                const voxel = if (world_y < -2.0)
                    1  // Stone
                else if (world_y < -0.5)
                    2  // Dirt  
                else if (world_y < 0.5)
                    3  // Grass
                else
                    0; // Air
                
                output_ptr[idx] = voxel;
                idx += 1;
            }
        }
    }
    
    return true;
}