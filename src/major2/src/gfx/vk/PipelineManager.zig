const std = @import("std");
const vk = @import("vulkan");
const gfx = @import("gfx.zig");

pub const DescriptorType = enum {
    uniform_buffer,
    storage_buffer,
    storage_buffer_dynamic,
    combined_image_sampler,
    storage_image,
    uniform_texel_buffer,
    storage_texel_buffer,
    
    pub fn toVulkan(self: DescriptorType) vk.DescriptorType {
        return switch (self) {
            .uniform_buffer => .uniform_buffer,
            .storage_buffer => .storage_buffer,
            .storage_buffer_dynamic => .storage_buffer_dynamic,
            .combined_image_sampler => .combined_image_sampler,
            .storage_image => .storage_image,
            .uniform_texel_buffer => .uniform_texel_buffer,
            .storage_texel_buffer => .storage_texel_buffer,
        };
    }
};

pub const ShaderStage = enum {
    vertex,
    fragment,
    compute,
    geometry,
    tessellation_control,
    tessellation_evaluation,
    
    pub fn toVulkan(self: ShaderStage) vk.ShaderStageFlags {
        return switch (self) {
            .vertex => .{ .vertex_bit = true },
            .fragment => .{ .fragment_bit = true },
            .compute => .{ .compute_bit = true },
            .geometry => .{ .geometry_bit = true },
            .tessellation_control => .{ .tessellation_control_bit = true },
            .tessellation_evaluation => .{ .tessellation_evaluation_bit = true },
        };
    }
};

pub const DescriptorBinding = struct {
    binding: u32,
    descriptor_type: DescriptorType,
    descriptor_count: u32,
    stage_flags: vk.ShaderStageFlags,
    name: []const u8,
    
    immutable_samplers: ?[]const vk.Sampler = null,
};

pub const DescriptorSetLayoutInfo = struct {
    bindings: []const DescriptorBinding,
    flags: vk.DescriptorSetLayoutCreateFlags = .{},
};

pub const BufferBinding = struct {
    buffer: vk.Buffer,
    offset: vk.DeviceSize,
    range: vk.DeviceSize,
};

pub const ImageBinding = struct {
    sampler: vk.Sampler,
    image_view: vk.ImageView,
    image_layout: vk.ImageLayout,
};

pub const DescriptorUpdate = union(enum) {
    buffer: BufferBinding,
    image: ImageBinding,
    buffer_array: []const BufferBinding,
    image_array: []const ImageBinding,
};

pub const DescriptorSetUpdate = struct {
    binding: u32,
    array_element: u32 = 0,
    update: DescriptorUpdate,
};

pub const PipelineLayoutInfo = struct {
    descriptor_set_layouts: []const vk.DescriptorSetLayout,
    push_constant_ranges: []const vk.PushConstantRange = &.{},
};

pub const ComputePipelineInfo = struct {
    shader_module: vk.ShaderModule,
    entry_point: [*:0]const u8 = "main",
    specialization_info: ?*const vk.SpecializationInfo = null,
    layout: vk.PipelineLayout,
    base_pipeline_handle: vk.Pipeline = .null_handle,
    base_pipeline_index: i32 = -1,
};

pub const GraphicsPipelineInfo = struct {
    stages: []const vk.PipelineShaderStageCreateInfo,
    vertex_input_state: vk.PipelineVertexInputStateCreateInfo,
    input_assembly_state: vk.PipelineInputAssemblyStateCreateInfo,
    tessellation_state: ?*const vk.PipelineTessellationStateCreateInfo = null,
    viewport_state: vk.PipelineViewportStateCreateInfo,
    rasterization_state: vk.PipelineRasterizationStateCreateInfo,
    multisample_state: vk.PipelineMultisampleStateCreateInfo,
    depth_stencil_state: ?*const vk.PipelineDepthStencilStateCreateInfo = null,
    color_blend_state: vk.PipelineColorBlendStateCreateInfo,
    dynamic_state: ?*const vk.PipelineDynamicStateCreateInfo = null,
    layout: vk.PipelineLayout,
    render_pass: vk.RenderPass,
    subpass: u32,
    base_pipeline_handle: vk.Pipeline = .null_handle,
    base_pipeline_index: i32 = -1,
};

