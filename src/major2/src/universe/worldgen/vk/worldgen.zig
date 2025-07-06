const std = @import("std");
const vk = @import("vulkan");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});
const gfx = @import("../../../gfx/vk/gfx.zig");
const Renderer = gfx.Renderer;
const PipelineManager = @import("../../../gfx/vk/PipelineManager.zig");
const tracy = @import("../../../tracy.zig");
const tracy_macros = @import("../../../tracy_macros.zig");

// Push constants structure matching shader layout
const PushConstants = struct {
    sdf_tree_address: u64,
    params_address: u64,
    output_field_address: u64,
    world_params_address: u64,
    output_voxels_address: u64,
    brush_program_address: u64 = 0,
    brush_layers_address: u64 = 0,
    workgroup_offset: u32 = 0,  // Starting workgroup index for this dispatch
    total_workgroups: u32 = 0,  // Total workgroups in the full volume
};

// Worldgen GPU implementation that uses the main renderer
pub const GpuWorldgen = struct {
    renderer: *Renderer,
    allocator: std.mem.Allocator,
    pipeline_manager: *PipelineManager.PipelineManager,

    // Device address pipelines
    sdf_pipeline: PipelineManager.DeviceAddressPipeline,
    brush_pipeline: PipelineManager.DeviceAddressPipeline,
    compression_pipeline: PipelineManager.DeviceAddressPipeline,
    
    // Default buffers to satisfy shader bindings
    default_buffer: vk.Buffer,
    default_memory: vk.DeviceMemory,
    default_sampler: vk.Sampler,
    default_image: vk.Image,
    default_image_view: vk.ImageView,
    default_image_memory: vk.DeviceMemory,

    pub fn init(renderer_ptr: *Renderer, allocator: std.mem.Allocator) !GpuWorldgen {
        var _tracy = tracy.zone("GpuWorldgen.init");
        defer _tracy.deinit();
        
        std.debug.print("Initializing GpuWorldgen\n", .{});
        tracy.setAppInfo("Angelite Engine");
        
        // Create pipeline manager
        const pipeline_manager = try allocator.create(PipelineManager.PipelineManager);
        pipeline_manager.* = try PipelineManager.PipelineManager.init(
            allocator,
            renderer_ptr.device.device,
            renderer_ptr.device.dispatch
        );
        
        // Push constant size for all pipelines (7 u64 addresses + 2 u32 values = 64 bytes)
        const push_constant_size = @sizeOf(PushConstants);
        
        // Load shader SPIRVs
        const sdf_code align(4) = @embedFile("sdf_evaluation.comp.spirv").*;
        const brush_code align(4) = @embedFile("brush_evaluation.comp.spirv").*;
        const compression_code align(4) = @embedFile("bitpack_compression.comp.spirv").*;
        
        // Create pipelines with device address support
        std.debug.print("Creating SDF pipeline...\n", .{});
        const sdf_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            pipeline_manager,
            std.mem.bytesAsSlice(u32, &sdf_code),
            push_constant_size
        );
        std.debug.print("SDF pipeline created: {}\n", .{sdf_pipeline.pipeline});
        
        std.debug.print("Creating Brush pipeline...\n", .{});
        const brush_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            pipeline_manager,
            std.mem.bytesAsSlice(u32, &brush_code),
            push_constant_size
        );
        std.debug.print("Brush pipeline created: {}\n", .{brush_pipeline.pipeline});
        
        std.debug.print("Creating Compression pipeline...\n", .{});
        const compression_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            pipeline_manager,
            std.mem.bytesAsSlice(u32, &compression_code),
            push_constant_size
        );
        std.debug.print("Compression pipeline created: {}\n", .{compression_pipeline.pipeline});
        
        // Create default resources
        const device = renderer_ptr.device.device;
        const dispatch = &renderer_ptr.device.dispatch;
        
        // Create default buffer
        const buffer_info = vk.BufferCreateInfo{
            .size = 256, // Small default size
            .usage = .{ .storage_buffer_bit = true, .uniform_buffer_bit = true, .shader_device_address_bit = true },
            .sharing_mode = .exclusive,
        };
        
        var default_buffer: vk.Buffer = undefined;
        _ = dispatch.vkCreateBuffer.?(device, &buffer_info, null, &default_buffer);
        
        // Allocate memory for buffer
        var mem_reqs: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, default_buffer, &mem_reqs);
        
        const alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        
        const alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = &alloc_flags_info,
            .allocation_size = mem_reqs.size,
            .memory_type_index = 0, // Should find appropriate type
        };
        
        var default_memory: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &alloc_info, null, &default_memory);
        _ = dispatch.vkBindBufferMemory.?(device, default_buffer, default_memory, 0);
        
        // Create default sampler
        const sampler_info = vk.SamplerCreateInfo{
            .mag_filter = .linear,
            .min_filter = .linear,
            .mipmap_mode = .linear,
            .address_mode_u = .repeat,
            .address_mode_v = .repeat,
            .address_mode_w = .repeat,
            .mip_lod_bias = 0,
            .anisotropy_enable = vk.FALSE,
            .max_anisotropy = 1,
            .compare_enable = vk.FALSE,
            .compare_op = .always,
            .min_lod = 0,
            .max_lod = 0,
            .border_color = .int_opaque_black,
            .unnormalized_coordinates = vk.FALSE,
        };
        
        var default_sampler: vk.Sampler = undefined;
        _ = dispatch.vkCreateSampler.?(device, &sampler_info, null, &default_sampler);
        
        // Create 1x1 default image
        const image_info = vk.ImageCreateInfo{
            .image_type = .@"2d",
            .format = .r8g8b8a8_unorm,
            .extent = .{ .width = 1, .height = 1, .depth = 1 },
            .mip_levels = 1,
            .array_layers = 1,
            .samples = .{ .@"1_bit" = true },
            .tiling = .optimal,
            .usage = .{ .sampled_bit = true },
            .sharing_mode = .exclusive,
            .initial_layout = .undefined,
        };
        
        var default_image: vk.Image = undefined;
        _ = dispatch.vkCreateImage.?(device, &image_info, null, &default_image);
        
        // Allocate memory for image
        var img_mem_reqs: vk.MemoryRequirements = undefined;
        dispatch.vkGetImageMemoryRequirements.?(device, default_image, &img_mem_reqs);
        
        const img_alloc_info = vk.MemoryAllocateInfo{
            .allocation_size = img_mem_reqs.size,
            .memory_type_index = 0, // Should find appropriate type
        };
        
        var default_image_memory: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &img_alloc_info, null, &default_image_memory);
        _ = dispatch.vkBindImageMemory.?(device, default_image, default_image_memory, 0);
        
        // Create image view
        const view_info = vk.ImageViewCreateInfo{
            .image = default_image,
            .view_type = .@"2d",
            .format = .r8g8b8a8_unorm,
            .components = .{ .r = .identity, .g = .identity, .b = .identity, .a = .identity },
            .subresource_range = .{
                .aspect_mask = .{ .color_bit = true },
                .base_mip_level = 0,
                .level_count = 1,
                .base_array_layer = 0,
                .layer_count = 1,
            },
        };
        
        var default_image_view: vk.ImageView = undefined;
        _ = dispatch.vkCreateImageView.?(device, &view_info, null, &default_image_view);
        
        std.debug.print("GpuWorldgen initialized successfully\n", .{});
        return .{
            .renderer = renderer_ptr,
            .allocator = allocator,
            .pipeline_manager = pipeline_manager,
            .sdf_pipeline = sdf_pipeline,
            .brush_pipeline = brush_pipeline,
            .compression_pipeline = compression_pipeline,
            .default_buffer = default_buffer,
            .default_memory = default_memory,
            .default_sampler = default_sampler,
            .default_image = default_image,
            .default_image_view = default_image_view,
            .default_image_memory = default_image_memory,
        };
    }

    pub fn deinit(self: *GpuWorldgen) void {
        const device = self.renderer.device.device;
        const dispatch = &self.renderer.device.dispatch;
        
        // Clean up default resources
        dispatch.vkDestroyImageView.?(device, self.default_image_view, null);
        dispatch.vkDestroyImage.?(device, self.default_image, null);
        dispatch.vkFreeMemory.?(device, self.default_image_memory, null);
        dispatch.vkDestroySampler.?(device, self.default_sampler, null);
        dispatch.vkDestroyBuffer.?(device, self.default_buffer, null);
        dispatch.vkFreeMemory.?(device, self.default_memory, null);
        
        // Clean up pipelines
        self.sdf_pipeline.deinit();
        self.brush_pipeline.deinit();
        self.compression_pipeline.deinit();
        self.pipeline_manager.deinit();
        self.allocator.destroy(self.pipeline_manager);
    }

    // Create buffers with device address support
    pub fn createDeviceAddressBuffer(self: *GpuWorldgen, size: u64) !vk.Buffer {
        const device = self.renderer.device.device;
        const dispatch = &self.renderer.device.dispatch;
        
        const buffer_info = vk.BufferCreateInfo{
            .size = size,
            .usage = .{ 
                .storage_buffer_bit = true,
                .shader_device_address_bit = true,
            },
            .sharing_mode = .exclusive,
        };
        
        var buffer: vk.Buffer = undefined;
        _ = dispatch.vkCreateBuffer.?(device, &buffer_info, null, &buffer);
        
        // Allocate memory with device address flag
        var mem_reqs: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, buffer, &mem_reqs);
        
        const alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        
        const alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = &alloc_flags_info,
            .allocation_size = mem_reqs.size,
            .memory_type_index = 0, // Should find appropriate memory type
        };
        
        var memory: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &alloc_info, null, &memory);
        _ = dispatch.vkBindBufferMemory.?(device, buffer, memory, 0);
        
        return buffer;
    }

    pub fn generateWorldAdaptive(
        self: *GpuWorldgen,
        cmd: vk.CommandBuffer,
        bounds: WorldBounds,
        sdf_tree_buffer: vk.Buffer,
        params_buffer: vk.Buffer,
        output_buffer: vk.Buffer,
        world_params_buffer: vk.Buffer,
        output_voxels_buffer: vk.Buffer,
        brush_buffer: ?vk.Buffer,  // Optional brush buffer
        start_offset: u32,
        max_workgroups: u32,  // Dynamically adjusted based on frame time
    ) !u32 {  // Returns number of workgroups processed
        std.debug.print("generateWorldAdaptive called - offset: {}, max_workgroups: {}\n", .{start_offset, max_workgroups});
        const dispatch = &self.renderer.device.dispatch;

        // Calculate total workgroups needed for 8x8x8 mini-chunks
        const group_size = 8;
        const groups_x = (bounds.resolution[0] + group_size - 1) / group_size;
        const groups_y = (bounds.resolution[1] + group_size - 1) / group_size;
        const groups_z = (bounds.resolution[2] + group_size - 1) / group_size;
        const total_groups = groups_x * groups_y * groups_z;
        
        // Always run SDF evaluation for the entire bounds
        {
            // Get buffer device addresses
            const sdf_tree_addr = self.pipeline_manager.*.getBufferDeviceAddress(sdf_tree_buffer);
            const params_addr = self.pipeline_manager.*.getBufferDeviceAddress(params_buffer);
            const output_addr = self.pipeline_manager.*.getBufferDeviceAddress(output_buffer);
            const world_params_addr = self.pipeline_manager.*.getBufferDeviceAddress(world_params_buffer);
            const output_voxels_addr = self.pipeline_manager.*.getBufferDeviceAddress(output_voxels_buffer);
            
            // Set up push constants for SDF evaluation
            const sdf_push = PushConstants{
                .sdf_tree_address = sdf_tree_addr,
                .params_address = params_addr,
                .output_field_address = output_addr,
                .world_params_address = world_params_addr,
                .output_voxels_address = output_voxels_addr,
                .workgroup_offset = 0,
                .total_workgroups = total_groups,
            };
            
            // Bind and dispatch SDF evaluation pipeline
            std.debug.print("Running SDF evaluation for entire bounds\n", .{});
            std.debug.print("About to bind SDF pipeline: {}\n", .{self.sdf_pipeline.pipeline});
            
            // Begin Tracy GPU zone for SDF evaluation
            var sdf_gpu_zone: ?tracy_macros.VkZone = if (self.renderer.tracy_vk_ctx) |ctx| 
                tracy_macros.VkZone.init(ctx, @ptrFromInt(@intFromEnum(cmd)), "SDF Evaluation")
            else null;
            defer if (sdf_gpu_zone) |*z| z.deinit();
            
            self.sdf_pipeline.bind(cmd);
            self.sdf_pipeline.pushConstants(cmd, &sdf_push, @sizeOf(PushConstants));
            
            // SDF evaluation runs on the full grid with 8x8x8 workgroups
            // Using groups_x/y/z already calculated above
            
            std.debug.print("SDF dispatch: {}x{}x{} workgroups for {}x{}x{} voxels\n", 
                .{groups_x, groups_y, groups_z, bounds.resolution[0], bounds.resolution[1], bounds.resolution[2]});
            
            self.sdf_pipeline.dispatch(cmd, groups_x, groups_y, groups_z);
            
            // Memory barrier before brush evaluation
            const barrier = vk.MemoryBarrier{
                .src_access_mask = .{ .shader_write_bit = true },
                .dst_access_mask = .{ .shader_read_bit = true },
            };
            dispatch.vkCmdPipelineBarrier.?(
                cmd,
                .{ .compute_shader_bit = true },
                .{ .compute_shader_bit = true },
                .{},
                1,
                @as([*]const vk.MemoryBarrier, @ptrCast(&barrier)),
                0,
                null,
                0,
                null,
            );
        }

        // Now handle brush evaluation in chunks
        // Get buffer addresses (reuse from SDF if needed)
        const sdf_tree_addr = self.pipeline_manager.*.getBufferDeviceAddress(sdf_tree_buffer);
        const params_addr = self.pipeline_manager.*.getBufferDeviceAddress(params_buffer);
        const output_addr = self.pipeline_manager.*.getBufferDeviceAddress(output_buffer);
        const world_params_addr = self.pipeline_manager.*.getBufferDeviceAddress(world_params_buffer);
        const output_voxels_addr = self.pipeline_manager.*.getBufferDeviceAddress(output_voxels_buffer);
        
        // Get brush buffer address - use actual buffer if provided, otherwise default
        const brush_layers_addr = if (brush_buffer) |buf| blk: {
            const addr = self.pipeline_manager.*.getBufferDeviceAddress(buf);
            std.debug.print("Using actual brush buffer with address: 0x{x}\n", .{addr});
            break :blk addr;
        } else blk: {
            const addr = self.pipeline_manager.*.getBufferDeviceAddress(self.default_buffer);
            std.debug.print("Warning: No brush buffer provided, using default buffer with address: 0x{x}\n", .{addr});
            break :blk addr;
        };
        
        // Set up push constants for brush evaluation
        const brush_push = PushConstants{
            .sdf_tree_address = sdf_tree_addr,
            .params_address = params_addr,
            .output_field_address = output_addr,  // SDF field as input
            .world_params_address = world_params_addr,
            .output_voxels_address = output_voxels_addr,
            .brush_program_address = brush_layers_addr,  // Use brush buffer address
            .brush_layers_address = brush_layers_addr,   // Use brush buffer address
            .workgroup_offset = start_offset,
            .total_workgroups = total_groups,
        };
        
        // Dispatch brush evaluation for this chunk only
        
        // Calculate the actual dispatch size for this chunk
        const remaining_groups = if (start_offset < total_groups) total_groups - start_offset else 0;
        const chunk_groups = @min(max_workgroups, remaining_groups);
        
        if (chunk_groups > 0) {
            // Update push constants with chunk offset
            var chunk_push = brush_push;
            chunk_push.workgroup_offset = start_offset;
            chunk_push.total_workgroups = total_groups;
            
            std.debug.print("Dispatching brush chunk: offset={}, size={} (of {} total)\n", 
                .{start_offset, chunk_groups, total_groups});
            
            // Begin Tracy GPU zone for brush evaluation
            var brush_gpu_zone: ?tracy_macros.VkZone = if (self.renderer.tracy_vk_ctx) |ctx| 
                tracy_macros.VkZone.init(ctx, @ptrFromInt(@intFromEnum(cmd)), "Brush Evaluation")
            else null;
            defer if (brush_gpu_zone) |*z| z.deinit();
            
            self.brush_pipeline.bind(cmd);
            self.brush_pipeline.pushConstants(cmd, &chunk_push, @sizeOf(PushConstants));
            
            // For chunked processing, we dispatch linearly and let the shader convert to 3D
            // This allows us to process a subset of the total workgroups
            self.brush_pipeline.dispatch(cmd, chunk_groups, 1, 1);
        }
        
        // Final barrier for transfer operations
        const transfer_barrier = vk.MemoryBarrier{
            .src_access_mask = .{ .shader_write_bit = true },
            .dst_access_mask = .{ .transfer_read_bit = true },
        };
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .compute_shader_bit = true },
            .{ .transfer_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&transfer_barrier)),
            0,
            null,
            0,
            null,
        );
        
        return chunk_groups;
    }
};

