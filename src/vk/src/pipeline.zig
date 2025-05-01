const std = @import("std");
const raw = @import("raw.zig");
const errors = @import("errors.zig");

/// Pipeline layout abstraction with utility functions
pub const PipelineLayout = struct {
    handle: raw.PipelineLayout,
    device: raw.Device,

    /// Configuration options for creating a pipeline layout
    pub const CreateInfo = struct {
        push_constant_ranges: []const raw.PushConstantRange = &[_]raw.PushConstantRange{},
        set_layouts: []const raw.DescriptorSetLayout = &[_]raw.DescriptorSetLayout{},
    };

    /// Create a new pipeline layout with the given configuration
    pub fn create(device: raw.Device, create_info: CreateInfo) errors.Error!PipelineLayout {
        const layout_info = raw.PipelineLayoutCreateInfo{
            .sType = raw.sTy(.PipelineLayoutCreateInfo),
            .pNext = null,
            .flags = 0,
            .setLayoutCount = @intCast(create_info.set_layouts.len),
            .pSetLayouts = if (create_info.set_layouts.len > 0) create_info.set_layouts.ptr else null,
            .pushConstantRangeCount = @intCast(create_info.push_constant_ranges.len),
            .pPushConstantRanges = if (create_info.push_constant_ranges.len > 0) create_info.push_constant_ranges.ptr else null,
        };

        var handle: raw.PipelineLayout = undefined;
        const result = raw.createPipelineLayout(device, &layout_info, null, &handle);
        try errors.checkResult(result);

        return PipelineLayout{
            .handle = handle,
            .device = device,
        };
    }

    /// Destroy the pipeline layout
    pub fn destroy(self: *PipelineLayout) void {
        raw.destroyPipelineLayout(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Get the raw pipeline layout handle
    pub fn getHandle(self: PipelineLayout) raw.PipelineLayout {
        return self.handle;
    }
};

/// Shader module abstraction
pub const ShaderModule = struct {
    handle: raw.ShaderModule,
    device: raw.Device,

    /// Create a new shader module from SPIR-V code
    pub fn create(device: raw.Device, code: []const u8) errors.Error!ShaderModule {
        const create_info = raw.ShaderModuleCreateInfo{
            .sType = raw.sTy(.ShaderModuleCreateInfo),
            .pNext = null,
            .flags = 0,
            .codeSize = code.len,
            .pCode = @ptrCast(code.ptr),
        };

        var handle: raw.ShaderModule = undefined;
        const result = raw.createShaderModule(device, &create_info, null, &handle);
        try errors.checkResult(result);

        return ShaderModule{
            .handle = handle,
            .device = device,
        };
    }

    /// Destroy the shader module
    pub fn destroy(self: *ShaderModule) void {
        raw.destroyShaderModule(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Get the raw shader module handle
    pub fn getHandle(self: ShaderModule) raw.ShaderModule {
        return self.handle;
    }
};

/// Graphics pipeline abstraction with utility functions
pub const GraphicsPipeline = struct {
    handle: raw.Pipeline,
    device: raw.Device,
    layout: raw.PipelineLayout,

    /// Configuration options for creating a graphics pipeline with dynamic rendering
    pub const CreateInfo = struct {
        vertex_shader: ShaderModule,
        fragment_shader: ?ShaderModule = null,
        layout: PipelineLayout,
        color_formats: []const raw.Format = &[_]raw.Format{},
        depth_format: ?raw.Format = null,
        vertex_binding_descriptions: []const raw.VertexInputBindingDescription = &[_]raw.VertexInputBindingDescription{},
        vertex_attribute_descriptions: []const raw.VertexInputAttributeDescription = &[_]raw.VertexInputAttributeDescription{},
        topology: raw.PrimitiveTopology = raw.TRIANGLE_LIST,
        cull_mode: raw.CullModeFlags = raw.CULL_MODE_BACK,
        front_face: raw.FrontFace = raw.CLOCKWISE,
        sample_count: u32 = raw.SAMPLE_COUNT_1_BIT,
        blend_enabled: bool = true,
        depth_test_enabled: bool = false,
        depth_write_enabled: bool = false,
    };

    /// Create a new graphics pipeline with the given configuration
    pub fn create(device: raw.Device, create_info: CreateInfo) errors.Error!GraphicsPipeline {
        // Create shader stages
        var stages: [2]raw.PipelineShaderStageCreateInfo = undefined;
        var stage_count: u32 = 1;

        // Vertex shader stage
        stages[0] = raw.PipelineShaderStageCreateInfo{
            .sType = raw.sTy(.PipelineShaderStageCreateInfo),
            .pNext = null,
            .flags = 0,
            .stage = raw.SHADER_STAGE_VERTEX_BIT,
            .module = create_info.vertex_shader.handle,
            .pName = "main",
            .pSpecializationInfo = null,
        };

        // Fragment shader stage (if provided)
        if (create_info.fragment_shader) |fragment_shader| {
            stages[1] = raw.PipelineShaderStageCreateInfo{
                .sType = raw.sTy(.PipelineShaderStageCreateInfo),
                .pNext = null,
                .flags = 0,
                .stage = raw.SHADER_STAGE_FRAGMENT_BIT,
                .module = fragment_shader.handle,
                .pName = "main",
                .pSpecializationInfo = null,
            };
            stage_count = 2;
        }

        // Vertex input state
        const vertex_input_state = raw.PipelineVertexInputStateCreateInfo{
            .sType = raw.sTy(.PipelineVertexInputStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .vertexBindingDescriptionCount = @intCast(create_info.vertex_binding_descriptions.len),
            .pVertexBindingDescriptions = if (create_info.vertex_binding_descriptions.len > 0) create_info.vertex_binding_descriptions.ptr else null,
            .vertexAttributeDescriptionCount = @intCast(create_info.vertex_attribute_descriptions.len),
            .pVertexAttributeDescriptions = if (create_info.vertex_attribute_descriptions.len > 0) create_info.vertex_attribute_descriptions.ptr else null,
        };

        // Input assembly state
        const input_assembly_state = raw.PipelineInputAssemblyStateCreateInfo{
            .sType = raw.sTy(.PipelineInputAssemblyStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .topology = create_info.topology,
            .primitiveRestartEnable = raw.FALSE,
        };

        // Viewport state - will be dynamic
        const viewport_state = raw.PipelineViewportStateCreateInfo{
            .sType = raw.sTy(.PipelineViewportStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .viewportCount = 1,
            .pViewports = null, // Dynamic
            .scissorCount = 1,
            .pScissors = null, // Dynamic
        };

        // Rasterization state
        const rasterization_state = raw.PipelineRasterizationStateCreateInfo{
            .sType = raw.sTy(.PipelineRasterizationStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .depthClampEnable = raw.FALSE,
            .rasterizerDiscardEnable = raw.FALSE,
            .polygonMode = raw.FILL,
            .cullMode = create_info.cull_mode,
            .frontFace = create_info.front_face,
            .depthBiasEnable = raw.FALSE,
            .depthBiasConstantFactor = 0.0,
            .depthBiasClamp = 0.0,
            .depthBiasSlopeFactor = 0.0,
            .lineWidth = 1.0,
        };

        // Multisample state
        const multisample_state = raw.PipelineMultisampleStateCreateInfo{
            .sType = raw.sTy(.PipelineMultisampleStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .rasterizationSamples = create_info.sample_count,
            .sampleShadingEnable = raw.FALSE,
            .minSampleShading = 1.0,
            .pSampleMask = null,
            .alphaToCoverageEnable = raw.FALSE,
            .alphaToOneEnable = raw.FALSE,
        };

        // Depth stencil state
        const depth_stencil_state = raw.PipelineDepthStencilStateCreateInfo{
            .sType = raw.sTy(.PipelineDepthStencilStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .depthTestEnable = if (create_info.depth_test_enabled) raw.TRUE else raw.FALSE,
            .depthWriteEnable = if (create_info.depth_write_enabled) raw.TRUE else raw.FALSE,
            .depthCompareOp = raw.LESS_OR_EQUAL,
            .depthBoundsTestEnable = raw.FALSE,
            .stencilTestEnable = raw.FALSE,
            .front = .{
                .failOp = raw.KEEP,
                .passOp = raw.KEEP,
                .depthFailOp = raw.KEEP,
                .compareOp = raw.ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .back = .{
                .failOp = raw.KEEP,
                .passOp = raw.KEEP,
                .depthFailOp = raw.KEEP,
                .compareOp = raw.ALWAYS,
                .compareMask = 0,
                .writeMask = 0,
                .reference = 0,
            },
            .minDepthBounds = 0.0,
            .maxDepthBounds = 1.0,
        };

        // Color blend attachment state
        const color_blend_attachment = raw.PipelineColorBlendAttachmentState{
            .blendEnable = if (create_info.blend_enabled) raw.TRUE else raw.FALSE,
            .srcColorBlendFactor = raw.SRC_ALPHA,
            .dstColorBlendFactor = raw.ONE_MINUS_SRC_ALPHA,
            .colorBlendOp = raw.ADD,
            .srcAlphaBlendFactor = raw.ONE,
            .dstAlphaBlendFactor = raw.ZERO,
            .alphaBlendOp = raw.ADD,
            .colorWriteMask = raw.R | raw.G | raw.B | raw.A,
        };

        // Color blend state
        const color_blend_state = raw.PipelineColorBlendStateCreateInfo{
            .sType = raw.sTy(.PipelineColorBlendStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .logicOpEnable = raw.FALSE,
            .logicOp = raw.COPY,
            .attachmentCount = 1,
            .pAttachments = &color_blend_attachment,
            .blendConstants = [_]f32{ 0.0, 0.0, 0.0, 0.0 },
        };

        // Dynamic state
        const dynamic_states = [_]raw.DynamicState{ raw.VIEWPORT, raw.SCISSOR };
        const dynamic_state = raw.PipelineDynamicStateCreateInfo{
            .sType = raw.sTy(.PipelineDynamicStateCreateInfo),
            .pNext = null,
            .flags = 0,
            .dynamicStateCount = dynamic_states.len,
            .pDynamicStates = &dynamic_states,
        };

        // Pipeline rendering info for dynamic rendering
        var rendering_info = raw.PipelineRenderingCreateInfo{
            .sType = raw.sTy(.PipelineRenderingCreateInfo),
            .pNext = null,
            .viewMask = 0,
            .colorAttachmentCount = @intCast(create_info.color_formats.len),
            .pColorAttachmentFormats = if (create_info.color_formats.len > 0) @as([*]const c_int, @ptrCast(create_info.color_formats.ptr)) else null,
            .depthAttachmentFormat = if (create_info.depth_format) |format| @intFromEnum(format) else 0,
            .stencilAttachmentFormat = 0,
        };

        // Graphics pipeline create info
        const pipeline_info = raw.GraphicsPipelineCreateInfo{
            .sType = raw.sTy(.GraphicsPipelineCreateInfo),
            .pNext = &rendering_info,
            .flags = 0,
            .stageCount = stage_count,
            .pStages = &stages,
            .pVertexInputState = &vertex_input_state,
            .pInputAssemblyState = &input_assembly_state,
            .pTessellationState = null,
            .pViewportState = &viewport_state,
            .pRasterizationState = &rasterization_state,
            .pMultisampleState = &multisample_state,
            .pDepthStencilState = &depth_stencil_state,
            .pColorBlendState = &color_blend_state,
            .pDynamicState = &dynamic_state,
            .layout = create_info.layout.handle,
            .renderPass = null, // Using dynamic rendering, so no render pass
            .subpass = 0,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        // Create the pipeline
        var handle: raw.Pipeline = undefined;
        const result = raw.createGraphicsPipelines(device, null, // No pipeline cache
            1, &pipeline_info, null, &handle);
        try errors.checkResult(result);

        return GraphicsPipeline{
            .handle = handle,
            .device = device,
            .layout = create_info.layout.handle,
        };
    }

    /// Destroy the graphics pipeline
    pub fn destroy(self: *GraphicsPipeline) void {
        raw.destroyPipeline(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Get the raw pipeline handle
    pub fn getHandle(self: GraphicsPipeline) raw.Pipeline {
        return self.handle;
    }

    /// Get the pipeline layout
    pub fn getLayout(self: GraphicsPipeline) raw.PipelineLayout {
        return self.layout;
    }
};

/// Compute pipeline abstraction with utility functions
pub const ComputePipeline = struct {
    handle: raw.Pipeline,
    device: raw.Device,
    layout: raw.PipelineLayout,

    /// Configuration options for creating a compute pipeline
    pub const CreateInfo = struct {
        shader: ShaderModule,
        layout: PipelineLayout,
        specialization_info: ?raw.SpecializationInfo = null,
    };

    /// Create a new compute pipeline with the given configuration
    pub fn create(device: raw.Device, create_info: CreateInfo) errors.Error!ComputePipeline {
        // Create shader stage
        const stage = raw.PipelineShaderStageCreateInfo{
            .sType = raw.sTy(.PipelineShaderStageCreateInfo),
            .pNext = null,
            .flags = 0,
            .stage = raw.SHADER_STAGE_COMPUTE_BIT,
            .module = create_info.shader.handle,
            .pName = "main",
            .pSpecializationInfo = if (create_info.specialization_info) |info| &info else null,
        };

        // Create compute pipeline info
        const pipeline_info = raw.ComputePipelineCreateInfo{
            .sType = raw.sTy(.ComputePipelineCreateInfo),
            .pNext = null,
            .flags = 0,
            .stage = stage,
            .layout = create_info.layout.handle,
            .basePipelineHandle = null,
            .basePipelineIndex = -1,
        };

        // Create the pipeline
        var handle: raw.Pipeline = undefined;
        const result = raw.createComputePipelines(device, null, // No pipeline cache
            1, &pipeline_info, null, &handle);
        try errors.checkResult(result);

        return ComputePipeline{
            .handle = handle,
            .device = device,
            .layout = create_info.layout.handle,
        };
    }

    /// Destroy the compute pipeline
    pub fn destroy(self: *ComputePipeline) void {
        raw.destroyPipeline(self.device, self.handle, null);
        self.* = undefined;
    }

    /// Get the raw pipeline handle
    pub fn getHandle(self: ComputePipeline) raw.Pipeline {
        return self.handle;
    }

    /// Get the pipeline layout
    pub fn getLayout(self: ComputePipeline) raw.PipelineLayout {
        return self.layout;
    }
};

/// Pipeline abstraction that can be either graphics or compute
pub const Pipeline = union(enum) {
    graphics: GraphicsPipeline,
    compute: ComputePipeline,

    /// Get the raw pipeline handle
    pub fn getHandle(self: Pipeline) raw.Pipeline {
        return switch (self) {
            .graphics => |p| p.getHandle(),
            .compute => |p| p.getHandle(),
        };
    }

    /// Get the pipeline layout
    pub fn getLayout(self: Pipeline) raw.PipelineLayout {
        return switch (self) {
            .graphics => |p| p.getLayout(),
            .compute => |p| p.getLayout(),
        };
    }

    /// Destroy the pipeline
    pub fn destroy(self: *Pipeline) void {
        switch (self.*) {
            .graphics => |*p| p.destroy(),
            .compute => |*p| p.destroy(),
        }
    }
};
