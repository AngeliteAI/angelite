const std = @import("std");
const vk = @import("vk.zig");
const compiler = @import("compiler.zig");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const ShaderCompiler = compiler.ShaderCompiler;
const UVec3 = @import("math").UVec3;

// Import C headers for direct stat access
const c = @cImport({
    @cInclude("sys/stat.h");
    @cInclude("time.h");
});

pub const PipelineError = error{
    LibraryNotFound,
    FunctionNotFound,
    PipelineCreationFailed,
    PipelineNotFound,
    InvalidPipelineType,
    ShaderCompilationFailed,
    OutOfMemory,
    InvalidConfiguration,
};

//get a zig std allocator
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
var allocator = gpa.allocator();

pub const PipelineType = enum {
    Compute,
    Graphics,
};

// Shader information
pub const ShaderInfo = struct {
    path: []const u8,
    shader_type: compiler.ShaderType,
    entry_point: []const u8 = "main",
};

// Base pipeline type that contains common functionality
pub const Pipeline = struct {
    name: []const u8,
    handle: vk.Pipeline,
    layout: vk.PipelineLayout,
    pipeline_type: PipelineType,

    pub fn deinit(self: *Pipeline, device: vk.Device) void {
        vk.destroyPipeline(device, self.handle, null);
        vk.destroyPipelineLayout(device, self.layout, null);
    }

    // Cast to AnyPipeline
    pub fn asAny(self: *Pipeline) *AnyPipeline {
        return @ptrCast(self);
    }
};

// Specialized compute pipeline
pub const ComputePipeline = struct {
    base: Pipeline,

    // Additional compute-specific fields
    shader_path: []const u8,

    // Store original configuration for hot reload
    push_constant_size: u32,
    descriptor_set_layouts: []const vk.DescriptorSetLayout,
    entry_point: []const u8,
    phase: u32,
    local_size: ?UVec3,

    pub fn init(name: []const u8, handle: vk.Pipeline, layout: vk.PipelineLayout, shader_path: []const u8, config: ComputePipelineConfig) !ComputePipeline {
        // Create a copy of the descriptor set layouts if needed
        const descriptor_layouts = config.descriptor_set_layouts;

        // Copy local_size if present
        var local_size_copy: ?UVec3 = null;
        if (config.local_size) |ls| {
            local_size_copy = ls;
        }

        // Make sure to get a copy of the entry point string
        const entry_point = try allocator.dupe(u8, config.shader.entry_point);

        return .{
            .base = .{
                .name = name,
                .handle = handle,
                .layout = layout,
                .pipeline_type = .Compute,
            },
            .shader_path = try allocator.dupe(u8, shader_path),
            .push_constant_size = config.push_constant_size,
            .descriptor_set_layouts = descriptor_layouts,
            .entry_point = entry_point,
            .phase = config.phase,
            .local_size = local_size_copy,
        };
    }

    pub fn deinit(self: *ComputePipeline) void {
        allocator.free(self.shader_path);
        allocator.free(self.entry_point);
    }
};

// Specialized graphics pipeline with dynamic rendering support
pub const GraphicsPipeline = struct {
    base: Pipeline,

    // Graphics pipeline specific fields
    vertex_shader_path: []const u8,
    fragment_shader_path: []const u8,
    color_formats: []const vk.Format,
    depth_format: ?vk.Format,

    // Store original configuration for hot reload
    push_constant_size: u32,
    descriptor_set_layouts: []const vk.DescriptorSetLayout,
    vertex_entry_point: []const u8,
    fragment_entry_point: []const u8,
    vertex_bindings: ?[]const vk.VertexInputBindingDescription,
    vertex_attributes: ?[]const vk.VertexInputAttributeDescription,
    topology: vk.PrimitiveTopology,
    cull_mode: vk.CullModeFlags,
    front_face: vk.FrontFace,
    blend_enable: bool,
    depth_test_enable: bool,
    depth_write_enable: bool,
    stencil_format: ?vk.Format,

    pub fn init(
        name: []const u8,
        handle: vk.Pipeline,
        layout: vk.PipelineLayout,
        vertex_path: []const u8,
        fragment_path: []const u8,
        color_formats: []const vk.Format,
        depth_format: ?vk.Format,
        config: GraphicsPipelineConfig,
    ) !GraphicsPipeline {
        // Create copies of the arrays and bindings
        const color_formats_copy = try allocator.dupe(vk.Format, color_formats);
        errdefer allocator.free(color_formats_copy);

        // Copy vertex bindings if present
        var vertex_bindings_copy: ?[]const vk.VertexInputBindingDescription = null;
        if (config.vertex_bindings) |bindings| {
            vertex_bindings_copy = try allocator.dupe(vk.VertexInputBindingDescription, bindings);
        }

        // Copy vertex attributes if present
        var vertex_attributes_copy: ?[]const vk.VertexInputAttributeDescription = null;
        if (config.vertex_attributes) |attrs| {
            vertex_attributes_copy = try allocator.dupe(vk.VertexInputAttributeDescription, attrs);
        }

        // Make sure to get copies of the entry point strings
        const vertex_entry = try allocator.dupe(u8, config.vertex_shader.entry_point);
        const fragment_entry = try allocator.dupe(u8, config.fragment_shader.entry_point);

        return .{
            .base = .{
                .name = name,
                .handle = handle,
                .layout = layout,
                .pipeline_type = .Graphics,
            },
            .vertex_shader_path = try allocator.dupe(u8, vertex_path),
            .fragment_shader_path = try allocator.dupe(u8, fragment_path),
            .color_formats = color_formats_copy,
            .depth_format = depth_format,
            .push_constant_size = config.push_constant_size,
            .descriptor_set_layouts = config.descriptor_set_layouts,
            .vertex_entry_point = vertex_entry,
            .fragment_entry_point = fragment_entry,
            .vertex_bindings = vertex_bindings_copy,
            .vertex_attributes = vertex_attributes_copy,
            .topology = config.topology,
            .cull_mode = config.cull_mode,
            .front_face = config.front_face,
            .blend_enable = config.blend_enable,
            .depth_test_enable = config.depth_test_enable,
            .depth_write_enable = config.depth_write_enable,
            .stencil_format = config.stencil_attachment_format,
        };
    }

    pub fn getHandle(self: *GraphicsPipeline) vk.Pipeline {
        return self.base.handle;
    }

    pub fn deinit(self: *GraphicsPipeline) void {
        allocator.free(self.vertex_shader_path);
        allocator.free(self.fragment_shader_path);
        allocator.free(self.color_formats);
        allocator.free(self.vertex_entry_point);
        allocator.free(self.fragment_entry_point);

        if (self.vertex_bindings) |bindings| {
            allocator.free(bindings);
        }

        if (self.vertex_attributes) |attrs| {
            allocator.free(attrs);
        }
    }
};

