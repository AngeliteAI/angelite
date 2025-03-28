const std = @import("std");
const vk = @import("vk.zig");
const compiler = @import("compiler.zig");
const fs = std.fs;
const Allocator = std.mem.Allocator;

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

    pub fn init(name: []const u8, handle: vk.Pipeline, layout: vk.PipelineLayout, shader_path: []const u8) ComputePipeline {
        return .{
            .base = .{
                .name = name,
                .handle = handle,
                .layout = layout,
                .pipeline_type = .Compute,
            },
            .shader_path = shader_path,
        };
    }

    pub fn deinit(self: *ComputePipeline, allocator: Allocator) void {
        allocator.free(self.shader_path);
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

    pub fn init(
        name: []const u8,
        handle: vk.Pipeline,
        layout: vk.PipelineLayout,
        vertex_path: []const u8,
        fragment_path: []const u8,
        color_formats: []const vk.Format,
        depth_format: ?vk.Format,
        allocator: Allocator,
    ) !GraphicsPipeline {
        return .{
            .base = .{
                .name = name,
                .handle = handle,
                .layout = layout,
                .pipeline_type = .Graphics,
            },
            .vertex_shader_path = try allocator.dupe(u8, vertex_path),
            .fragment_shader_path = try allocator.dupe(u8, fragment_path),
            .color_formats = try allocator.dupe(vk.Format, color_formats),
            .depth_format = depth_format,
        };
    }

    pub fn deinit(self: *GraphicsPipeline, allocator: Allocator) void {
        allocator.free(self.vertex_shader_path);
        allocator.free(self.fragment_shader_path);
        allocator.free(self.color_formats);
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
    topology: vk.PrimitiveTopology = .TRIANGLE_LIST,
    cull_mode: vk.CullModeFlags = vk.CULL_MODE_BACK_BIT,
    front_face: vk.FrontFace = .CLOCKWISE,
    blend_enable: bool = false,
    depth_test_enable: bool = true,
    depth_write_enable: bool = true,
    viewport_scissor_dynamic: bool = true,
};

pub const PipelineCompiler = struct {
    device: vk.Device,
    allocator: Allocator,
    pipelines: std.StringHashMap(*AnyPipeline),
    shader_monitors: std.ArrayList(ShaderMonitor),
    shader_compiler: compiler.ShaderCompiler,

    pub fn init(allocator: Allocator, device: vk.Device) !*PipelineCompiler {
        var self = try allocator.create(PipelineCompiler);
        self.* = .{
            .device = device,
            .allocator = allocator,
            .pipelines = std.StringHashMap(*AnyPipeline).init(allocator),
            .shader_monitors = std.ArrayList(ShaderMonitor).init(allocator),
            .shader_compiler = try compiler.ShaderCompiler.init(allocator),
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
                        compute.deinit(self.allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(self.allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            self.allocator.destroy(pipeline);
            self.allocator.free(entry.key_ptr.*);
        }
        self.pipelines.deinit();

        // Clean up shader monitors
        for (self.shader_monitors.items) |monitor| {
            self.allocator.free(monitor.path);
            self.allocator.free(monitor.pipeline_name);
        }
        self.shader_monitors.deinit();

        // Clean up shader compiler
        self.shader_compiler.deinit();

        // Free self
        self.allocator.destroy(self);
    }

    // Private function to register a pipeline for hot reloading
    fn registerPipeline(self: *PipelineCompiler, pipeline: *AnyPipeline) !void {
        const name_copy = try self.allocator.dupe(u8, pipeline.base.name);
        errdefer self.allocator.free(name_copy);

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
        const stat = try fs.cwd().statFile(path);

        try self.shader_monitors.append(.{
            .path = try self.allocator.dupe(u8, path),
            .last_modified = stat.mtime,
            .pipeline_name = try self.allocator.dupe(u8, pipeline_name),
        });
    }

    // Create a compute pipeline
    pub fn createComputePipeline(
        self: *PipelineCompiler,
        name: []const u8,
        config: ComputePipelineConfig,
    ) !*ComputePipeline {
        // Compile or get cached compute shader
        const shader_module = try self.shader_compiler.getOrCompileShader(config.shader.path, config.shader.shader_type);

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
                .stageFlags = vk.SHADER_STAGE_COMPUTE_BIT,
                .offset = 0,
                .size = config.push_constant_size,
            };
            pipeline_layout_info.pushConstantRangeCount = 1;
            pipeline_layout_info.pPushConstantRanges = &push_constant_range;
        }

        var pipeline_layout: vk.PipelineLayout = undefined;
        const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &pipeline_layout);

        if (layout_result != vk.SUCCESS) {
            return PipelineError.PipelineCreationFailed;
        }

        // Create compute pipeline
        const shader_stage = vk.PipelineShaderStageCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
            .stage = vk.SHADER_STAGE_COMPUTE_BIT,
            .module = shader_module,
            .pName = config.shader.entry_point.ptr,
            .pSpecializationInfo = config.specialization_info,
        };

        const compute_create_info = vk.ComputePipelineCreateInfo{
            .sType = vk.sTy(vk.StructureType.ComputePipelineCreateInfo),
            .stage = shader_stage,
            .layout = pipeline_layout,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        var pipeline: vk.Pipeline = undefined;
        const result = vk.createComputePipelines(self.device, null, 1, &compute_create_info, null, &pipeline);

        if (result != vk.SUCCESS) {
            vk.destroyPipelineLayout(self.device, pipeline_layout, null);
            return PipelineError.PipelineCreationFailed;
        }

        // Create the pipeline object
        var compute_pipeline = try self.allocator.create(ComputePipeline);
        compute_pipeline.* = ComputePipeline.init(name, pipeline, pipeline_layout, try self.allocator.dupe(u8, config.shader.path));

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
        // Compile or get cached shaders
        const vertex_module = try self.shader_compiler.getOrCompileShader(config.vertex_shader.path, config.vertex_shader.shader_type);

        const fragment_module = try self.shader_compiler.getOrCompileShader(config.fragment_shader.path, config.fragment_shader.shader_type);

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
                .stageFlags = vk.SHADER_STAGE_VERTEX_BIT | vk.SHADER_STAGE_FRAGMENT_BIT,
                .offset = 0,
                .size = config.push_constant_size,
            };
            pipeline_layout_info.pushConstantRangeCount = 1;
            pipeline_layout_info.pPushConstantRanges = &push_constant_range;
        }

        var pipeline_layout: vk.PipelineLayout = undefined;
        const layout_result = vk.createPipelineLayout(self.device, &pipeline_layout_info, null, &pipeline_layout);

        if (layout_result != vk.SUCCESS) {
            return PipelineError.PipelineCreationFailed;
        }

        // Setup shader stages
        const shader_stages = [_]vk.PipelineShaderStageCreateInfo{
            .{
                .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                .stage = vk.SHADER_STAGE_VERTEX_BIT,
                .module = vertex_module,
                .pName = config.vertex_shader.entry_point.ptr,
                .pSpecializationInfo = null,
            },
            .{
                .sType = vk.sTy(vk.StructureType.PipelineShaderStageCreateInfo),
                .stage = vk.SHADER_STAGE_FRAGMENT_BIT,
                .module = fragment_module,
                .pName = config.fragment_shader.entry_point.ptr,
                .pSpecializationInfo = null,
            },
        };

        // Setup dynamic rendering info
        const pipeline_rendering_create_info = vk.PipelineRenderingCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineRenderingCreateInfo),
            .viewMask = 0,
            .colorAttachmentCount = @intCast(config.color_attachment_formats.len),
            .pColorAttachmentFormats = config.color_attachment_formats.ptr,
            .depthAttachmentFormat = if (config.depth_attachment_format) |fmt| fmt else .UNDEFINED,
            .stencilAttachmentFormat = if (config.stencil_attachment_format) |fmt| fmt else .UNDEFINED,
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
            .polygonMode = .FILL,
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
            .rasterizationSamples = .@"1_BIT",
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
            .depthCompareOp = .LESS_OR_EQUAL,
            .depthBoundsTestEnable = vk.FALSE,
            .stencilTestEnable = vk.FALSE,
            .front = .{
                .failOp = .KEEP,
                .passOp = .KEEP,
                .depthFailOp = .KEEP,
                .compareOp = .ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .back = .{
                .failOp = .KEEP,
                .passOp = .KEEP,
                .depthFailOp = .KEEP,
                .compareOp = .ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
        };

        // Color blend attachment
        const color_blend_attachment = vk.PipelineColorBlendAttachmentState{
            .blendEnable = if (config.blend_enable) vk.TRUE else vk.FALSE,
            .srcColorBlendFactor = .SRC_ALPHA,
            .dstColorBlendFactor = .ONE_MINUS_SRC_ALPHA,
            .colorBlendOp = .ADD,
            .srcAlphaBlendFactor = .ONE,
            .dstAlphaBlendFactor = .ZERO,
            .alphaBlendOp = .ADD,
            .colorWriteMask = vk.COLOR_COMPONENT_R_BIT |
                vk.COLOR_COMPONENT_G_BIT |
                vk.COLOR_COMPONENT_B_BIT |
                vk.COLOR_COMPONENT_A_BIT,
        };

        // We need one attachment state per color attachment
        const color_blend_attachments = try self.allocator.alloc(vk.PipelineColorBlendAttachmentState, config.color_attachment_formats.len);
        defer self.allocator.free(color_blend_attachments);

        for (color_blend_attachments) |*attachment| {
            attachment.* = color_blend_attachment;
        }

        // Color blend state
        const color_blend_state = vk.PipelineColorBlendStateCreateInfo{
            .sType = vk.sTy(vk.StructureType.PipelineColorBlendStateCreateInfo),
            .logicOpEnable = vk.FALSE,
            .logicOp = .COPY,
            .attachmentCount = @intCast(color_blend_attachments.len),
            .pAttachments = color_blend_attachments.ptr,
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        // Define dynamic states
        var dynamic_states = [_]vk.DynamicState{ .VIEWPORT, .SCISSOR };
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
            return PipelineError.PipelineCreationFailed;
        }

        // Create the graphics pipeline
        var graphics_pipeline = try self.allocator.create(GraphicsPipeline);
        graphics_pipeline.* = try GraphicsPipeline.init(name, pipeline, pipeline_layout, config.vertex_shader.path, config.fragment_shader.path, config.color_attachment_formats, config.depth_attachment_format, self.allocator);

        // Automatically register the pipeline for hot reloading
        try self._registerPipeline(graphics_pipeline.base.asAny());

        return graphics_pipeline;
    }

    // Get a pipeline by name
    pub fn getPipeline(self: *PipelineCompiler, name: []const u8) !*AnyPipeline {
        return self.pipelines.get(name) orelse return PipelineError.PipelineNotFound;
    }

    // Check for changes in monitored shaders
    pub fn checkForChanges(self: *PipelineCompiler) !bool {
        var changes_detected = false;
        var pipelines_to_reload = std.StringHashMap(void).init(self.allocator);
        defer pipelines_to_reload.deinit();

        for (self.shader_monitors.items) |*monitor| {
            const stat = fs.cwd().statFile(monitor.path) catch continue;

            if (stat.mtime > monitor.last_modified) {
                std.debug.print("Detected change in shader: {s}\n", .{monitor.path});
                monitor.last_modified = stat.mtime;
                changes_detected = true;

                // Mark this pipeline for reload
                try pipelines_to_reload.put(monitor.pipeline_name, {});
            }
        }

        // If changes were detected, reload affected pipelines
        if (changes_detected) {
            var it = pipelines_to_reload.keyIterator();
            while (it.next()) |pipeline_name| {
                try self._reloadPipeline(pipeline_name.*);
            }
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
                        compute.deinit(self.allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(self.allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            self.allocator.destroy(pipeline);
            self.allocator.free(entry.key);

            // Remove any shader monitors for this pipeline
            var i: usize = 0;
            while (i < self.shader_monitors.items.len) {
                if (std.mem.eql(u8, self.shader_monitors.items[i].pipeline_name, name)) {
                    self.allocator.free(self.shader_monitors.items[i].path);
                    self.allocator.free(self.shader_monitors.items[i].pipeline_name);
                    _ = self.shader_monitors.orderedRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    // Reload a specific pipeline
    fn _reloadPipeline(self: *PipelineCompiler, name: []const u8) !void {
        std.debug.print("Reloading pipeline: {s}\n", .{name});

        // Get existing pipeline
        const pipeline_entry = self.pipelines.getEntry(name) orelse {
            std.debug.print("Pipeline not found: {s}\n", .{name});
            return;
        };

        var pipeline = pipeline_entry.value_ptr.*;

        // Recreate the pipeline based on type
        switch (pipeline.base.pipeline_type) {
            .Compute => {
                const compute = pipeline.asCompute().?;

                // For now, just reload the shader and report success
                // In a real implementation, store pipeline configuration and completely recreate
                _ = try self.shader_compiler.getOrCompileShader(compute.shader_path, .Compute);
                std.debug.print("Compute shader reloaded for {s}\n", .{name});
            },
            .Graphics => {
                const graphics = pipeline.asGraphics().?;

                // Reload vertex and fragment shaders
                _ = try self.shader_compiler.getOrCompileShader(graphics.vertex_shader_path, .Vertex);
                _ = try self.shader_compiler.getOrCompileShader(graphics.fragment_shader_path, .Fragment);
                std.debug.print("Graphics shaders reloaded for {s}\n", .{name});
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
                        compute.deinit(self.allocator);
                    }
                },
                .Graphics => {
                    if (pipeline.asGraphics()) |graphics| {
                        graphics.deinit(self.allocator);
                    }
                },
            }

            pipeline.base.deinit(self.device);
            self.allocator.destroy(pipeline);
            self.allocator.free(entry.key_ptr.*);
        }
        self.pipelines.clearAndFree();

        // Clear shader monitors
        for (self.shader_monitors.items) |monitor| {
            self.allocator.free(monitor.path);
            self.allocator.free(monitor.pipeline_name);
        }
        self.shader_monitors.clearRetainingCapacity();
    }
};