pub const WorldBounds = struct {
    min: [3]f32,
    max: [3]f32,
    resolution: [3]u32,
    voxel_size: f32,
};

// C API exports
export fn gpu_worldgen_create(renderer_ptr: *Renderer, allocator: *anyopaque) ?*GpuWorldgen {
    _ = allocator;
    const system_allocator = std.heap.page_allocator;
    const worldgen = system_allocator.create(GpuWorldgen) catch return null;
    worldgen.* = GpuWorldgen.init(renderer_ptr, system_allocator) catch {
        system_allocator.destroy(worldgen);
        return null;
    };
    return worldgen;
}

export fn gpu_worldgen_destroy(worldgen: *GpuWorldgen) void {
    const allocator = worldgen.allocator;
    worldgen.deinit();
    allocator.destroy(worldgen);
}

// Legacy function for compatibility - calls adaptive version with full workload
export fn gpu_worldgen_generate(
    worldgen: *GpuWorldgen,
    cmd_ptr: *anyopaque,
    bounds_min_x: f32,
    bounds_min_y: f32,
    bounds_min_z: f32,
    bounds_max_x: f32,
    bounds_max_y: f32,
    bounds_max_z: f32,
    resolution_x: u32,
    resolution_y: u32,
    resolution_z: u32,
    voxel_size: f32,
    sdf_tree_buffer_ptr: *anyopaque,
    params_buffer_ptr: *anyopaque,
    output_buffer_ptr: *anyopaque,
    world_params_buffer_ptr: *anyopaque,
    output_voxels_buffer_ptr: *anyopaque,
) void {
    // Calculate total workgroups needed for 8x8x8 mini-chunks
    const group_size = 8;
    const groups_x = (resolution_x + group_size - 1) / group_size;
    const groups_y = (resolution_y + group_size - 1) / group_size;
    const groups_z = (resolution_z + group_size - 1) / group_size;
    const total_workgroups = groups_x * groups_y * groups_z;
    
    // Limit to avoid GPU timeouts - process 18 8x8x8 minichunks per frame
    const max_dispatch = 18; // Process 18x8x8 minichunks per frame
    const clamped_workgroups = @min(total_workgroups, max_dispatch);
    
    if (total_workgroups > max_dispatch) {
        std.debug.print("Warning: Clamping workgroups from {} to {} due to GPU limits\n", .{total_workgroups, max_dispatch});
    }
    
    // Call adaptive version with limited workload (using null brush buffer)
    _ = gpu_worldgen_generate_adaptive_with_brush(
        worldgen,
        cmd_ptr,
        bounds_min_x,
        bounds_min_y,
        bounds_min_z,
        bounds_max_x,
        bounds_max_y,
        bounds_max_z,
        resolution_x,
        resolution_y,
        resolution_z,
        voxel_size,
        sdf_tree_buffer_ptr,
        params_buffer_ptr,
        output_buffer_ptr,
        world_params_buffer_ptr,
        output_voxels_buffer_ptr,
        null, // No brush buffer for legacy function
        0, // start_offset
        clamped_workgroups, // process limited amount
    );
}