pub const PipelineManager = struct {
    allocator: std.mem.Allocator,
    device: vk.Device,
    vkd: gfx.DeviceDispatch,
    
    descriptor_pool: vk.DescriptorPool,
    pipeline_cache: vk.PipelineCache,
    
    // Bindless descriptor set
    bindless_set_layout: vk.DescriptorSetLayout,
    bindless_set: vk.DescriptorSet,
    
    descriptor_set_layouts: std.AutoHashMap(u64, vk.DescriptorSetLayout),
    pipeline_layouts: std.AutoHashMap(u64, vk.PipelineLayout),
    compute_pipelines: std.AutoHashMap(u64, vk.Pipeline),
    graphics_pipelines: std.AutoHashMap(u64, vk.Pipeline),
    
    allocated_descriptor_sets: std.ArrayList(vk.DescriptorSet),
    
    pub fn init(allocator: std.mem.Allocator, device: vk.Device, vkd: gfx.DeviceDispatch) !PipelineManager {
        std.debug.print("PipelineManager.init called with device: {}\n", .{device});
        std.debug.print("vkGetBufferDeviceAddress function pointer: {?}\n", .{vkd.vkGetBufferDeviceAddress});
        
        // Validate critical function pointers
        if (vkd.vkCmdBindPipeline == null) {
            std.debug.panic("vkCmdBindPipeline is null in dispatch table during init!\n", .{});
        }
        if (vkd.vkCmdDispatch == null) {
            std.debug.panic("vkCmdDispatch is null in dispatch table during init!\n", .{});
        }
        if (vkd.vkCmdPushConstants == null) {
            std.debug.panic("vkCmdPushConstants is null in dispatch table during init!\n", .{});
        }
        
        std.debug.print("Critical dispatch functions validated:\n", .{});
        std.debug.print("  vkCmdBindPipeline: {*}\n", .{vkd.vkCmdBindPipeline.?});
        std.debug.print("  vkCmdDispatch: {*}\n", .{vkd.vkCmdDispatch.?});
        std.debug.print("  vkCmdPushConstants: {*}\n", .{vkd.vkCmdPushConstants.?});
        // Create a large pool for bindless descriptors
        const pool_sizes = [_]vk.DescriptorPoolSize{
            .{ .type = .uniform_buffer, .descriptor_count = 10000 },
            .{ .type = .storage_buffer, .descriptor_count = 10000 },
            .{ .type = .combined_image_sampler, .descriptor_count = 10000 },
            .{ .type = .storage_image, .descriptor_count = 1000 },
        };
        
        const pool_info = vk.DescriptorPoolCreateInfo{
            .s_type = .descriptor_pool_create_info,
            .p_next = null,
            .flags = .{ .free_descriptor_set_bit = true, .update_after_bind_bit = true },
            .max_sets = 1000,
            .pool_size_count = pool_sizes.len,
            .p_pool_sizes = &pool_sizes,
        };
        
        var descriptor_pool: vk.DescriptorPool = undefined;
        const pool_result = vkd.vkCreateDescriptorPool.?(device, &pool_info, null, &descriptor_pool);
        if (pool_result != .success) return error.FailedToCreateDescriptorPool;
        errdefer vkd.vkDestroyDescriptorPool.?(device, descriptor_pool, null);
        
        const cache_info = vk.PipelineCacheCreateInfo{
            .s_type = .pipeline_cache_create_info,
            .p_next = null,
            .flags = .{},
            .initial_data_size = 0,
            .p_initial_data = null,
        };
        
        var pipeline_cache: vk.PipelineCache = undefined;
        const cache_result = vkd.vkCreatePipelineCache.?(device, &cache_info, null, &pipeline_cache);
        if (cache_result != .success) return error.FailedToCreatePipelineCache;
        errdefer vkd.vkDestroyPipelineCache.?(device, pipeline_cache, null);
        
        // Create bindless descriptor set layout
        const bindless_layout = try createBindlessLayout(device, vkd);
        errdefer vkd.vkDestroyDescriptorSetLayout.?(device, bindless_layout, null);
        
        // Allocate the bindless descriptor set
        const alloc_info = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = descriptor_pool,
            .descriptor_set_count = 1,
            .p_set_layouts = &[_]vk.DescriptorSetLayout{bindless_layout},
        };
        
        var bindless_sets: [1]vk.DescriptorSet = undefined;
        const result = vkd.vkAllocateDescriptorSets.?(device, &alloc_info, &bindless_sets);
        if (result != .success) return error.FailedToAllocateBindlessSet;
        const bindless_set = bindless_sets[0];
        
        const manager = PipelineManager{
            .allocator = allocator,
            .device = device,
            .vkd = vkd,
            .descriptor_pool = descriptor_pool,
            .pipeline_cache = pipeline_cache,
            .bindless_set_layout = bindless_layout,
            .bindless_set = bindless_set,
            .descriptor_set_layouts = std.AutoHashMap(u64, vk.DescriptorSetLayout).init(allocator),
            .pipeline_layouts = std.AutoHashMap(u64, vk.PipelineLayout).init(allocator),
            .compute_pipelines = std.AutoHashMap(u64, vk.Pipeline).init(allocator),
            .graphics_pipelines = std.AutoHashMap(u64, vk.Pipeline).init(allocator),
            .allocated_descriptor_sets = std.ArrayList(vk.DescriptorSet).init(allocator),
        };
        
        std.debug.print("PipelineManager created with vkGetBufferDeviceAddress: {?}\n", .{manager.vkd.vkGetBufferDeviceAddress});
        
        // Final validation of the created manager
        if (manager.vkd.vkCmdBindPipeline == null) {
            std.debug.panic("vkCmdBindPipeline became null after manager creation!\n", .{});
        }
        std.debug.print("Manager dispatch table still valid after creation\n", .{});
        
        return manager;
    }
    
    fn createBindlessLayout(device: vk.Device, vkd: gfx.DeviceDispatch) !vk.DescriptorSetLayout {
        // Create bindings for bindless resources
        const bindings = [_]vk.DescriptorSetLayoutBinding{
            // Bindless storage buffers
            .{
                .binding = 0,
                .descriptor_type = .storage_buffer,
                .descriptor_count = 10000, // Large array for bindless
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
                .p_immutable_samplers = null,
            },
            // Bindless uniform buffers
            .{
                .binding = 1,
                .descriptor_type = .uniform_buffer,
                .descriptor_count = 1000,
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
                .p_immutable_samplers = null,
            },
            // Bindless samplers/images
            .{
                .binding = 2,
                .descriptor_type = .combined_image_sampler,
                .descriptor_count = 1000,
                .stage_flags = .{ .vertex_bit = true, .fragment_bit = true, .compute_bit = true },
                .p_immutable_samplers = null,
            },
        };
        
        // Enable descriptor indexing features
        // Note: variable_descriptor_count_bit can only be used on the last binding
        const binding_flags = [_]vk.DescriptorBindingFlags{
            .{ .partially_bound_bit = true, .update_after_bind_bit = true },
            .{ .partially_bound_bit = true, .update_after_bind_bit = true },
            .{ .partially_bound_bit = true, .update_after_bind_bit = true, .variable_descriptor_count_bit = true },
        };
        
        const flags_info = vk.DescriptorSetLayoutBindingFlagsCreateInfo{
            .s_type = .descriptor_set_layout_binding_flags_create_info,
            .p_next = null,
            .binding_count = bindings.len,
            .p_binding_flags = &binding_flags,
        };
        
        const layout_info = vk.DescriptorSetLayoutCreateInfo{
            .s_type = .descriptor_set_layout_create_info,
            .p_next = &flags_info,
            .flags = .{ .update_after_bind_pool_bit = true },
            .binding_count = bindings.len,
            .p_bindings = &bindings,
        };
        
        var layout: vk.DescriptorSetLayout = undefined;
        const result = vkd.vkCreateDescriptorSetLayout.?(device, &layout_info, null, &layout);
        if (result != .success) return error.FailedToCreateBindlessLayout;
        
        return layout;
    }
    
    pub fn deinit(self: *PipelineManager) void {
        var graphics_it = self.graphics_pipelines.iterator();
        while (graphics_it.next()) |entry| {
            self.vkd.vkDestroyPipeline.?(self.device, entry.value_ptr.*, null);
        }
        
        var compute_it = self.compute_pipelines.iterator();
        while (compute_it.next()) |entry| {
            self.vkd.vkDestroyPipeline.?(self.device, entry.value_ptr.*, null);
        }
        
        var layout_it = self.pipeline_layouts.iterator();
        while (layout_it.next()) |entry| {
            self.vkd.vkDestroyPipelineLayout.?(self.device, entry.value_ptr.*, null);
        }
        
        var set_layout_it = self.descriptor_set_layouts.iterator();
        while (set_layout_it.next()) |entry| {
            self.vkd.vkDestroyDescriptorSetLayout.?(self.device, entry.value_ptr.*, null);
        }
        
        self.vkd.vkDestroyDescriptorSetLayout.?(self.device, self.bindless_set_layout, null);
        self.vkd.vkDestroyPipelineCache.?(self.device, self.pipeline_cache, null);
        self.vkd.vkDestroyDescriptorPool.?(self.device, self.descriptor_pool, null);
        
        self.graphics_pipelines.deinit();
        self.compute_pipelines.deinit();
        self.pipeline_layouts.deinit();
        self.descriptor_set_layouts.deinit();
        self.allocated_descriptor_sets.deinit();
    }
    
    pub fn createDescriptorSetLayout(self: *PipelineManager, info: DescriptorSetLayoutInfo) !vk.DescriptorSetLayout {
        const hash = hashDescriptorSetLayoutInfo(info);
        
        if (self.descriptor_set_layouts.get(hash)) |layout| {
            return layout;
        }
        
        var bindings = try self.allocator.alloc(vk.DescriptorSetLayoutBinding, info.bindings.len);
        defer self.allocator.free(bindings);
        
        for (info.bindings, 0..) |binding, i| {
            bindings[i] = .{
                .binding = binding.binding,
                .descriptor_type = binding.descriptor_type.toVulkan(),
                .descriptor_count = binding.descriptor_count,
                .stage_flags = binding.stage_flags,
                .p_immutable_samplers = if (binding.immutable_samplers) |samplers| samplers.ptr else null,
            };
        }
        
        const create_info = vk.DescriptorSetLayoutCreateInfo{
            .flags = info.flags,
            .binding_count = @intCast(bindings.len),
            .p_bindings = bindings.ptr,
        };
        
        var layout: vk.DescriptorSetLayout = undefined;
        const result = self.vkd.vkCreateDescriptorSetLayout.?(self.device, &create_info, null, &layout);
        if (result != .success) return error.FailedToCreateDescriptorSetLayout;
        try self.descriptor_set_layouts.put(hash, layout);
        
        return layout;
    }
    
    pub fn createPipelineLayout(self: *PipelineManager, info: PipelineLayoutInfo) !vk.PipelineLayout {
        const hash = hashPipelineLayoutInfo(info);
        
        if (self.pipeline_layouts.get(hash)) |layout| {
            return layout;
        }
        
        const create_info = vk.PipelineLayoutCreateInfo{
            .set_layout_count = @intCast(info.descriptor_set_layouts.len),
            .p_set_layouts = info.descriptor_set_layouts.ptr,
            .push_constant_range_count = @intCast(info.push_constant_ranges.len),
            .p_push_constant_ranges = info.push_constant_ranges.ptr,
        };
        
        var layout: vk.PipelineLayout = undefined;
        const result = self.vkd.vkCreatePipelineLayout.?(self.device, &create_info, null, &layout);
        if (result != .success) return error.FailedToCreatePipelineLayout;
        try self.pipeline_layouts.put(hash, layout);
        
        return layout;
    }
    
    pub fn createComputePipeline(self: *PipelineManager, info: ComputePipelineInfo) !vk.Pipeline {
        const hash = hashComputePipelineInfo(info);
        
        if (self.compute_pipelines.get(hash)) |pipeline| {
            return pipeline;
        }
        
        const stage_info = vk.PipelineShaderStageCreateInfo{
            .s_type = .pipeline_shader_stage_create_info,
            .p_next = null,
            .flags = .{},
            .stage = .{ .compute_bit = true },
            .module = info.shader_module,
            .p_name = info.entry_point,
            .p_specialization_info = info.specialization_info,
        };
        
        const create_info = vk.ComputePipelineCreateInfo{
            .s_type = .compute_pipeline_create_info,
            .p_next = null,
            .flags = .{},
            .stage = stage_info,
            .layout = info.layout,
            .base_pipeline_handle = info.base_pipeline_handle,
            .base_pipeline_index = info.base_pipeline_index,
        };
        
        var pipeline: vk.Pipeline = undefined;
        const result = self.vkd.vkCreateComputePipelines.?(
            self.device,
            .null_handle, // Disable pipeline cache to avoid stale pipelines
            1,
            @ptrCast(&create_info),
            null,
            @ptrCast(&pipeline)
        );
        if (result != .success) return error.FailedToCreateComputePipeline;
        
        try self.compute_pipelines.put(hash, pipeline);
        return pipeline;
    }
    
    pub fn createGraphicsPipeline(self: *PipelineManager, info: GraphicsPipelineInfo) !vk.Pipeline {
        const hash = hashGraphicsPipelineInfo(info);
        
        if (self.graphics_pipelines.get(hash)) |pipeline| {
            return pipeline;
        }
        
        const create_info = vk.GraphicsPipelineCreateInfo{
            .stage_count = @intCast(info.stages.len),
            .p_stages = info.stages.ptr,
            .p_vertex_input_state = &info.vertex_input_state,
            .p_input_assembly_state = &info.input_assembly_state,
            .p_tessellation_state = info.tessellation_state,
            .p_viewport_state = &info.viewport_state,
            .p_rasterization_state = &info.rasterization_state,
            .p_multisample_state = &info.multisample_state,
            .p_depth_stencil_state = info.depth_stencil_state,
            .p_color_blend_state = &info.color_blend_state,
            .p_dynamic_state = info.dynamic_state,
            .layout = info.layout,
            .render_pass = info.render_pass,
            .subpass = info.subpass,
            .base_pipeline_handle = info.base_pipeline_handle,
            .base_pipeline_index = info.base_pipeline_index,
        };
        
        var pipeline: vk.Pipeline = undefined;
        const result = self.vkd.vkCreateGraphicsPipelines.?(
            self.device,
            self.pipeline_cache,
            1,
            @ptrCast(&create_info),
            null,
            @ptrCast(&pipeline)
        );
        if (result != .success) return error.FailedToCreateGraphicsPipeline;
        
        try self.graphics_pipelines.put(hash, pipeline);
        return pipeline;
    }
    
    pub fn allocateDescriptorSets(self: *PipelineManager, layouts: []const vk.DescriptorSetLayout) ![]vk.DescriptorSet {
        const sets = try self.allocator.alloc(vk.DescriptorSet, layouts.len);
        
        const alloc_info = vk.DescriptorSetAllocateInfo{
            .descriptor_pool = self.descriptor_pool,
            .descriptor_set_count = @intCast(layouts.len),
            .p_set_layouts = layouts.ptr,
        };
        
        const result = self.vkd.vkAllocateDescriptorSets.?(self.device, &alloc_info, sets.ptr);
        if (result != .success) return error.FailedToAllocateDescriptorSets;
        
        try self.allocated_descriptor_sets.appendSlice(sets);
        
        return sets;
    }
    
    pub fn updateDescriptorSets(self: *PipelineManager, set: vk.DescriptorSet, updates: []const DescriptorSetUpdate) !void {
        var write_count: u32 = 0;
        var writes = try self.allocator.alloc(vk.WriteDescriptorSet, updates.len);
        defer self.allocator.free(writes);
        
        var buffer_infos = std.ArrayList(vk.DescriptorBufferInfo).init(self.allocator);
        defer buffer_infos.deinit();
        
        var image_infos = std.ArrayList(vk.DescriptorImageInfo).init(self.allocator);
        defer image_infos.deinit();
        
        for (updates) |update| {
            writes[write_count] = .{
                .dst_set = set,
                .dst_binding = update.binding,
                .dst_array_element = update.array_element,
                .descriptor_count = undefined,
                .descriptor_type = undefined,
                .p_image_info = undefined,
                .p_buffer_info = undefined,
                .p_texel_buffer_view = undefined,
            };
            
            switch (update.update) {
                .buffer => |buffer| {
                    const buffer_info = vk.DescriptorBufferInfo{
                        .buffer = buffer.buffer,
                        .offset = buffer.offset,
                        .range = buffer.range,
                    };
                    try buffer_infos.append(buffer_info);
                    
                    writes[write_count].descriptor_count = 1;
                    writes[write_count].descriptor_type = .storage_buffer;
                    writes[write_count].p_buffer_info = @ptrCast(&buffer_infos.items[buffer_infos.items.len - 1]);
                },
                .image => |image| {
                    const image_info = vk.DescriptorImageInfo{
                        .sampler = image.sampler,
                        .image_view = image.image_view,
                        .image_layout = image.image_layout,
                    };
                    try image_infos.append(image_info);
                    
                    writes[write_count].descriptor_count = 1;
                    writes[write_count].descriptor_type = .combined_image_sampler;
                    writes[write_count].p_image_info = @ptrCast(&image_infos.items[image_infos.items.len - 1]);
                },
                .buffer_array => |buffers| {
                    const start_index = buffer_infos.items.len;
                    for (buffers) |buffer| {
                        const buffer_info = vk.DescriptorBufferInfo{
                            .buffer = buffer.buffer,
                            .offset = buffer.offset,
                            .range = buffer.range,
                        };
                        try buffer_infos.append(buffer_info);
                    }
                    
                    writes[write_count].descriptor_count = @intCast(buffers.len);
                    writes[write_count].descriptor_type = .storage_buffer;
                    writes[write_count].p_buffer_info = @ptrCast(&buffer_infos.items[start_index]);
                },
                .image_array => |images| {
                    const start_index = image_infos.items.len;
                    for (images) |image| {
                        const image_info = vk.DescriptorImageInfo{
                            .sampler = image.sampler,
                            .image_view = image.image_view,
                            .image_layout = image.image_layout,
                        };
                        try image_infos.append(image_info);
                    }
                    
                    writes[write_count].descriptor_count = @intCast(images.len);
                    writes[write_count].descriptor_type = .combined_image_sampler;
                    writes[write_count].p_image_info = @ptrCast(&image_infos.items[start_index]);
                },
            }
            
            write_count += 1;
        }
        
        self.vkd.vkUpdateDescriptorSets.?(self.device, write_count, writes.ptr, 0, undefined);
    }
    
    pub fn freeDescriptorSets(self: *PipelineManager, sets: []const vk.DescriptorSet) !void {
        const result = self.vkd.vkFreeDescriptorSets.?(self.device, self.descriptor_pool, @intCast(sets.len), sets.ptr);
        if (result != .success) return error.FailedToFreeDescriptorSets;
        
        for (sets) |set| {
            for (self.allocated_descriptor_sets.items, 0..) |allocated_set, i| {
                if (allocated_set == set) {
                    _ = self.allocated_descriptor_sets.swapRemove(i);
                    break;
                }
            }
        }
    }
    
    fn hashDescriptorSetLayoutInfo(info: DescriptorSetLayoutInfo) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&info.flags));
        for (info.bindings) |binding| {
            hasher.update(std.mem.asBytes(&binding.binding));
            hasher.update(std.mem.asBytes(&binding.descriptor_type));
            hasher.update(std.mem.asBytes(&binding.descriptor_count));
            hasher.update(std.mem.asBytes(&binding.stage_flags));
        }
        return hasher.final();
    }
    
    fn hashPipelineLayoutInfo(info: PipelineLayoutInfo) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (info.descriptor_set_layouts) |layout| {
            hasher.update(std.mem.asBytes(&layout));
        }
        for (info.push_constant_ranges) |range| {
            hasher.update(std.mem.asBytes(&range));
        }
        return hasher.final();
    }
    
    fn hashComputePipelineInfo(info: ComputePipelineInfo) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(std.mem.asBytes(&info.shader_module));
        hasher.update(std.mem.span(info.entry_point));
        hasher.update(std.mem.asBytes(&info.layout));
        return hasher.final();
    }
    
    fn hashGraphicsPipelineInfo(info: GraphicsPipelineInfo) u64 {
        var hasher = std.hash.Wyhash.init(0);
        for (info.stages) |stage| {
            hasher.update(std.mem.asBytes(&stage.module));
            hasher.update(std.mem.asBytes(&stage.stage));
        }
        hasher.update(std.mem.asBytes(&info.layout));
        hasher.update(std.mem.asBytes(&info.render_pass));
        hasher.update(std.mem.asBytes(&info.subpass));
        return hasher.final();
    }
    
    // Helper to get buffer device address
    pub fn getBufferDeviceAddress(self: *PipelineManager, buffer: vk.Buffer) vk.DeviceAddress {
        std.debug.print("getBufferDeviceAddress called for buffer: {}\n", .{buffer});
        
        const info = vk.BufferDeviceAddressInfo{
            .s_type = .buffer_device_address_info,
            .p_next = null,
            .buffer = buffer,
        };
        
        std.debug.print("Calling vkGetBufferDeviceAddress with device: {}, dispatch fn: {?}\n", .{self.device, self.vkd.vkGetBufferDeviceAddress});
        const address = self.vkd.vkGetBufferDeviceAddress.?(self.device, &info);
        std.debug.print("Got buffer device address: {}\n", .{address});
        
        return address;
    }
    
    // Create a null buffer that can be used for unbound resources
    pub fn createNullBuffer(self: *PipelineManager) !vk.Buffer {
        const buffer_info = vk.BufferCreateInfo{
            .size = 16, // Minimal size
            .usage = .{ 
                .storage_buffer_bit = true,
                .shader_device_address_bit = true,
            },
            .sharing_mode = .exclusive,
        };
        
        var buffer: vk.Buffer = undefined;
        const result = self.vkd.vkCreateBuffer.?(self.device, &buffer_info, null, &buffer);
        if (result != .success) return error.FailedToCreateNullBuffer;
        
        // Allocate memory with device address flag
        var mem_reqs: vk.MemoryRequirements = undefined;
        self.vkd.vkGetBufferMemoryRequirements.?(self.device, buffer, &mem_reqs);
        
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
        _ = self.vkd.vkAllocateMemory.?(self.device, &alloc_info, null, &memory);
        _ = self.vkd.vkBindBufferMemory.?(self.device, buffer, memory, 0);
        
        return buffer;
    }
};