// Type-erased container for any pipeline type
pub const AnyPipeline = struct {
    base: Pipeline,

    // Cast to specific pipeline types
    pub fn asCompute(self: *AnyPipeline) ?*ComputePipeline {
        if (self.base.pipeline_type != .Compute) return null;
        return @ptrCast(self);
    }

    pub fn asGraphics(self: *AnyPipeline) ?*GraphicsPipeline {
        if (self.base.pipeline_type != .Graphics) return null;
        return @ptrCast(self);
    }
};

// Shader monitoring info
const ShaderMonitor = struct {
    path: []const u8,
    last_modified: i128,
    pipeline_name: []const u8,
};

// Configuration for compute pipeline creation
pub const ComputePipelineConfig = struct {
    shader: ShaderInfo,
    push_constant_size: u32 = 0,
    descriptor_set_layouts: []const vk.DescriptorSetLayout = &[_]vk.DescriptorSetLayout{},
    specialization_info: ?*const vk.SpecializationInfo = null,
    local_size: ?UVec3 = null,
    phase: u32 = 0,
};

// Configuration for graphics pipeline creation with dynamic rendering
pub const GraphicsPipelineConfig = struct {
    vertex_shader: ShaderInfo,
    fragment_shader: ShaderInfo,

    // Dynamic rendering settings
    color_attachment_formats: []const vk.Format,
    depth_attachment_format: ?vk.Format = null,
    stencil_attachment_format: ?vk.Format = null,

    // Pipeline settings
    push_constant_size: u32 = 0,
    descriptor_set_layouts: []const vk.DescriptorSetLayout = &[_]vk.DescriptorSetLayout{},
    vertex_bindings: ?[]const vk.VertexInputBindingDescription = null,
    vertex_attributes: ?[]const vk.VertexInputAttributeDescription = null,
    topology: vk.PrimitiveTopology = vk.TRIANGLE_LIST,
    cull_mode: vk.CullModeFlags = vk.CULL_MODE_BACK,
    front_face: vk.FrontFace = vk.COUNTER_CLOCKWISE,
    blend_enable: bool = false,
    depth_test_enable: bool = true,
    depth_write_enable: bool = true,
    viewport_scissor_dynamic: bool = true,
};