export fn gpu_worldgen_generate_adaptive_with_brush(
    worldgen: *GpuWorldgen,
    cmd_ptr: *anyopaque,
    bounds_min_x: f32,
    bounds_min_y: f32,
    bounds_min_z: f32,
    bounds_max_x: f32,
    bounds_max_y: f32,
    bounds_max_z: f32,
    resolution_x: u32,
    resolution_y: u32,
    resolution_z: u32,
    voxel_size: f32,
    sdf_tree_buffer_ptr: *anyopaque,
    params_buffer_ptr: *anyopaque,
    output_buffer_ptr: *anyopaque,
    world_params_buffer_ptr: *anyopaque,
    output_voxels_buffer_ptr: *anyopaque,
    brush_buffer_ptr: ?*anyopaque,  // Make it optional
    start_offset: u32,
    max_workgroups: u32,
) u32 {
    // Cast the command buffer pointer to ComputeCommandBuffer and extract the vk.CommandBuffer
    const compute_cmd_buffer = @as(*gfx.ComputeCommandBuffer, @ptrCast(@alignCast(cmd_ptr)));
    const cmd = compute_cmd_buffer.command_buffer;
    
    // Cast the opaque pointers to GpuBuffer pointers and extract the vk.Buffer handles
    const sdf_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(sdf_tree_buffer_ptr)));
    const params_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(params_buffer_ptr)));
    const output_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(output_buffer_ptr)));
    const world_params_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(world_params_buffer_ptr)));
    const output_voxels_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(output_voxels_buffer_ptr)));
    
    const sdf_tree_buffer = sdf_gpu_buffer.buffer;
    const params_buffer = params_gpu_buffer.buffer;
    const output_buffer = output_gpu_buffer.buffer;
    const world_params_buffer = world_params_gpu_buffer.buffer;
    const output_voxels_buffer = output_voxels_gpu_buffer.buffer;
    
    // Extract brush buffer if provided
    const brush_buffer = if (brush_buffer_ptr) |ptr| blk: {
        const brush_gpu_buffer = @as(*gfx.GpuBuffer, @ptrCast(@alignCast(ptr)));
        break :blk brush_gpu_buffer.buffer;
    } else null;
    const bounds = WorldBounds{
        .min = [3]f32{ bounds_min_x, bounds_min_y, bounds_min_z },
        .max = [3]f32{ bounds_max_x, bounds_max_y, bounds_max_z },
        .resolution = [3]u32{ resolution_x, resolution_y, resolution_z },
        .voxel_size = voxel_size,
    };

    std.debug.print("GPU worldgen generate called with bounds: [{:.1},{:.1},{:.1}] to [{:.1},{:.1},{:.1}]\n", .{
        bounds.min[0], bounds.min[1], bounds.min[2],
        bounds.max[0], bounds.max[1], bounds.max[2],
    });
    
    std.debug.print("Buffer handles - SDF: {}, Params: {}, Output: {}\n", .{
        sdf_tree_buffer, params_buffer, output_buffer
    });
    
    const processed = worldgen.generateWorldAdaptive(
        cmd,
        bounds,
        sdf_tree_buffer,
        params_buffer,
        output_buffer,
        world_params_buffer,
        output_voxels_buffer,
        brush_buffer,
        start_offset,
        max_workgroups,
    ) catch |err| {
        // Handle error
        std.log.err("Failed to generate world: {}", .{err});
        return 0;
    };
    
    return processed;
}