// Device address pipeline using buffer device addresses
pub const DeviceAddressPipeline = struct {
    manager: *PipelineManager,
    shader_module: vk.ShaderModule,
    pipeline_layout: vk.PipelineLayout,
    pipeline: vk.Pipeline,
    
    pub const PushConstants = struct {
        // Buffer device addresses - up to 16 buffers
        buffer_addresses: [16]vk.DeviceAddress = [_]vk.DeviceAddress{0} ** 16,
        // Additional parameters
        params: [16]u32 = [_]u32{0} ** 16,
    };
    
    pub fn create(
        manager: *PipelineManager,
        shader_code: []const u32,
        push_constant_size: u32,
    ) !DeviceAddressPipeline {
        // Validate manager pointer
        if (@intFromPtr(manager) == 0) {
            return error.NullManagerPointer;
        }
        
        // Validate dispatch table in manager
        if (manager.vkd.vkCmdBindPipeline == null) {
            std.debug.panic("vkCmdBindPipeline is null in manager during pipeline creation!\n", .{});
        }
        
        std.debug.print("Creating DeviceAddressPipeline with manager at {*}\n", .{manager});
        std.debug.print("Manager dispatch table check: vkCmdBindPipeline = {*}\n", .{manager.vkd.vkCmdBindPipeline.?});
        const shader_info = vk.ShaderModuleCreateInfo{
            .s_type = .shader_module_create_info,
            .p_next = null,
            .flags = .{},
            .code_size = shader_code.len * @sizeOf(u32),
            .p_code = shader_code.ptr,
        };
        
        var shader_module: vk.ShaderModule = undefined;
        const shader_result = manager.vkd.vkCreateShaderModule.?(manager.device, &shader_info, null, &shader_module);
        if (shader_result != .success) return error.FailedToCreateShaderModule;
        errdefer manager.vkd.vkDestroyShaderModule.?(manager.device, shader_module, null);
        
        // Create layout with only push constants (no descriptor sets needed with device addresses)
        const push_constant_ranges = [_]vk.PushConstantRange{
            .{
                .stage_flags = .{ .compute_bit = true },
                .offset = 0,
                .size = if (push_constant_size > 0) push_constant_size else @sizeOf(PushConstants),
            },
        };
        
        const layout_info = vk.PipelineLayoutCreateInfo{
            .s_type = .pipeline_layout_create_info,
            .p_next = null,
            .flags = .{},
            .set_layout_count = 0, // No descriptor sets!
            .p_set_layouts = null,
            .push_constant_range_count = push_constant_ranges.len,
            .p_push_constant_ranges = &push_constant_ranges,
        };
        
        var pipeline_layout: vk.PipelineLayout = undefined;
        const layout_result = manager.vkd.vkCreatePipelineLayout.?(manager.device, &layout_info, null, &pipeline_layout);
        if (layout_result != .success) {
            std.debug.print("Failed to create pipeline layout: {}\n", .{layout_result});
            return error.FailedToCreatePipelineLayout;
        }
        errdefer manager.vkd.vkDestroyPipelineLayout.?(manager.device, pipeline_layout, null);
        
        std.debug.print("Created pipeline layout 0x{x} with push constant size: {}, compute_bit: {}\n", .{
            @intFromEnum(pipeline_layout),
            push_constant_ranges[0].size,
            push_constant_ranges[0].stage_flags.compute_bit
        });
        
        // Create compute pipeline directly without caching
        const stage_info = vk.PipelineShaderStageCreateInfo{
            .s_type = .pipeline_shader_stage_create_info,
            .p_next = null,
            .flags = .{},
            .stage = .{ .compute_bit = true },
            .module = shader_module,
            .p_name = "main",
            .p_specialization_info = null,
        };
        
        const pipeline_create_info = vk.ComputePipelineCreateInfo{
            .s_type = .compute_pipeline_create_info,
            .p_next = null,
            .flags = .{},
            .stage = stage_info,
            .layout = pipeline_layout,
            .base_pipeline_handle = .null_handle,
            .base_pipeline_index = -1,
        };
        
        var pipeline: vk.Pipeline = undefined;
        const pipeline_result = manager.vkd.vkCreateComputePipelines.?(
            manager.device,
            .null_handle, // Don't use pipeline cache
            1,
            @ptrCast(&pipeline_create_info),
            null,
            @ptrCast(&pipeline)
        );
        if (pipeline_result != .success) {
            std.debug.print("Failed to create compute pipeline: {}\n", .{pipeline_result});
            return error.FailedToCreateComputePipeline;
        }
        
        std.debug.print("Created pipeline 0x{x} with layout 0x{x}\n", .{
            @intFromEnum(pipeline),
            @intFromEnum(pipeline_layout)
        });
        
        const result = DeviceAddressPipeline{
            .manager = manager,
            .shader_module = shader_module,
            .pipeline_layout = pipeline_layout,
            .pipeline = pipeline,
        };
        
        std.debug.print("DeviceAddressPipeline created with manager: {*}\n", .{result.manager});
        
        // Final validation before returning
        if (result.manager.vkd.vkCmdBindPipeline == null) {
            std.debug.panic("vkCmdBindPipeline became null after pipeline creation!\n", .{});
        }
        std.debug.print("Pipeline dispatch validation passed: vkCmdBindPipeline = {*}\n", .{result.manager.vkd.vkCmdBindPipeline.?});
        
        return result;
    }
    
    pub fn deinit(self: *DeviceAddressPipeline) void {
        self.manager.vkd.vkDestroyShaderModule.?(self.manager.device, self.shader_module, null);
        self.manager.vkd.vkDestroyPipelineLayout.?(self.manager.device, self.pipeline_layout, null);
        self.manager.vkd.vkDestroyPipeline.?(self.manager.device, self.pipeline, null);
    }
    
    pub fn bind(self: *DeviceAddressPipeline, cmd: vk.CommandBuffer) void {
        std.debug.print("DeviceAddressPipeline.bind called\n", .{});
        std.debug.print("  self: {*}\n", .{self});
        std.debug.print("  self.manager: {*}\n", .{self.manager});
        std.debug.print("  cmd: {}\n", .{cmd});
        std.debug.print("  pipeline: {}\n", .{self.pipeline});
        std.debug.print("  pipeline_layout: {}\n", .{self.pipeline_layout});
        
        // Debug print vkd info
        std.debug.print("  vkd pointer: {*}\n", .{&self.manager.vkd});
        std.debug.print("  vkCmdBindPipeline function: {?}\n", .{self.manager.vkd.vkCmdBindPipeline});
        
        // Check if the dispatch table looks valid
        if (self.manager.vkd.vkCmdDispatch) |dispatchFn| {
            std.debug.print("  vkCmdDispatch function (for comparison): {*}\n", .{dispatchFn});
        }
        if (self.manager.vkd.vkCmdPushConstants) |pushFn| {
            std.debug.print("  vkCmdPushConstants function (for comparison): {*}\n", .{pushFn});
        }
        
        // Validate handles
        if (cmd == .null_handle) {
            std.debug.panic("Command buffer is null in DeviceAddressPipeline.bind\n", .{});
        }
        if (self.pipeline == .null_handle) {
            std.debug.panic("Pipeline is null in DeviceAddressPipeline.bind\n", .{});
        }
        
        // Additional validation
        std.debug.print("Command buffer handle value: 0x{x}\n", .{@intFromEnum(cmd)});
        std.debug.print("Pipeline handle value: 0x{x}\n", .{@intFromEnum(self.pipeline)});
        std.debug.print("Manager device handle: 0x{x}\n", .{@intFromEnum(self.manager.device)});
        
        // Try to check if command buffer looks suspicious
        const cmd_value = @intFromEnum(cmd);
        if (cmd_value == 0 or cmd_value == 0xFFFFFFFFFFFFFFFF or cmd_value == 0xDEADBEEF) {
            std.debug.panic("Command buffer has suspicious value: 0x{x}\n", .{cmd_value});
        }
        
        std.debug.print("About to call vkCmdBindPipeline\n", .{});
        
        // First check if the dispatch table itself is valid
        const vkd_ptr = @intFromPtr(&self.manager.vkd);
        if (vkd_ptr == 0) {
            std.debug.panic("Device dispatch table pointer is null!\n", .{});
        }
        
        // Check if vkCmdBindPipeline is available
        if (self.manager.vkd.vkCmdBindPipeline == null) {
            std.debug.panic("vkCmdBindPipeline is null in dispatch table!\n", .{});
        }
        
        const bindPipelineFn = self.manager.vkd.vkCmdBindPipeline.?;
        std.debug.print("bindPipelineFn pointer: {*}\n", .{bindPipelineFn});
        std.debug.print("bindPipelineFn address: 0x{x}\n", .{@intFromPtr(bindPipelineFn)});
        
        // Validate the function pointer is in a reasonable address range
        const fn_addr = @intFromPtr(bindPipelineFn);
        if (fn_addr < 0x1000) {
            std.debug.panic("Function pointer address too low (null or invalid): 0x{x}\n", .{fn_addr});
        }
        
        // Additional validation: check that the function pointer is aligned
        if (fn_addr & 0xF != 0) {
            std.debug.panic("Function pointer not aligned: 0x{x}\n", .{fn_addr});
        }
        
        // Try to verify this is actually code by checking if nearby dispatch functions are similar
        if (self.manager.vkd.vkCmdDispatch) |dispatchFn| {
            const dispatch_addr = @intFromPtr(dispatchFn);
            const diff = if (fn_addr > dispatch_addr) fn_addr - dispatch_addr else dispatch_addr - fn_addr;
            if (diff > 0x1000000) { // Functions should be relatively close in memory
                std.debug.print("WARNING: vkCmdBindPipeline and vkCmdDispatch are suspiciously far apart: 0x{x}\n", .{diff});
            }
        }
        
        std.debug.print("Calling vkCmdBindPipeline with cmd=0x{x}, bindPoint=compute, pipeline=0x{x}\n", .{@intFromEnum(cmd), @intFromEnum(self.pipeline)});
        
        // Call through the dispatch table directly instead of through the optional
        self.manager.vkd.vkCmdBindPipeline.?(cmd, .compute, self.pipeline);
        
        std.debug.print("Pipeline bound successfully\n", .{});
        // No descriptor sets to bind!
    }
    
    pub fn pushConstants(self: *DeviceAddressPipeline, cmd: vk.CommandBuffer, data: *const anyopaque, size: u32) void {
        std.debug.print("DeviceAddressPipeline.pushConstants: cmd={}, layout={}, size={}\n", .{cmd, self.pipeline_layout, size});
        std.debug.print("vkCmdPushConstants function: {?}\n", .{self.manager.vkd.vkCmdPushConstants});
        if (self.manager.vkd.vkCmdPushConstants) |pushConstantsFn| {
            pushConstantsFn(
                cmd,
                self.pipeline_layout,
                .{ .compute_bit = true },
                0,
                size,
                data
            );
            std.debug.print("Push constants set successfully\n", .{});
        } else {
            std.debug.panic("vkCmdPushConstants is null!\n", .{});
        }
    }
    
    pub fn dispatch(self: *DeviceAddressPipeline, cmd: vk.CommandBuffer, x: u32, y: u32, z: u32) void {
        std.debug.print("DeviceAddressPipeline.dispatch: cmd={}, x={}, y={}, z={}\n", .{cmd, x, y, z});
        std.debug.print("vkCmdDispatch function: {?}\n", .{self.manager.vkd.vkCmdDispatch});
        if (self.manager.vkd.vkCmdDispatch) |dispatchFn| {
            dispatchFn(cmd, x, y, z);
            std.debug.print("Dispatch called successfully\n", .{});
        } else {
            std.debug.panic("vkCmdDispatch is null!\n", .{});
        }
    }
};