pub const PipelineCompiler = struct {
    device: vk.Device,
    pipelines: std.StringHashMap(*AnyPipeline),
    shader_monitors: std.ArrayList(ShaderMonitor),
    shader_compiler: *ShaderCompiler,
    is_reloading: bool = false, // Flag to prevent recursive reloading

    pub fn init(device: vk.Device) !*PipelineCompiler {
        var self = try allocator.create(PipelineCompiler);
        self.* = .{
            .device = device,
            .pipelines = std.StringHashMap(*AnyPipeline).init(allocator),
            .shader_monitors = std.ArrayList(ShaderMonitor).init(allocator),
            .shader_compiler = try compiler.ShaderCompiler.init(allocator),
            .is_reloading = false,
        };
        self.shader_compiler.setDevice(device);
        return self;
    }

    pub fn deinit(self: *PipelineCompiler) void {
        // Clean up pipelines
        var it = self.pipelines.iterator();
        while (it.next()) |entry| {
            var pipeline = entry.value_ptr.*;

            // Call the appropriate deinit
            switch (pipeline.base.pipeline_type) {
                .Compute => {
                    if (pipeline.asCompute()) |compute| {
                        compute.deinit(allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            allocator.destroy(pipeline);
            allocator.free(entry.key_ptr.*);
        }
        self.pipelines.deinit();

        // Clean up shader monitors
        for (self.shader_monitors.items) |monitor| {
            allocator.free(monitor.path);
            allocator.free(monitor.pipeline_name);
        }
        self.shader_monitors.deinit();

        // Clean up shader compiler
        self.shader_compiler.deinit();

        // Free self
        allocator.destroy(self);
    }

    // Private function to register a pipeline for hot reloading
    fn registerPipeline(self: *PipelineCompiler, pipeline: *AnyPipeline) !void {
        // Safety check - ensure pipeline name is not empty
        if (pipeline.base.name.len == 0) {
            std.debug.print("Error: Attempting to register pipeline with empty name\n", .{});
            return error.InvalidPipelineName;
        }

        // Use getEntry instead of contains to avoid potential recursion issues
        // This directly checks for the existence once rather than doing separate contains+put operations
        if (self.pipelines.getEntry(pipeline.base.name)) |_| {
            std.debug.print("Pipeline with name '{s}' already registered, skipping registration\n", .{pipeline.base.name});
            return;
        }

        const name_copy = try allocator.dupe(u8, pipeline.base.name);

        std.debug.print("Registering pipeline: {s}\n", .{name_copy});
        try self.pipelines.put(name_copy, pipeline);

        // Monitor shaders based on pipeline type
        switch (pipeline.base.pipeline_type) {
            .Compute => {
                const compute = pipeline.asCompute().?;
                try self.monitorShader(compute.shader_path, name_copy);
            },
            .Graphics => {
                const graphics = pipeline.asGraphics().?;
                try self.monitorShader(graphics.vertex_shader_path, name_copy);
                try self.monitorShader(graphics.fragment_shader_path, name_copy);
            },
        }
    }

    // Add a shader to monitor for changes
    fn monitorShader(self: *PipelineCompiler, path: []const u8, pipeline_name: []const u8) !void {
        std.debug.print("Monitoring shader: path={s}, pipeline={s}\n", .{ path, pipeline_name });

        // Use C stat directly to get file info
        var stat_buf: c.struct_stat = undefined;
        var file_mtime: i128 = 0;

        // Ensure path is null-terminated for C functions
        if (c.stat(path.ptr, &stat_buf) == 0) {
            // Convert stat time to an i128 timestamp
            file_mtime = @as(i128, stat_buf.st_mtime);
            std.debug.print("Got file timestamp: {d}\n", .{file_mtime});
        } else {
            std.debug.print("Warning: Failed to stat shader file: {s}, using default timestamp\n", .{path});
            // Continue with default timestamp
        }

        const path_copy = try allocator.dupe(u8, path);

        const pipeline_name_copy = try allocator.dupe(u8, pipeline_name);

        try self.shader_monitors.append(.{
            .path = path_copy,
            .last_modified = file_mtime,
            .pipeline_name = pipeline_name_copy,
        });

        std.debug.print("Now monitoring shader: {s} for pipeline {s}\n", .{ path, pipeline_name });
    }

    // Create a compute pipeline
    pub fn createComputePipeline(
        self: *PipelineCompiler,
        name: []const u8,
        config: ComputePipelineConfig,
    ) !*ComputePipeline {
        std.debug.print("Creating compute pipeline: {s}\n", .{name});

        // Compile or get cached compute shader
        std.debug.print("Compiling or getting cached shader: {s}\n", .{config.shader.path});
        const shader_module = try self.shader_compiler.compileShaderFile(config.shader.path, config.shader.shader_type);

        // Create specialization map entries
        var map_entries = std.ArrayList(vk.SpecializationMapEntry).init(allocator);
        defer map_entries.deinit();

        // Add phase specialization
        try map_entries.append(.{
            .constantID = 0,
            .offset = 0,
            .size = @sizeOf(u32),
        });

        // Add local size specialization if provided
        if (config.local_size) |_| {
            try map_entries.append(.{
                .constantID = 1,
                .offset = @sizeOf(u32),
                .size = @sizeOf(UVec3),
            });
        }

        // Create specialization data
        var specialization_data = std.ArrayList(u8).init(allocator);
        defer specialization_data.deinit();

        // Add phase data
        var phase_data: u32 = config.phase;
        try specialization_data.appendSlice(std.mem.asBytes(&phase_data));

        // Add local size data if provided
        if (config.local_size) |local_size| {
            try specialization_data.appendSlice(std.mem.asBytes(&local_size));
        }

        // Create specialization info
        const specialization_info = vk.SpecializationInfo{
            .mapEntryCount = @intCast(map_entries.items.len),
            .pMapEntries = map_entries.items.ptr,
            .dataSize = specialization_data.items.len,
            .pData = specialization_data.items.ptr,
        };

        // Create pipeline layout
        var pipeline_layout_info = vk.PipelineLayoutCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineLayoutCreateInfo),
            .setLayoutCount = @intCast(config.descriptor_set_layouts.len),
            .pSetLayouts = if (config.descriptor_set_layouts.len > 0) config.descriptor_set_layouts.ptr else null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        // Add push constants if needed
        var push_constant_range: vk.PushConstantRange = undefined;
        if (config.push_constant_size > 0) {
            push_constant_range = .{
                .stageFlags = vk.SHADER_STAGE_COMPUTE,
                .offset = 0,
                .size = config.push_constant_size,
            };
            pipeline_layout_info.pushConstantRangeCount = 1;
            pipeline_layout_info.pPushConstantRanges = &push_constant_range;
        }

        var pipeline_layout: vk.PipelineLayout = undefined;
        const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &pipeline_layout);

        if (layout_result != vk.SUCCESS) {
            std.debug.print("Failed to create pipeline layout", .{});
            return PipelineError.PipelineCreationFailed;
        }

        // Create compute pipeline
        const pipeline_info = vk.ComputePipelineCreateInfo{
            .sType = vk.sTy(vk.StructureType.ComputePipelineCreateInfo),
            .stage = .{
                .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                .stage = vk.SHADER_STAGE_COMPUTE,
                .module = shader_module,
                .pName = "main", // Always use "main" as the entry point for safety
                .pSpecializationInfo = &specialization_info,
            },
            .layout = pipeline_layout,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: vk.Pipeline = undefined;
        const result = vk.createComputePipelines(self.device, null, 1, &pipeline_info, null, &pipeline);

        if (result != vk.SUCCESS) {
            std.debug.print("Failed to create compute pipeline", .{});
            return PipelineError.PipelineCreationFailed;
        }

        // Create the pipeline object
        var compute_pipeline = try allocator.create(ComputePipeline);
        compute_pipeline.* = try ComputePipeline.init(name, pipeline, pipeline_layout, config.shader.path, config);

        // Automatically register the pipeline for hot reloading
        try self.registerPipeline(compute_pipeline.base.asAny());

        return compute_pipeline;
    }

    // Create a graphics pipeline with dynamic rendering
    pub fn createGraphicsPipeline(
        self: *PipelineCompiler,
        name: []const u8,
        config: GraphicsPipelineConfig,
    ) !*GraphicsPipeline {
        std.debug.print("Creating graphics pipeline: {s}\n", .{name});

        // Compile or get cached shaders
        std.debug.print("Compiling or getting cached vertex shader: {s}\n", .{config.vertex_shader.path});
        const vertex_module = try self.shader_compiler.compileShaderFile(config.vertex_shader.path, config.vertex_shader.shader_type);

        std.debug.print("Compiling or getting cached fragment shader: {s}\n", .{config.fragment_shader.path});
        const fragment_module = try self.shader_compiler.compileShaderFile(config.fragment_shader.path, config.fragment_shader.shader_type);

        // Create pipeline layout
        var pipeline_layout_info = vk.PipelineLayoutCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineLayoutCreateInfo),
            .setLayoutCount = @intCast(config.descriptor_set_layouts.len),
            .pSetLayouts = if (config.descriptor_set_layouts.len > 0) config.descriptor_set_layouts.ptr else null,
            .pushConstantRangeCount = 0,
            .pPushConstantRanges = null,
        };

        // Add push constants if needed
        var push_constant_range: vk.PushConstantRange = undefined;
        if (config.push_constant_size > 0) {
            push_constant_range = .{
                .stageFlags = vk.SHADER_STAGE_VERTEX | vk.SHADER_STAGE_FRAGMENT,
                .offset = 0,
                .size = config.push_constant_size,
            };
            pipeline_layout_info.pushConstantRangeCount = 1;
            pipeline_layout_info.pPushConstantRanges = &push_constant_range;
        }

        var pipeline_layout: vk.PipelineLayout = undefined;
        const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &pipeline_layout);

        if (layout_result != vk.SUCCESS) {
            std.debug.print("deez", .{});
            return PipelineError.PipelineCreationFailed;
        }

        // Setup shader stages
        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                .stage = vk.SHADER_STAGE_VERTEX,
                .module = vertex_module,
                .pName = "main", // Always use "main" as the entry point for safety
                .pSpecializationInfo = null,
            },
            .{
                .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                .stage = vk.SHADER_STAGE_FRAGMENT,
                .module = fragment_module,
                .pName = "main", // Always use "main" as the entry point for safety
                .pSpecializationInfo = null,
            },
        };

        // Setup dynamic rendering info
        const pipeline_rendering_create_info = vk.PipelineRenderingCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineRenderingCreateInfo),
            .viewMask = 0,
            .colorAttachmentCount = @intCast(config.color_attachment_formats.len),
            .pColorAttachmentFormats = @ptrCast(config.color_attachment_formats.ptr),
            .depthAttachmentFormat = if (config.depth_attachment_format) |fmt| @intCast(@intFromEnum(fmt)) else @intCast(@intFromEnum(vk.Format.Undefined)),
            .stencilAttachmentFormat = if (config.stencil_attachment_format) |fmt| @intCast(@intFromEnum(fmt)) else @intCast(@intFromEnum(vk.Format.Undefined)),
        };

        // Vertex input state
        const vertex_binding_count = if (config.vertex_bindings) |bindings| bindings.len else 0;
        const vertex_attribute_count = if (config.vertex_attributes) |attrs| attrs.len else 0;

        const vertex_input_state = vk.PipelineVertexInputStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineVertexInputStateCreateInfo),
            .vertexBindingDescriptionCount = @intCast(vertex_binding_count),
            .pVertexBindingDescriptions = if (vertex_binding_count > 0) config.vertex_bindings.?.ptr else null,
            .vertexAttributeDescriptionCount = @intCast(vertex_attribute_count),
            .pVertexAttributeDescriptions = if (vertex_attribute_count > 0) config.vertex_attributes.?.ptr else null,
        };

        // Input assembly state
        const input_assembly_state = vk.PipelineInputAssemblyStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineInputAssemblyStateCreateInfo),
            .topology = config.topology,
            .primitiveRestartEnable = vk.FALSE,
        };

        // Viewport state (dynamic or static)
        const viewport_state = vk.PipelineViewportStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineViewportStateCreateInfo),
            .viewportCount = 1,
            .pViewports = null, // Dynamic
            .scissorCount = 1,
            .pScissors = null, // Dynamic
        };

        // Rasterization state
        const rasterization_state = vk.PipelineRasterizationStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineRasterizationStateCreateInfo),
            .depthClampEnable = vk.FALSE,
            .rasterizerDiscardEnable = vk.FALSE,
            .polygonMode = vk.FILL,
            .cullMode = config.cull_mode,
            .frontFace = config.front_face,
            .depthBiasEnable = vk.FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .lineWidth = 1.0,
        };

        // Multisample state
        const multisample_state = vk.PipelineMultisampleStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineMultisampleStateCreateInfo),
            .rasterizationSamples = vk.SAMPLE_COUNT_1,
            .sampleShadingEnable = vk.FALSE,
            .minSampleShading = 1.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = vk.FALSE,
            .alphaToOneEnable = vk.FALSE,
        };

        // Depth stencil state
        const depth_stencil_state = vk.PipelineDepthStencilStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineDepthStencilStateCreateInfo),
            .depthTestEnable = if (config.depth_test_enable) vk.TRUE else vk.FALSE,
            .depthWriteEnable = if (config.depth_write_enable) vk.TRUE else vk.FALSE,
            .depthCompareOp = vk.LESS_OR_EQUAL,
            .depthBoundsTestEnable = vk.FALSE,
            .stencilTestEnable = vk.FALSE,
            .front = .{
                .failOp = vk.KEEP,
                .passOp = vk.KEEP,
                .depthFailOp = vk.KEEP,
                .compareOp = vk.ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .back = .{
                .failOp = vk.KEEP,
                .passOp = vk.KEEP,
                .depthFailOp = vk.KEEP,
                .compareOp = vk.ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
        };

        // We need one attachment state per color attachment
        const color_blend_attachment = vk.PipelineColorBlendAttachmentState{
            .blendEnable = if (config.blend_enable) vk.TRUE else vk.FALSE,
            .srcColorBlendFactor = vk.SRC_ALPHA,
            .dstColorBlendFactor = vk.ONE_MINUS_SRC_ALPHA,
            .colorBlendOp = vk.ADD,
            .srcAlphaBlendFactor = vk.ONE,
            .dstAlphaBlendFactor = vk.ZERO,
            .alphaBlendOp = vk.ADD,
            .colorWriteMask = vk.R |
                vk.G |
                vk.B |
                vk.A,
        };

        // We need one attachment state per color attachment
        const color_blend_attachments = try allocator.alloc(vk.PipelineColorBlendAttachmentState, config.color_attachment_formats.len);
        defer allocator.free(color_blend_attachments);

        for (color_blend_attachments) |*attachment| {
            attachment.* = color_blend_attachment;
        }

        // Color blend state
        const color_blend_state = vk.PipelineColorBlendStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineColorBlendStateCreateInfo),
            .logicOpEnable = vk.FALSE,
            .logicOp = vk.COPY,
            .attachmentCount = @intCast(color_blend_attachments.len),
            .pAttachments = color_blend_attachments.ptr,
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        // Define dynamic states
        var dynamic_states = [_]vk.DynamicState{ vk.VIEWPORT, vk.SCISSOR };
        const dynamic_state = vk.PipelineDynamicStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineDynamicStateCreateInfo),
            .dynamicStateCount = dynamic_states.len,
            .pDynamicStates = &dynamic_states,
        };

        // Create the graphics pipeline
        var pipeline_info = vk.GraphicsPipelineCreateInfo{
            .sType = vk.sTy(vk.StructureType.GraphicsPipelineCreateInfo),
            .pNext = &pipeline_rendering_create_info, // Dynamic rendering
            .stageCount = 2,
            .pStages = &shader_stages,
            .pVertexInputState = &vertex_input_state,
            .pInputAssemblyState = &input_assembly_state,
            .pTessellationState = null,
            .pViewportState = &viewport_state,
            .pRasterizationState = &rasterization_state,
            .pMultisampleState = &multisample_state,
            .pDepthStencilState = &depth_stencil_state,
            .pColorBlendState = &color_blend_state,
            .pDynamicState = &dynamic_state,
            .layout = pipeline_layout,
            .renderPass = null, // Not used with dynamic rendering
            .subpass = 0, // Not used with dynamic rendering
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: vk.Pipeline = undefined;
        const result = vk.createGraphicsPipelines(self.device, null, 1, &pipeline_info, null, &pipeline);

        if (result != vk.SUCCESS) {
            vk.destroyPipelineLayout(self.device, pipeline_layout, null);
            std.debug.print("Pipeline creation failed with error code: {any}", .{result});
            return PipelineError.PipelineCreationFailed;
        }

        // Create the graphics pipeline
        var graphics_pipeline = try allocator.create(GraphicsPipeline);
        graphics_pipeline.* = try GraphicsPipeline.init(name, pipeline, pipeline_layout, config.vertex_shader.path, config.fragment_shader.path, config.color_attachment_formats, config.depth_attachment_format, config);

        // Automatically register the pipeline for hot reloading
        try self.registerPipeline(graphics_pipeline.base.asAny());

        return graphics_pipeline;
    }

    // Get a pipeline by name
    pub fn getPipeline(self: *PipelineCompiler, name: []const u8) !*AnyPipeline {
        return self.pipelines.get(name) orelse return PipelineError.PipelineNotFound;
    }

    // Check for changes in monitored shaders
    pub fn checkForChanges(self: *PipelineCompiler) !bool {
        // Prevent recursive reloading
        if (self.is_reloading) {
            return false;
        }

        var changes_detected = false;

        // We'll only reload one pipeline per call to avoid potential stack issues
        var pipeline_name_to_reload: ?[]const u8 = null;

        for (self.shader_monitors.items) |*monitor| {
            // Use C stat directly to get file info
            var stat_buf: c.struct_stat = undefined;
            var new_mtime: i128 = monitor.last_modified; // Default to current timestamp

            const path = monitor.path;

            if (c.stat(path.ptr, &stat_buf) == 0) {
                // Convert stat time to an i128 timestamp
                new_mtime = @as(i128, stat_buf.st_mtime);
            } else {
                std.debug.print("Warning: Failed to stat monitored shader: {s}, skipping\n", .{monitor.path});
                continue; // Skip this file if we can't stat it
            }

            if (new_mtime > monitor.last_modified) {
                std.debug.print("Detected change in shader: {s}\n", .{monitor.path});
                monitor.last_modified = new_mtime;
                changes_detected = true;

                // We'll remember the first pipeline that needs reloading
                if (pipeline_name_to_reload == null) {
                    pipeline_name_to_reload = monitor.pipeline_name;
                }
            }
        }

        // If a change was detected, reload just that one pipeline
        if (pipeline_name_to_reload != null) {
            // Set the reloading flag to prevent recursion
            self.is_reloading = true;
            defer self.is_reloading = false;

            try self._reloadPipeline(pipeline_name_to_reload.?);
        }

        return changes_detected;
    }

    // Remove a pipeline
    pub fn removePipeline(self: *PipelineCompiler, name: []const u8) void {
        if (self.pipelines.fetchRemove(name)) |entry| {
            var pipeline = entry.value_ptr.*;

            // Clean up based on pipeline type
            switch (pipeline.base.pipeline_type) {
                .Compute => {
                    if (pipeline.asCompute()) |compute| {
                        compute.deinit(allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            allocator.destroy(pipeline);
            allocator.free(entry.key);

            // Remove any shader monitors for this pipeline
            var i: usize = 0;
            while (i < self.shader_monitors.items.len) {
                if (std.mem.eql(u8, self.shader_monitors.items[i].pipeline_name, name)) {
                    allocator.free(self.shader_monitors.items[i].path);
                    allocator.free(self.shader_monitors.items[i].pipeline_name);
                    _ = self.shader_monitors.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    // Reload a specific pipeline
    fn _reloadPipeline(self: *PipelineCompiler, name: []const u8) !void {
        std.debug.print("*** START RELOAD PIPELINE: {s} ***\n", .{name});

        // Get existing pipeline
        const pipeline_entry = self.pipelines.getEntry(name) orelse {
            std.debug.print("Pipeline not found: {s}\n", .{name});
            return;
        };

        var old_pipeline = pipeline_entry.value_ptr.*;

        std.debug.print("Found pipeline: type={s}\n", .{@tagName(old_pipeline.base.pipeline_type)});

        // Recreate the pipeline based on type
        switch (old_pipeline.base.pipeline_type) {
            .Compute => {
                const compute = old_pipeline.asCompute().?;
                std.debug.print("Compute pipeline shader path: {s}\n", .{compute.shader_path});

                // Clean up the old shader module from the cache before recompiling
                self.shader_compiler.removeShader(compute.shader_path);

                // Compile the shader first
                std.debug.print("Compiling shader: {s}\n", .{compute.shader_path});
                const shader_module = try self.shader_compiler.compileShaderFile(compute.shader_path, .Compute);

                // Create pipeline layout using the stored configuration
                std.debug.print("Creating new pipeline layout with push constant size: {d}\n", .{compute.push_constant_size});
                var pipeline_layout_info = vk.PipelineLayoutCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineLayoutCreateInfo),
                    .setLayoutCount = @intCast(compute.descriptor_set_layouts.len),
                    .pSetLayouts = if (compute.descriptor_set_layouts.len > 0) compute.descriptor_set_layouts.ptr else null,
                    .pushConstantRangeCount = 0,
                    .pPushConstantRanges = null,
                };

                // Add push constants if needed
                var push_constant_range: vk.PushConstantRange = undefined;
                if (compute.push_constant_size > 0) {
                    push_constant_range = .{
                        .stageFlags = vk.SHADER_STAGE_COMPUTE,
                        .offset = 0,
                        .size = compute.push_constant_size,
                    };
                    pipeline_layout_info.pushConstantRangeCount = 1;
                    pipeline_layout_info.pPushConstantRanges = &push_constant_range;
                }

                var new_pipeline_layout: vk.PipelineLayout = undefined;
                const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &new_pipeline_layout);

                if (layout_result != vk.SUCCESS) {
                    std.debug.print("Failed to create pipeline layout for reload\n", .{});
                    return PipelineError.PipelineCreationFailed;
                }

                // Create specialization map entries if needed
                var map_entries = std.ArrayList(vk.SpecializationMapEntry).init(allocator);
                defer map_entries.deinit();

                // Add phase specialization
                try map_entries.append(.{
                    .constantID = 0,
                    .offset = 0,
                    .size = @sizeOf(u32),
                });

                // Add local size specialization if provided
                if (compute.local_size != null) {
                    try map_entries.append(.{
                        .constantID = 1,
                        .offset = @sizeOf(u32),
                        .size = @sizeOf(UVec3),
                    });
                }

                // Create specialization data
                var specialization_data = std.ArrayList(u8).init(allocator);
                defer specialization_data.deinit();

                // Add phase data
                try specialization_data.appendSlice(std.mem.asBytes(&compute.phase));

                // Add local size data if provided
                if (compute.local_size) |local_size| {
                    try specialization_data.appendSlice(std.mem.asBytes(&local_size));
                }

                // Create specialization info
                const specialization_info = vk.SpecializationInfo{
                    .mapEntryCount = @intCast(map_entries.items.len),
                    .pMapEntries = map_entries.items.ptr,
                    .dataSize = specialization_data.items.len,
                    .pData = specialization_data.items.ptr,
                };

                // Create a new compute pipeline
                std.debug.print("Creating new compute pipeline\n", .{});
                const pipeline_info = vk.ComputePipelineCreateInfo{
                    .sType = vk.sTy(vk.StructureType.ComputePipelineCreateInfo),
                    .stage = .{
                        .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                        .stage = vk.SHADER_STAGE_COMPUTE,
                        .module = shader_module,
                        .pName = "main", // Always use "main" as the entry point for safety
                        .pSpecializationInfo = &specialization_info,
                    },
                    .layout = new_pipeline_layout,
                    .basePipelineHandle = null,
                    .basePipelineIndex = -1,
                };

                var new_pipeline: vk.Pipeline = undefined;
                const result = vk.createComputePipelines(self.device, null, 1, &pipeline_info, null, &new_pipeline);

                if (result != vk.SUCCESS) {
                    vk.destroyPipelineLayout(self.device, new_pipeline_layout, null);
                    std.debug.print("Failed to create compute pipeline during reload\n", .{});
                    return PipelineError.PipelineCreationFailed;
                }

                // Destroy old pipeline and layout
                std.debug.print("Destroying old pipeline and layout\n", .{});
                vk.destroyPipeline(self.device, compute.base.handle, null);
                vk.destroyPipelineLayout(self.device, compute.base.layout, null);

                // Update the pipeline with new handles
                std.debug.print("Updating pipeline handles\n", .{});
                compute.base.handle = new_pipeline;
                compute.base.layout = new_pipeline_layout;

                std.debug.print("Successfully reloaded compute pipeline: {s}\n", .{name});
            },
            .Graphics => {
                const graphics = old_pipeline.asGraphics().?;
                std.debug.print("Graphics pipeline shader paths: vertex={s}, fragment={s}\n", .{ graphics.vertex_shader_path, graphics.fragment_shader_path });

                // Clean up the old shader modules from the cache before recompiling
                self.shader_compiler.removeShader(graphics.vertex_shader_path);
                self.shader_compiler.removeShader(graphics.fragment_shader_path);

                // Compile the shaders
                std.debug.print("Compiling vertex shader: {s}\n", .{graphics.vertex_shader_path});
                const vertex_module = try self.shader_compiler.compileShaderFile(graphics.vertex_shader_path, .Vertex);

                std.debug.print("Compiling fragment shader: {s}\n", .{graphics.fragment_shader_path});
                const fragment_module = try self.shader_compiler.compileShaderFile(graphics.fragment_shader_path, .Fragment);

                // Create a new pipeline layout using stored configuration
                std.debug.print("Creating new pipeline layout with push constant size: {d}\n", .{graphics.push_constant_size});
                var pipeline_layout_info = vk.PipelineLayoutCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineLayoutCreateInfo),
                    .setLayoutCount = @intCast(graphics.descriptor_set_layouts.len),
                    .pSetLayouts = if (graphics.descriptor_set_layouts.len > 0) graphics.descriptor_set_layouts.ptr else null,
                    .pushConstantRangeCount = 0,
                    .pPushConstantRanges = null,
                };

                // Add push constants if needed
                var push_constant_range: vk.PushConstantRange = undefined;
                if (graphics.push_constant_size > 0) {
                    push_constant_range = .{
                        .stageFlags = vk.SHADER_STAGE_VERTEX | vk.SHADER_STAGE_FRAGMENT,
                        .offset = 0,
                        .size = graphics.push_constant_size,
                    };
                    pipeline_layout_info.pushConstantRangeCount = 1;
                    pipeline_layout_info.pPushConstantRanges = &push_constant_range;
                }

                var new_pipeline_layout: vk.PipelineLayout = undefined;
                const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &new_pipeline_layout);

                if (layout_result != vk.SUCCESS) {
                    std.debug.print("Failed to create graphics pipeline layout for reload\n", .{});
                    return PipelineError.PipelineCreationFailed;
                }

                // Setup shader stages
                const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
                    .{
                        .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                        .stage = vk.SHADER_STAGE_VERTEX,
                        .module = vertex_module,
                        .pName = "main", // Always use "main" as the entry point for safety
                        .pSpecializationInfo = null,
                    },
                    .{
                        .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                        .stage = vk.SHADER_STAGE_FRAGMENT,
                        .module = fragment_module,
                        .pName = "main", // Always use "main" as the entry point for safety
                        .pSpecializationInfo = null,
                    },
                };

                // Setup dynamic rendering info
                const pipeline_rendering_create_info = vk.PipelineRenderingCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineRenderingCreateInfo),
                    .viewMask = 0,
                    .colorAttachmentCount = @intCast(graphics.color_formats.len),
                    .pColorAttachmentFormats = @ptrCast(graphics.color_formats.ptr),
                    .depthAttachmentFormat = if (graphics.depth_format) |fmt| @intCast(@intFromEnum(fmt)) else @intCast(@intFromEnum(vk.Format.Undefined)),
                    .stencilAttachmentFormat = if (graphics.stencil_format) |fmt| @intCast(@intFromEnum(fmt)) else @intCast(@intFromEnum(vk.Format.Undefined)),
                };

                // Vertex input state using stored configuration
                const vertex_binding_count = if (graphics.vertex_bindings) |bindings| bindings.len else 0;
                const vertex_attribute_count = if (graphics.vertex_attributes) |attrs| attrs.len else 0;

                const vertex_input_state = vk.PipelineVertexInputStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineVertexInputStateCreateInfo),
                    .vertexBindingDescriptionCount = @intCast(vertex_binding_count),
                    .pVertexBindingDescriptions = if (vertex_binding_count > 0) graphics.vertex_bindings.?.ptr else null,
                    .vertexAttributeDescriptionCount = @intCast(vertex_attribute_count),
                    .pVertexAttributeDescriptions = if (vertex_attribute_count > 0) graphics.vertex_attributes.?.ptr else null,
                };

                // Input assembly state
                const input_assembly_state = vk.PipelineInputAssemblyStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineInputAssemblyStateCreateInfo),
                    .topology = graphics.topology,
                    .primitiveRestartEnable = vk.FALSE,
                };

                // Viewport state (dynamic)
                const viewport_state = vk.PipelineViewportStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineViewportStateCreateInfo),
                    .viewportCount = 1,
                    .pViewports = null, // Dynamic
                    .scissorCount = 1,
                    .pScissors = null, // Dynamic
                };

                // Rasterization state
                const rasterization_state = vk.PipelineRasterizationStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineRasterizationStateCreateInfo),
                    .depthClampEnable = vk.FALSE,
                    .rasterizerDiscardEnable = vk.FALSE,
                    .polygonMode = vk.FILL,
                    .cullMode = graphics.cull_mode,
                    .frontFace = graphics.front_face,
                    .depthBiasEnable = vk.FALSE,
                    .depthBiasConstantFactor = 0.0,
                    .depthBiasClamp = 0.0,
                    .depthBiasSlopeFactor = 0.0,
                    .lineWidth = 1.0,
                };

                // Multisample state
                const multisample_state = vk.PipelineMultisampleStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineMultisampleStateCreateInfo),
                    .rasterizationSamples = vk.SAMPLE_COUNT_1,
                    .sampleShadingEnable = vk.FALSE,
                    .minSampleShading = 1.0,
                    .pSampleMask = null,
                    .alphaToCoverageEnable = vk.FALSE,
                    .alphaToOneEnable = vk.FALSE,
                };

                // Depth stencil state
                const depth_stencil_state = vk.PipelineDepthStencilStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineDepthStencilStateCreateInfo),
                    .depthTestEnable = if (graphics.depth_test_enable) vk.TRUE else vk.FALSE,
                    .depthWriteEnable = if (graphics.depth_write_enable) vk.TRUE else vk.FALSE,
                    .depthCompareOp = vk.LESS_OR_EQUAL,
                    .depthBoundsTestEnable = vk.FALSE,
                    .stencilTestEnable = vk.FALSE,
                    .front = .{
                        .failOp = vk.KEEP,
                        .passOp = vk.KEEP,
                        .depthFailOp = vk.KEEP,
                        .compareOp = vk.ALWAYS,
                        .compareMask = 0,
                        .writeMask = 0,
                        .reference = 0,
                    },
                    .back = .{
                        .failOp = vk.KEEP,
                        .passOp = vk.KEEP,
                        .depthFailOp = vk.KEEP,
                        .compareOp = vk.ALWAYS,
                        .compareMask = 0,
                        .writeMask = 0,
                        .reference = 0,
                    },
                    .minDepthBounds = 0.0,
                    .maxDepthBounds = 1.0,
                };

                // We need one attachment state per color attachment
                const color_blend_attachment = vk.PipelineColorBlendAttachmentState{
                    .blendEnable = if (graphics.blend_enable) vk.TRUE else vk.FALSE,
                    .srcColorBlendFactor = vk.SRC_ALPHA,
                    .dstColorBlendFactor = vk.ONE_MINUS_SRC_ALPHA,
                    .colorBlendOp = vk.ADD,
                    .srcAlphaBlendFactor = vk.ONE,
                    .dstAlphaBlendFactor = vk.ZERO,
                    .alphaBlendOp = vk.ADD,
                    .colorWriteMask = vk.R | vk.G | vk.B | vk.A,
                };

                // Create color attachment states for each format
                const color_blend_attachments = try allocator.alloc(vk.PipelineColorBlendAttachmentState, graphics.color_formats.len);
                defer allocator.free(color_blend_attachments);

                for (color_blend_attachments) |*attachment| {
                    attachment.* = color_blend_attachment;
                }

                // Color blend state
                const color_blend_state = vk.PipelineColorBlendStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineColorBlendStateCreateInfo),
                    .logicOpEnable = vk.FALSE,
                    .logicOp = vk.COPY,
                    .attachmentCount = @intCast(color_blend_attachments.len),
                    .pAttachments = color_blend_attachments.ptr,
                    .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
                };

                // Define dynamic states
                var dynamic_states = [_]vk.DynamicState{ vk.VIEWPORT, vk.SCISSOR };
                const dynamic_state = vk.PipelineDynamicStateCreateInfo{
                    .sType = vk.sTy(vk.StructureType.PipelineDynamicStateCreateInfo),
                    .dynamicStateCount = dynamic_states.len,
                    .pDynamicStates = &dynamic_states,
                };

                // Create the graphics pipeline
                var pipeline_info = vk.GraphicsPipelineCreateInfo{
                    .sType = vk.sTy(vk.StructureType.GraphicsPipelineCreateInfo),
                    .pNext = &pipeline_rendering_create_info, // Dynamic rendering
                    .stageCount = 2,
                    .pStages = &shader_stages,
                    .pVertexInputState = &vertex_input_state,
                    .pInputAssemblyState = &input_assembly_state,
                    .pTessellationState = null,
                    .pViewportState = &viewport_state,
                    .pRasterizationState = &rasterization_state,
                    .pMultisampleState = &multisample_state,
                    .pDepthStencilState = &depth_stencil_state,
                    .pColorBlendState = &color_blend_state,
                    .pDynamicState = &dynamic_state,
                    .layout = new_pipeline_layout,
                    .renderPass = null, // Not used with dynamic rendering
                    .subpass = 0, // Not used with dynamic rendering
                    .basePipelineHandle = null,
                    .basePipelineIndex = -1,
                };

                var new_pipeline: vk.Pipeline = undefined;
                const result = vk.createGraphicsPipelines(self.device, null, 1, &pipeline_info, null, &new_pipeline);

                if (result != vk.SUCCESS) {
                    vk.destroyPipelineLayout(self.device, new_pipeline_layout, null);
                    std.debug.print("Failed to create graphics pipeline during reload: {any}\n", .{result});
                    return PipelineError.PipelineCreationFailed;
                }

                // Destroy the old pipeline and layout
                std.debug.print("Destroying old pipeline and layout\n", .{});
                vk.destroyPipeline(self.device, graphics.base.handle, null);
                vk.destroyPipelineLayout(self.device, graphics.base.layout, null);

                // Update the pipeline with new handles
                std.debug.print("Updating pipeline handles\n", .{});
                graphics.base.handle = new_pipeline;
                graphics.base.layout = new_pipeline_layout;

                std.debug.print("Successfully reloaded graphics pipeline: {s}\n", .{name});
            },
        }
    }

    // Clear all pipelines
    pub fn clearPipelines(self: *PipelineCompiler) void {
        var it = self.pipelines.iterator();
        while (it.next()) |entry| {
            var pipeline = entry.value_ptr.*;

            // Clean up based on pipeline type
            switch (pipeline.base.pipeline_type) {
                .Compute => {
                    if (pipeline.asCompute()) |compute| {
                        compute.deinit(allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            allocator.destroy(pipeline);
            allocator.free(entry.key_ptr.*);
        }
        self.pipelines.clearAndFree();

        // Clear shader monitors
        for (self.shader_monitors.items) |monitor| {
            allocator.free(monitor.path);
            allocator.free(monitor.pipeline_name);
        }
        self.shader_monitors.clearRetainingCapacity();
    }
};