export fn gpu_worldgen_generate_adaptive(
    worldgen: *GpuWorldgen,
    cmd_ptr: *anyopaque,
    bounds_min_x: f32,
    bounds_min_y: f32,
    bounds_min_z: f32,
    bounds_max_x: f32,
    bounds_max_y: f32,
    bounds_max_z: f32,
    resolution_x: u32,
    resolution_y: u32,
    resolution_z: u32,
    voxel_size: f32,
    sdf_tree_buffer_ptr: *anyopaque,
    params_buffer_ptr: *anyopaque,
    output_buffer_ptr: *anyopaque,
    world_params_buffer_ptr: *anyopaque,
    output_voxels_buffer_ptr: *anyopaque,
    start_offset: u32,
    max_workgroups: u32,
) u32 {
    // Call the new version with null brush buffer
    return gpu_worldgen_generate_adaptive_with_brush(
        worldgen,
        cmd_ptr,
        bounds_min_x, bounds_min_y, bounds_min_z,
        bounds_max_x, bounds_max_y, bounds_max_z,
        resolution_x, resolution_y, resolution_z,
        voxel_size,
        sdf_tree_buffer_ptr,
        params_buffer_ptr,
        output_buffer_ptr,
        world_params_buffer_ptr,
        output_voxels_buffer_ptr,
        null, // No brush buffer
        start_offset,
        max_workgroups,
    );
}

// Helper to get buffer device address
export fn gpu_worldgen_get_buffer_device_address(
    worldgen: *GpuWorldgen,
    buffer: vk.Buffer,
) u64 {
    return worldgen.pipeline_manager.*.getBufferDeviceAddress(buffer);
}

// Create a buffer with device address support
export fn gpu_worldgen_create_device_buffer(
    worldgen: *GpuWorldgen,
    size: u64,
) vk.Buffer {
    return worldgen.createDeviceAddressBuffer(size) catch {
        std.log.err("Failed to create device buffer", .{});
        return .null_handle;
    };
}