// Keep SimplifiedComputePipeline as an alias for compatibility with old interface
pub const SimplifiedComputePipeline = struct {
    pipeline: DeviceAddressPipeline,
    descriptor_sets: []vk.DescriptorSet = &[_]vk.DescriptorSet{},
    descriptor_set_layout: vk.DescriptorSetLayout = .null_handle,
    
    pub fn create(
        manager: *PipelineManager,
        shader_code: []const u32,
        bindings: []const BindingInfo,
        push_constant_size: u32,
    ) !SimplifiedComputePipeline {
        _ = bindings; // Unused with device addresses
        const pipeline = try DeviceAddressPipeline.create(
            manager,
            shader_code,
            push_constant_size
        );
        
        return .{
            .pipeline = pipeline,
        };
    }
    
    pub fn deinit(self: *SimplifiedComputePipeline) void {
        self.pipeline.deinit();
    }
    
    pub fn bind(self: *SimplifiedComputePipeline, cmd: vk.CommandBuffer, set_index: u32) void {
        _ = set_index; // Unused
        self.pipeline.bind(cmd);
    }
    
    pub fn dispatch(self: *SimplifiedComputePipeline, cmd: vk.CommandBuffer, x: u32, y: u32, z: u32) void {
        self.pipeline.dispatch(cmd, x, y, z);
    }
};

pub const BindingInfo = struct {
    binding: u32,
    descriptor_type: DescriptorType,
    descriptor_count: u32 = 1,
    name: []const u8,
};