const std = @import("std");
const vk = @import("vulkan");
const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

// Worldgen GPU implementation
pub const GpuWorldgen = struct {
    device: vk.Device,
    allocator: std.mem.Allocator,
    
    // Compute pipelines
    sdf_pipeline: vk.Pipeline,
    brush_pipeline: vk.Pipeline,
    compression_pipeline: vk.Pipeline,
    
    // Descriptor sets
    descriptor_pool: vk.DescriptorPool,
    descriptor_set_layout: vk.DescriptorSetLayout,
    
    // Shaders
    sdf_shader: vk.ShaderModule,
    brush_shader: vk.ShaderModule,
    compression_shader: vk.ShaderModule,
    
    pub fn init(device: vk.Device, allocator: std.mem.Allocator) !GpuWorldgen {
        var self = GpuWorldgen{
            .device = device,
            .allocator = allocator,
            .sdf_pipeline = .null_handle,
            .brush_pipeline = .null_handle,
            .compression_pipeline = .null_handle,
            .descriptor_pool = .null_handle,
            .descriptor_set_layout = .null_handle,
            .sdf_shader = .null_handle,
            .brush_shader = .null_handle,
            .compression_shader = .null_handle,
        };
        
        try self.createShaders();
        try self.createDescriptorSetLayout();
        try self.createPipelines();
        try self.createDescriptorPool();
        
        return self;
    }
    
    pub fn deinit(self: *GpuWorldgen) void {
        self.device.destroyShaderModule(self.sdf_shader, null);
        self.device.destroyShaderModule(self.brush_shader, null);
        self.device.destroyShaderModule(self.compression_shader, null);
        self.device.destroyPipeline(self.sdf_pipeline, null);
        self.device.destroyPipeline(self.brush_pipeline, null);
        self.device.destroyPipeline(self.compression_pipeline, null);
        self.device.destroyDescriptorPool(self.descriptor_pool, null);
        self.device.destroyDescriptorSetLayout(self.descriptor_set_layout, null);
    }
    
    fn createShaders(self: *GpuWorldgen) !void {
        // Load SDF evaluation shader
        const sdf_code = @embedFile("sdf_evaluation.comp.glsl.spv");
        self.sdf_shader = try self.device.createShaderModule(&.{
            .code_size = sdf_code.len,
            .p_code = @ptrCast([*]const u32, @alignCast(4, sdf_code.ptr)),
        }, null);
        
        // Load brush evaluation shader
        const brush_code = @embedFile("brush_evaluation.comp.glsl.spv");
        self.brush_shader = try self.device.createShaderModule(&.{
            .code_size = brush_code.len,
            .p_code = @ptrCast([*]const u32, @alignCast(4, brush_code.ptr)),
        }, null);
        
        // Load compression shader
        const compression_code = @embedFile("palette_counting.comp.glsl.spv");
        self.compression_shader = try self.device.createShaderModule(&.{
            .code_size = compression_code.len,
            .p_code = @ptrCast([*]const u32, @alignCast(4, compression_code.ptr)),
        }, null);
    }
    
    fn createDescriptorSetLayout(self: *GpuWorldgen) !void {
        const bindings = [_]vk.DescriptorSetLayoutBinding{
            // SDF tree buffer
            .{
                .binding = 0,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            // Parameters buffer
            .{
                .binding = 1,
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            // Output buffer
            .{
                .binding = 2,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 1,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
            // Noise textures
            .{
                .binding = 3,
                .descriptor_type = .combined_image_sampler,
                .descriptor_count = 4,
                .stage_flags = .{ .compute_bit = true },
                .p_immutable_samplers = null,
            },
        };
        
        self.descriptor_set_layout = try self.device.createDescriptorSetLayout(&.{
            .binding_count = bindings.len,
            .p_bindings = &bindings,
        }, null);
    }
    
    fn createPipelines(self: *GpuWorldgen) !void {
        const pipeline_layout = try self.device.createPipelineLayout(&.{
            .set_layout_count = 1,
            .p_set_layouts = @ptrCast([*]const vk.DescriptorSetLayout, &self.descriptor_set_layout),
            .push_constant_range_count = 0,
            .p_push_constant_ranges = null,
        }, null);
        defer self.device.destroyPipelineLayout(pipeline_layout, null);
        
        // Create SDF evaluation pipeline
        {
            const stage = vk.PipelineShaderStageCreateInfo{
                .stage = .{ .compute_bit = true },
                .module = self.sdf_shader,
                .p_name = "main",
                .p_specialization_info = null,
            };
            
            const create_info = vk.ComputePipelineCreateInfo{
                .stage = stage,
                .layout = pipeline_layout,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,
            };
            
            _ = try self.device.createComputePipelines(
                .null_handle,
                1,
                @ptrCast([*]const vk.ComputePipelineCreateInfo, &create_info),
                null,
                @ptrCast([*]vk.Pipeline, &self.sdf_pipeline),
            );
        }
        
        // Create brush evaluation pipeline
        {
            const stage = vk.PipelineShaderStageCreateInfo{
                .stage = .{ .compute_bit = true },
                .module = self.brush_shader,
                .p_name = "main",
                .p_specialization_info = null,
            };
            
            const create_info = vk.ComputePipelineCreateInfo{
                .stage = stage,
                .layout = pipeline_layout,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,
            };
            
            _ = try self.device.createComputePipelines(
                .null_handle,
                1,
                @ptrCast([*]const vk.ComputePipelineCreateInfo, &create_info),
                null,
                @ptrCast([*]vk.Pipeline, &self.brush_pipeline),
            );
        }
        
        // Create compression pipeline
        {
            const stage = vk.PipelineShaderStageCreateInfo{
                .stage = .{ .compute_bit = true },
                .module = self.compression_shader,
                .p_name = "main",
                .p_specialization_info = null,
            };
            
            const create_info = vk.ComputePipelineCreateInfo{
                .stage = stage,
                .layout = pipeline_layout,
                .base_pipeline_handle = .null_handle,
                .base_pipeline_index = 0,
            };
            
            _ = try self.device.createComputePipelines(
                .null_handle,
                1,
                @ptrCast([*]const vk.ComputePipelineCreateInfo, &create_info),
                null,
                @ptrCast([*]vk.Pipeline, &self.compression_pipeline),
            );
        }
    }
    
    fn createDescriptorPool(self: *GpuWorldgen) !void {
        const pool_sizes = [_]vk.DescriptorPoolSize{
            .{
                .ty = .storage_buffer,
                .descriptor_count = 100,
            },
            .{
                .ty = .uniform_buffer,
                .descriptor_count = 100,
            },
            .{
                .ty = .combined_image_sampler,
                .descriptor_count = 100,
            },
        };
        
        self.descriptor_pool = try self.device.createDescriptorPool(&.{
            .max_sets = 100,
            .pool_size_count = pool_sizes.len,
            .p_pool_sizes = &pool_sizes,
        }, null);
    }
    
    pub fn generateWorld(
        self: *GpuWorldgen,
        cmd: vk.CommandBuffer,
        bounds: WorldBounds,
        sdf_tree: vk.Buffer,
        output_buffer: vk.Buffer,
        descriptor_set: vk.DescriptorSet,
    ) !void {
        // Bind SDF evaluation pipeline
        cmd.bindPipeline(.compute, self.sdf_pipeline);
        cmd.bindDescriptorSets(
            .compute,
            self.descriptor_set_layout,
            0,
            1,
            @ptrCast([*]const vk.DescriptorSet, &descriptor_set),
            0,
            null,
        );
        
        // Dispatch SDF evaluation
        const group_size = 8;
        const groups_x = (bounds.resolution[0] + group_size - 1) / group_size;
        const groups_y = (bounds.resolution[1] + group_size - 1) / group_size;
        const groups_z = (bounds.resolution[2] + group_size - 1) / group_size;
        
        cmd.dispatch(groups_x, groups_y, groups_z);
        
        // Memory barrier
        const barrier = vk.MemoryBarrier{
            .src_access_mask = .{ .shader_write_bit = true },
            .dst_access_mask = .{ .shader_read_bit = true },
        };
        cmd.pipelineBarrier(
            .{ .compute_shader_bit = true },
            .{ .compute_shader_bit = true },
            .{},
            1,
            &barrier,
            0,
            null,
            0,
            null,
        );
        
        // Bind brush evaluation pipeline
        cmd.bindPipeline(.compute, self.brush_pipeline);
        
        // Dispatch brush evaluation
        const voxel_count = bounds.resolution[0] * bounds.resolution[1] * bounds.resolution[2];
        const brush_groups = (voxel_count + 63) / 64;
        cmd.dispatch(brush_groups, 1, 1);
        
        // Final barrier
        cmd.pipelineBarrier(
            .{ .compute_shader_bit = true },
            .{ .transfer_bit = true },
            .{},
            1,
            &barrier,
            0,
            null,
            0,
            null,
        );
    }
};

pub const WorldBounds = struct {
    min: [3]f32,
    max: [3]f32,
    resolution: [3]u32,
    voxel_size: f32,
};

// C API exports
export fn gpu_worldgen_create(device: *c.VkDevice, allocator: *anyopaque) ?*GpuWorldgen {
    const alloc = @ptrCast(*std.mem.Allocator, @alignCast(@alignOf(std.mem.Allocator), allocator));
    const worldgen = alloc.create(GpuWorldgen) catch return null;
    worldgen.* = GpuWorldgen.init(@ptrCast(vk.Device, device), alloc.*) catch {
        alloc.destroy(worldgen);
        return null;
    };
    return worldgen;
}

export fn gpu_worldgen_destroy(worldgen: *GpuWorldgen) void {
    const allocator = worldgen.allocator;
    worldgen.deinit();
    allocator.destroy(worldgen);
}

export fn gpu_worldgen_generate(
    worldgen: *GpuWorldgen,
    cmd: *c.VkCommandBuffer,
    bounds_min: [3]f32,
    bounds_max: [3]f32,
    resolution: [3]u32,
    voxel_size: f32,
    sdf_tree: *c.VkBuffer,
    output_buffer: *c.VkBuffer,
    descriptor_set: *c.VkDescriptorSet,
) void {
    const bounds = WorldBounds{
        .min = bounds_min,
        .max = bounds_max,
        .resolution = resolution,
        .voxel_size = voxel_size,
    };
    
    worldgen.generateWorld(
        @ptrCast(vk.CommandBuffer, cmd),
        bounds,
        @ptrCast(vk.Buffer, sdf_tree),
        @ptrCast(vk.Buffer, output_buffer),
        @ptrCast(vk.DescriptorSet, descriptor_set),
    ) catch {
        // Handle error
        std.log.err("Failed to generate world", .{});
    };
}