const inc = @import("include").render;

const vk = @import("vk.zig");
const logger = @import("../logger.zig");
// Import surface as a dependency
const sf = @import("surface");
const std = @import("std");
const pipelines = @import("pipeline.zig");
const task = @import("task.zig");
const frame = @import("frame.zig");
const math = @import("math");
const include = @import("include");
const ctx = @import("ctx.zig");
const alloc = @import("alloc.zig");

const Mat4 = math.Mat4;
const SurfaceId = sf.Id;
const Surface = sf.Surface;
const PlatformRenderer = inc.Renderer;
const PipelineCompiler = pipelines.PipelineCompiler;
const Graph = task.Graph;
const Pass = task.Pass;
const PassContext = task.PassContext;
const ResourceState = task.ResourceState;
const Frame = frame.Frame;
const Context = ctx.Context;

// Define the noise context and parameters structures
const NoiseContext = struct {
    noiseParamOffset: u64 align(8),
    noiseDataOffset: u64 align(8),
};

const NoiseParams = struct {
    seed: f32,
    scale: f32,
    frequency: f32,
    lacunarity: f32,
    persistence: f32,
    offset: [3]i32 align(16), // Align to 16 bytes to match vec3 in shader
    size: [3]u32 align(16), // Align to 16 bytes to match vec3 in shader
};

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
pub var renderAllocator: std.mem.Allocator = gpa.allocator();

var platformRenderers = std.AutoHashMap(PlatformRenderer, *Renderer).init(gpa.allocator());
var surfaceRenderers = std.AutoHashMap(Surface, PlatformRenderer).init(gpa.allocator());
var platformRendererActive = PlatformRenderer{
    .id = 0,
};

const GpuCamera = struct {
    viewProjection: Mat4,
};

const camera_sys = @import("camera.zig");
const RendererCamera = camera_sys.RendererCamera;
const heap_mod = @import("heap.zig");
const stage_mod = @import("stage.zig");

// Constants for buffer sizes
const RENDERER_STAGING_BUFFER_SIZE = 1024 * 1024 * 8; // 8MB
const RENDERER_HEAP_BUFFER_SIZE = 1024 * 1024 * 1024; // 1GB

const Renderer = struct {
    context: *Context,
    graph: *Graph,
    swapchainImageResource: *task.Resource,
    pipeline: *PipelineCompiler,
    frame: Frame,
    // Large heap and stage buffers for the renderer
    renderer_heap: *heap_mod.Heap,
    renderer_stage: *stage_mod.Stage,
    camera: ?*RendererCamera,
    allocator: *alloc.Allocator,
    // Noise allocations
    noise_context_allocation: *alloc.Allocation,
    noise_params_allocation: *alloc.Allocation,
    noise_data_allocation: *alloc.Allocation,
    // Add staging pass
    staging_pass: ?*task.Pass,

    fn init(surface: *Surface) !?*Renderer {
        logger.info("Initializing Vulkan renderer for surface ID: {}", .{surface.id});

        // Allocate renderer structure first
        logger.info("Allocating renderer structure...", .{});
        var renderer = renderAllocator.create(Renderer) catch |err| {
            logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Renderer structure allocated: {*}", .{renderer});

        // Initialize Vulkan context
        const vulkanContext = Context.init(surface) catch |err| {
            logger.err("Failed to initialize Vulkan context: {s}", .{@errorName(err)});
            return null;
        };
        if (vulkanContext == null) {
            logger.err("Failed to initialize Vulkan context", .{});
            return null;
        }
        renderer.context = vulkanContext.?;

        const workgroup_size = vulkanContext.?.maximumReasonableDispatchSize();
        logger.info("Maximum reasonable dispatch size: {}x{}x{}", .{ workgroup_size.x, workgroup_size.y, workgroup_size.z });

        // Create large heap buffer for the renderer
        logger.info("Creating large renderer heap buffer (1GB)...", .{});
        renderer.renderer_heap = heap_mod.Heap.create(
            vulkanContext.?.device,
            vulkanContext.?.physicalDevice,
            RENDERER_HEAP_BUFFER_SIZE,
            vk.BUFFER_USAGE_STORAGE_BUFFER_BIT | vk.BUFFER_USAGE_TRANSFER_DST_BIT,
            vk.MEMORY_PROPERTY_DEVICE_LOCAL_BIT,
            &renderAllocator,
        ) catch |err| {
            logger.err("Failed to create renderer heap: {s}", .{@errorName(err)});
            return null;
        };

        // Create large staging buffer for the renderer
        logger.info("Creating large renderer staging buffer (8MB)...", .{});
        renderer.renderer_stage = stage_mod.Stage.createWithBufferTarget(
            vulkanContext.?.device,
            vulkanContext.?.physicalDevice,
            vulkanContext.?.queue_family_index,
            RENDERER_STAGING_BUFFER_SIZE,
            renderer.renderer_heap.getBuffer(),
            0, // Target offset 0
            &renderAllocator,
        ) catch |err| {
            logger.err("Failed to create renderer stage: {s}", .{@errorName(err)});
            renderer.renderer_heap.destroy(vulkanContext.?.device, &renderAllocator);
            return null;
        };
        logger.info("Initializing render graph...", .{});
        renderer.graph = Graph.init(&renderAllocator, renderer, vulkanContext.?.swapchain, vulkanContext.?.render_finished_semaphores[0], vulkanContext.?.image_available_semaphores[0], vulkanContext.?.in_flight_fences[0], vulkanContext.?.queue, true) catch |err| {
            logger.err("Failed to initialize graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Render graph initialized: {*}", .{renderer.graph});
        renderer.allocator = renderAllocator.create(alloc.Allocator) catch |err| {
            logger.err("Failed to allocate memory for allocator: {s}", .{@errorName(err)});
            return null;
        };
        renderer.allocator.* = alloc.Allocator.init(vulkanContext.?.device, renderer.renderer_heap, renderer.renderer_stage, renderer.graph);

        logger.info("Initializing pipeline compiler...", .{});
        renderer.pipeline = PipelineCompiler.init(vulkanContext.?.device) catch |err| {
            logger.err("Failed to initialize pipeline compiler: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Pipeline compiler initialized", .{});

        logger.info("Creating triangle graphics pipeline...", .{});
        _ = renderer.pipeline.createGraphicsPipeline("triangle", .{
            .vertex_shader = .{ .path = "src/gfx/src/vk/hellotriangle.glsl", .shader_type = .Vertex },
            .fragment_shader = .{ .path = "src/gfx/src/vk/hellotrianglef.glsl", .shader_type = .Fragment },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
        }) catch |err| {
            logger.err("Failed to create graphics pipeline: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Triangle graphics pipeline created successfully", .{});

        logger.info("Creating bindless triangle graphics pipeline...", .{});
        _ = renderer.pipeline.createGraphicsPipeline("bindless_triangle", .{
            .vertex_shader = .{ .path = "src/gfx/src/vk/bindless_triangle.glsl", .shader_type = .Vertex },
            .fragment_shader = .{ .path = "src/gfx/src/vk/bindless_trianglef.glsl", .shader_type = .Fragment },
            .color_attachment_formats = &[_]vk.Format{vk.Format.B8G8R8A8Srgb},
            // Add push constant range for the camera device address and model matrix
            .push_constant_size = @sizeOf(camera_sys.CameraPushConstants),
        }) catch |err| {
            logger.err("Failed to create bindless graphics pipeline: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Bindless triangle graphics pipeline created successfully", .{});

        // Create noise compute pipeline
        logger.info("Creating noise compute pipeline...", .{});
        _ = renderer.pipeline.createComputePipeline("noise_compute", .{
            .shader = .{ .path = "src/gfx/src/vk/010_generate_noise.glsl", .shader_type = .Compute },
            // Add push constant range for the heap address and noise context offset
            .push_constant_size = @sizeOf(struct {
                heap_address: u64,
                noise_context_offset: u64,
            }),
        }) catch |err| {
            logger.err("Failed to create noise compute pipeline: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise compute pipeline created successfully", .{});

        logger.info("Setting up triangle rendering pass...", .{});
        const trianglePassFn = struct {
            fn execute(passCtx: PassContext) void {
                logger.info("Executing triangle pass...", .{});
                const taskRenderer = @as(*Renderer, @ptrCast(@alignCast(passCtx.userData)));

                logger.info("Triangle pass context: cmd={*}, frame={}x{}", .{ passCtx.cmd, passCtx.frame.*.width, passCtx.frame.*.height });

                if (passCtx.pass.inputs.items.len == 0 or passCtx.pass.inputs.items[0].resource.view == null) {
                    logger.err("No inputs for triangle pass", .{});
                    return;
                }

                // Get heap device address for bindless access
                logger.info("Getting heap device address...", .{});

                const heapAddress = taskRenderer.renderer_heap.getDeviceAddress() catch |err| {
                    logger.err("Failed to get heap device address: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Heap device address: 0x{x}", .{heapAddress});

                // Verify the heap address is valid
                if (heapAddress == 0) {
                    logger.err("Invalid heap address (0)", .{});
                    return;
                }

                // Create push constant data with the heap address
                logger.info("Creating push constants...", .{});

                // Check that m4Id returns a valid matrix
                const modelMatrix = math.m4Id();
                logger.info("Model matrix from m4Id: {any}", .{modelMatrix});

                // Print out the data array to verify it's a proper identity matrix
                logger.info("Model matrix data array:", .{});
                for (0..4) |col| {
                    logger.info("Col {}: [{}, {}, {}, {}]", .{
                        col,
                        modelMatrix.data[col * 4 + 0],
                        modelMatrix.data[col * 4 + 1],
                        modelMatrix.data[col * 4 + 2],
                        modelMatrix.data[col * 4 + 3],
                    });
                }

                // Get camera offset
                const cameraOffset = if (taskRenderer.camera) |camera| blk: {
                    if (camera.camera_allocation) |allocation| {
                        logger.info("Camera allocation heap offset: {}", .{allocation.heap_offset});
                        break :blk allocation.heap_offset;
                    } else {
                        logger.err("Camera allocation is null", .{});
                        break :blk 0;
                    }
                } else blk: {
                    logger.err("Camera is null", .{});
                    break :blk 0;
                };

                // Create push constants with the verified model matrix
                const pushConstants = camera_sys.CameraPushConstants{
                    .heap_address = heapAddress,
                    .camera_offset = cameraOffset,
                };
                logger.info("Push constants created with heap_address=0x{x}, camera_offset={}", .{ pushConstants.heap_address, pushConstants.camera_offset });

                // Verify push constants are valid
                if (pushConstants.heap_address == 0) {
                    logger.err("Invalid heap address in push constants (0)", .{});
                    return;
                }

                logger.info("Setting up color attachment for frame {}x{}", .{ passCtx.frame.*.width, passCtx.frame.*.height });
                const color_attachment = vk.RenderingAttachmentInfoKHR{
                    .sType = vk.sTy(vk.StructureType.RenderingAttachmentInfoKHR),
                    .imageView = passCtx.pass.inputs.items[0].resource.view.?.imageView,
                    .imageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    .resolveMode = vk.RESOLVE_MODE_NONE_KHR,
                    .resolveImageView = null,
                    .resolveImageLayout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
                    .loadOp = vk.RENDER_PASS_LOAD_OP_CLEAR,
                    .storeOp = vk.RENDER_PASS_STORE_OP_STORE,
                    .clearValue = vk.ClearValue{
                        .color = vk.ClearColorValue{
                            .float32 = [_]f32{ 0.1, 0.1, 0.1, 1.0 },
                        },
                    },
                };

                const rendering_info = vk.RenderingInfoKHR{
                    .sType = vk.sTy(vk.StructureType.RenderingInfoKHR),
                    .renderArea = vk.Rect2D{
                        .offset = vk.Offset2D{ .x = 0, .y = 0 },
                        .extent = vk.Extent2D{ .width = passCtx.frame.*.width, .height = passCtx.frame.*.height },
                    },
                    .layerCount = 1,
                    .colorAttachmentCount = 1,
                    .pColorAttachments = &color_attachment,
                };

                logger.info("Beginning dynamic rendering", .{});
                vk.cmdBeginRenderingKHR(passCtx.cmd, &rendering_info);
                logger.debug("Color attachment: {any}", .{rendering_info});

                // Use the bindless pipeline instead of the regular triangle pipeline
                logger.info("Getting bindless_triangle pipeline...", .{});
                const pipeline = taskRenderer.pipeline.getPipeline("bindless_triangle") catch |err| {
                    logger.err("Failed to get bindless pipeline: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Pipeline obtained: {*}", .{pipeline});

                logger.info("Binding pipeline", .{});
                vk.cmdBindPipeline(passCtx.cmd, vk.PIPELINE_BIND_POINT_GRAPHICS, pipeline.asGraphics().?.getHandle().?);

                const viewport = vk.Viewport{
                    .x = 0.0,
                    .y = 0.0,
                    .width = @floatFromInt(passCtx.frame.*.width),
                    .height = @floatFromInt(passCtx.frame.*.height),
                    .minDepth = 0.0,
                    .maxDepth = 1.0,
                };

                logger.info("Setting viewport: {}x{}", .{ viewport.width, viewport.height });
                vk.cmdSetViewport(passCtx.cmd, 0, 1, &viewport);

                const scissor = vk.Rect2D{
                    .offset = vk.Offset2D{ .x = 0, .y = 0 },
                    .extent = vk.Extent2D{ .width = passCtx.frame.*.width, .height = passCtx.frame.*.height },
                };

                logger.info("Setting scissor: {}x{}", .{ scissor.extent.width, scissor.extent.height });
                vk.cmdSetScissor(passCtx.cmd, 0, 1, &scissor);

                // Push the constants to the shader
                logger.info("Pushing constants with heap address: 0x{x}", .{heapAddress});
                if (pipeline.asGraphics() == null) {
                    logger.err("Pipeline is not a graphics pipeline", .{});
                    return;
                }

                const pipelineLayout = pipeline.asGraphics().?.base.layout;
                logger.info("Pipeline layout: {*}", .{pipelineLayout});

                // Verify the push constant size
                const pushConstantsSize = @sizeOf(camera_sys.CameraPushConstants);
                logger.info("Push constants size: {} bytes", .{pushConstantsSize});
                // Verify the first few bytes of push constants to check alignment
                const pushConstantsPtr = @as([*]const u8, @ptrCast(&pushConstants));
                logger.info("First 16 bytes of push constants: {any}", .{pushConstantsPtr[0..16]});

                vk.cmdPushConstants(passCtx.cmd, pipelineLayout, vk.SHADER_STAGE_VERTEX_BIT | vk.SHADER_STAGE_FRAGMENT_BIT, 0, pushConstantsSize, &pushConstants);

                logger.info("Drawing triangle (3 vertices) with cmd={*}", .{passCtx.cmd});
                vk.cmdDraw(passCtx.cmd, 3, 1, 0, 0);
                logger.info("Draw call completed", .{});

                logger.info("Ending dynamic rendering", .{});
                vk.cmdEndRenderingKHR(passCtx.cmd);
                logger.info("Triangle pass execution complete", .{});
            }
        }.execute;

        logger.info("Creating triangle pass...", .{});
        const trianglePass = Pass.init(&renderAllocator, "triangle", trianglePassFn) catch |err| {
            logger.err("Failed to create triangle pass: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Triangle pass created", .{});
        // CRITICAL FIX: Set the renderer as userData for the triangle pass
        // This ensures the triangle pass has access to the renderer during execution
        trianglePass.userData = renderer;

        const noisePassFn = struct {
            fn execute(passCtx: PassContext) void {
                const taskRenderer = @as(*Renderer, @ptrCast(@alignCast(passCtx.userData)));
                logger.info("Executing noise pass...", .{});

                // Get the compute pipeline for noise generation
                const pipeline = taskRenderer.pipeline.getPipeline("noise_compute") catch |err| {
                    logger.err("Failed to get noise compute pipeline: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Noise compute pipeline obtained successfully", .{});

                // Bind the compute pipeline
                vk.cmdBindPipeline(passCtx.cmd, vk.PIPELINE_BIND_POINT_COMPUTE, pipeline.asCompute().?.base.handle);
                logger.info("Noise compute pipeline bound successfully", .{});

                // Get the pipeline layout
                const pipelineLayout = pipeline.asCompute().?.base.layout;

                // Get the heap device address
                const heapAddress = taskRenderer.renderer_heap.getDeviceAddress() catch |err| {
                    logger.err("Failed to get heap device address: {s}", .{@errorName(err)});
                    return;
                };
                logger.info("Heap device address: 0x{x}", .{heapAddress});

                // Create push constants with heap address and noise context offset
                const pushConstants = struct {
                    heap_address: u64,
                    noise_context_offset: u64,
                }{
                    .heap_address = heapAddress,
                    .noise_context_offset = taskRenderer.noise_context_allocation.heap_offset,
                };
                logger.info("Push constants: {any}", .{pushConstants});

                // Push the constants to the shader
                vk.cmdPushConstants(
                    passCtx.cmd,
                    pipelineLayout,
                    vk.SHADER_STAGE_COMPUTE,
                    0,
                    @sizeOf(@TypeOf(pushConstants)),
                    &pushConstants,
                );
                logger.info("Push constants sent to shader", .{});

                // Get the maximum dispatch size from the context
                const noise_workgroup_size = taskRenderer.context.maximumReasonableDispatchSize();
                logger.info("Maximum workgroup size: {any}", .{noise_workgroup_size});

                // Calculate grid size based on noise texture dimensions (32x32x32)
                const grid_size_x = (32 + noise_workgroup_size.x - 1) / noise_workgroup_size.x;
                const grid_size_y = (32 + noise_workgroup_size.y - 1) / noise_workgroup_size.y;
                const grid_size_z = (32 + noise_workgroup_size.z - 1) / noise_workgroup_size.z;

                logger.info("Dispatching noise compute shader with grid size: {}x{}x{} and workgroup size: {}x{}x{}", .{ grid_size_x, grid_size_y, grid_size_z, noise_workgroup_size.x, noise_workgroup_size.y, noise_workgroup_size.z });
                vk.cmdDispatch(passCtx.cmd, grid_size_x, grid_size_y, grid_size_z);
                logger.info("Noise compute shader dispatch complete", .{});
            }
        }.execute;

        // Create the noise pass
        logger.info("Creating noise pass...", .{});
        const noisePass = Pass.init(&renderAllocator, "noise", noisePassFn) catch |err| {
            logger.err("Failed to create noise pass: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise pass created", .{});
        noisePass.userData = renderer;

        // Create resources for noise data
        const noiseContextResource = task.Resource.init(&renderAllocator, "noise_context", .Buffer, renderer.renderer_heap.buffer) catch |err| {
            logger.err("Failed to create noise context resource: {s}", .{@errorName(err)});
            return null;
        };
        const noiseParamsResource = task.Resource.init(&renderAllocator, "noise_params", .Buffer, renderer.renderer_heap.buffer) catch |err| {
            logger.err("Failed to create noise params resource: {s}", .{@errorName(err)});
            return null;
        };
        const noiseDataResource = task.Resource.init(&renderAllocator, "noise_data", .Buffer, renderer.renderer_heap.buffer) catch |err| {
            logger.err("Failed to create noise data resource: {s}", .{@errorName(err)});
            return null;
        };

        logger.info("Allocating memory for noise context (size: {} bytes)...", .{@sizeOf(NoiseContext)});
        // Allocate memory for noise context
        const noiseContextSize = @sizeOf(NoiseContext);
        logger.info("allocator ptr: {}", .{renderer.allocator});
        renderer.noise_context_allocation = renderer.allocator.alloc(noiseContextSize, 8) catch |err| {
            logger.err("Failed to allocate noise context: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise context allocation successful at offset: {}", .{renderer.noise_context_allocation.heap_offset});

        logger.info("Allocating memory for noise parameters (size: {} bytes)...", .{@sizeOf(NoiseParams)});
        // Allocate memory for noise parameters
        const noiseParamsSize = @sizeOf(NoiseParams);
        renderer.noise_params_allocation = renderer.allocator.alloc(noiseParamsSize, 8) catch |err| {
            logger.err("Failed to allocate noise parameters: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise parameters allocation successful at offset: {}", .{renderer.noise_params_allocation.heap_offset});

        logger.info("Allocating memory for noise data (size: {} bytes)...", .{32 * 32 * 32 * @sizeOf(f32)});
        // Allocate memory for noise data (32x32x32 = 32768 floats)
        const noiseDataSize = 32 * 32 * 32 * @sizeOf(f32);
        renderer.noise_data_allocation = renderer.allocator.alloc(noiseDataSize, 8) catch |err| {
            logger.err("Failed to allocate noise data: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise data allocation successful at offset: {}", .{renderer.noise_data_allocation.heap_offset});

        // Create and write the noise context
        const noiseContext = NoiseContext{
            .noiseParamOffset = renderer.noise_params_allocation.heap_offset,
            .noiseDataOffset = renderer.noise_data_allocation.heap_offset,
        };
        logger.info("Created noise context with param offset: {} and data offset: {}", .{ noiseContext.noiseParamOffset, noiseContext.noiseDataOffset });
        // Write the noise context to its allocation
        logger.info("Writing noise context to allocation...", .{});
        logger.info("Writing bytes: {any}", .{std.mem.asBytes(&noiseContext)});
        const bytesWritten = renderer.noise_context_allocation.write(std.mem.asBytes(&noiseContext)) catch |err| {
            logger.err("Failed to write noise context: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise context written successfully, {} bytes written", .{bytesWritten});

        // Create and write the noise parameters
        const noiseParams = NoiseParams{
            .seed = 42.0,
            .scale = 1.0,
            .frequency = 1.0,
            .lacunarity = 2.0,
            .persistence = 0.5,
            .offset = [_]i32{ 0, 0, 0 },
            .size = [_]u32{ 32, 32, 32 },
        };
        logger.info("Created noise parameters: seed={}, scale={}, frequency={}, lacunarity={}, persistence={}, offset=[{}, {}, {}], size=[{}, {}, {}]", .{ noiseParams.seed, noiseParams.scale, noiseParams.frequency, noiseParams.lacunarity, noiseParams.persistence, noiseParams.offset[0], noiseParams.offset[1], noiseParams.offset[2], noiseParams.size[0], noiseParams.size[1], noiseParams.size[2] });

        // Write the noise parameters to its allocation
        logger.info("Writing noise parameters to allocation...", .{});
        const paramsBytesWritten = renderer.noise_params_allocation.write(std.mem.asBytes(&noiseParams)) catch |err| {
            logger.err("Failed to write noise parameters: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise parameters written successfully, {} bytes written", .{paramsBytesWritten});

        // Get device addresses for verification
        const noiseContextAddr = renderer.noise_context_allocation.deviceAddress() catch |err| {
            logger.err("Failed to get noise context device address: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise context device address: 0x{x}", .{noiseContextAddr});

        const noiseParamsAddr = renderer.noise_params_allocation.deviceAddress() catch |err| {
            logger.err("Failed to get noise params device address: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise params device address: 0x{x}", .{noiseParamsAddr});

        const noiseDataAddr = renderer.noise_data_allocation.deviceAddress() catch |err| {
            logger.err("Failed to get noise data device address: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise data device address: 0x{x}", .{noiseDataAddr});

        // Flush individual allocations with proper synchronization
        logger.info("Flushing noise context allocation...", .{});
        renderer.noise_context_allocation.flush() catch |err| {
            logger.err("Failed to flush noise context: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise context flushed successfully", .{});

        logger.info("Flushing noise params allocation...", .{});
        renderer.noise_params_allocation.flush() catch |err| {
            logger.err("Failed to flush noise params: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise params flushed successfully", .{});

        logger.info("Flushing noise data allocation...", .{});
        renderer.noise_data_allocation.flush() catch |err| {
            logger.err("Failed to flush noise data: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise data flushed successfully", .{});

        // Flush all allocations to make them available on the GPU
        logger.info("Flushing all allocations to make them available on the GPU...", .{});
        renderer.allocator.flush() catch |err| {
            logger.err("Failed to flush allocations: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Allocations flushed successfully", .{});

        logger.info("Noise allocations initialized successfully", .{});

        logger.info("Creating swapchain image resource...", .{});
        renderer.swapchainImageResource = task.Resource.init(&renderAllocator, "swapchain_image", .Image, null) catch |err| {
            logger.err("Failed to create swapchain image resource: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Swapchain image resource created: {*}", .{renderer.swapchainImageResource});

        // Add resources to the graph
        logger.info("Adding resources to graph...", .{});
        try renderer.graph.addResource(renderer.swapchainImageResource);
        try renderer.graph.addResource(noiseContextResource);
        try renderer.graph.addResource(noiseParamsResource);
        try renderer.graph.addResource(noiseDataResource);
        logger.info("Resources added to graph", .{});

        // Add resources to the noise pass with proper regions
        try noisePass.addInput(noiseContextResource, .{
            .accessMask = vk.ACCESS_SHADER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        }, .{
            .offset = renderer.noise_context_allocation.heap_offset,
            .size = @sizeOf(NoiseContext),
        });

        try noisePass.addInput(noiseParamsResource, .{
            .accessMask = vk.ACCESS_SHADER_READ_BIT,
            .stageMask = vk.PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        }, .{
            .offset = renderer.noise_params_allocation.heap_offset,
            .size = @sizeOf(NoiseParams),
        });

        try noisePass.addOutput(noiseDataResource, .{
            .accessMask = vk.ACCESS_SHADER_WRITE_BIT,
            .stageMask = vk.PIPELINE_STAGE_COMPUTE_SHADER_BIT,
        }, .{
            .offset = renderer.noise_data_allocation.heap_offset,
            .size = 32 * 32 * 32 * @sizeOf(f32),
        });

        logger.info("Adding swapchain as input to triangle pass...", .{});
        trianglePass.addInput(renderer.swapchainImageResource, task.ResourceState{
            .accessMask = vk.ACCESS_COLOR_ATTACHMENT_WRITE,
            .stageMask = vk.PIPELINE_STAGE_COLOR_ATTACHMENT_OUTPUT,
            .layout = vk.IMAGE_LAYOUT_COLOR_ATTACHMENT_OPTIMAL,
            .queueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
        }, null) catch |err| {
            logger.err("Failed to add input to triangle pass: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Input added successfully", .{});

        // Initialize camera system using renderer's heap and stage
        logger.info("Initializing camera system with renderer's heap and stage...", .{});
        renderer.camera = RendererCamera.create(vulkanContext.?.device, renderer.renderer_heap, renderer.renderer_stage, renderer.allocator, &renderAllocator) catch |err| {
            logger.err("Failed to initialize camera system: {s}", .{@errorName(err)});
            renderer.camera = null;
            return null;
        };

        logger.info("Camera system initialized with direct allocation", .{});

        // Create staging pass
        logger.info("Creating staging pass...", .{});
        renderer.staging_pass = renderer.renderer_stage.createStagingPass("StagingPass") catch |err| {
            logger.err("Failed to create staging pass: {s}", .{@errorName(err)});
            renderer.staging_pass = null;
            return null;
        };

        // Add staging pass to the graph BEFORE the noise pass
        logger.info("Adding staging pass to render graph...", .{});
        renderer.graph.addPass(renderer.staging_pass.?) catch |err| {
            logger.err("Failed to add staging pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Staging pass added to graph", .{});

        // Set initial camera at position 0,0,5 looking toward the triangle at z=-2
        const initial_position = math.v3(0.0, 0.0, 5.0);
        const look_target = math.v3(0.0, 0.0, -2.0); // Look at where the triangle is positioned
        const initial_view = math.m4LookAt(initial_position, look_target, math.v3Z() // Using Z as up vector as requested
        );
        const initial_projection = math.m4Persp(math.rad(45.0), @as(f32, @floatFromInt(renderer.frame.width)) / @as(f32, @floatFromInt(renderer.frame.height)), 0.1, 1000.0);

        _ = renderer.camera.?.update(initial_view, initial_projection) catch |err| {
            logger.warn("Failed to set initial camera: {s}", .{@errorName(err)});
        };

        logger.info("Adding passes to render graph...", .{});

        // Add noise pass to the graph after camera pass
        logger.info("Adding noise pass to render graph...", .{});
        renderer.graph.addPass(noisePass) catch |err| {
            logger.err("Failed to add noise pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Noise pass added to graph", .{});

        // Now add the triangle pass after the camera pass
        renderer.graph.addPass(trianglePass) catch |err| {
            logger.err("Failed to add triangle pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Triangle pass added to graph", .{});

        var submitPass = task.getPassSubmit(renderer);
        submitPass.userData = renderer;
        renderer.graph.addPass(submitPass) catch |err| {
            logger.err("Failed to add submit pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Submit pass added to graph", .{});

        var presentPass = task.pass_present(renderer.swapchainImageResource);
        presentPass.userData = renderer;
        renderer.graph.addPass(presentPass) catch |err| {
            logger.err("Failed to add present pass to graph: {s}", .{@errorName(err)});
            return null;
        };
        logger.info("Present pass added to graph", .{});

        var surfaceCapabilities: vk.SurfaceCapabilitiesKHR = undefined;
        _ = vk.getPhysicalDeviceSurfaceCapabilitiesKHR(vulkanContext.?.physicalDevice, vulkanContext.?.surface.?, &surfaceCapabilities);
        logger.info("Finalizing renderer setup...", .{});
        renderer.frame = Frame{
            .width = surfaceCapabilities.currentExtent.width,
            .index = 0,
            .height = surfaceCapabilities.currentExtent.height,
            .count = 0,
        };

        // Initialize noise allocations
        logger.info("Initializing noise allocations...", .{});

        logger.info("Renderer initialization complete. Returning renderer: {*}", .{renderer});
        return renderer;
    }
};

pub export fn init(surface: ?*Surface) ?*PlatformRenderer {
    // Fixed export with name that matches Rust's expectation
    if (surface == null) {
        logger.err("Surface is null.", .{});
        return null;
    }
    if (surfaceRenderers.contains(surface.?.*)) {
        logger.warn("Renderer already exists for this surface.", .{});
        return null;
    }

    const renderer = Renderer.init(surface.?) catch |err| {
        logger.err("Renderer initialization failed: {s}", .{@errorName(err)});
        return null;
    };
    if (renderer == null) {
        logger.err("Renderer initialization failed.", .{});
        return null;
    }

    const id = platformRendererActive;
    platformRendererActive.id += 1;
    platformRenderers.put(id, renderer.?) catch |err| {
        logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
        return null;
    };
    surfaceRenderers.put(surface.?.*, id) catch |err| {
        logger.err("Failed to allocate memory for renderer: {s}", .{@errorName(err)});
        return null;
    };
    logger.info("Renderer initialized successfully.", .{});
    logger.info("Renderer ID: {}", .{id});
    logger.info("Renderer pointer: {}", .{renderer.?.*});
    logger.info("Surface pointer: {}", .{surface.?.*});
    logger.info("Surface ID: {}", .{surface.?.*});

    const platform_renderer = renderAllocator.create(PlatformRenderer) catch |err| {
        logger.err("Failed to allocate memory for platform renderer: {s}", .{@errorName(err)});
        return null;
    };
    platform_renderer.* = id;
    return platform_renderer;
}

pub export fn shutdown(handle: ?*PlatformRenderer) void {
    if (handle == null) return;

    var renderer = platformRenderers.get(handle.?.*) orelse {
        return;
    };

    // // Cleanup noise allocations if they exist
    // if (renderer.noise_context_allocation != null) {
    //     renderer.noise_context_allocation.?.deinit();
    //     renderer.noise_context_allocation = null;
    // }
    // if (renderer.noise_params_allocation != null) {
    //     renderer.noise_params_allocation.?.deinit();
    //     renderer.noise_params_allocation = null;
    // }
    // if (renderer.noise_data_allocation != null) {
    //     renderer.noise_data_allocation.?.deinit();
    //     renderer.noise_data_allocation = null;
    // }

    // Cleanup camera resources if they exist
    if (renderer.camera != null) {
        renderer.camera.?.destroy();
        renderer.camera = null;
    }

    // Cleanup renderer stage and heap

    // Clean up task graph resources
    renderer.graph.deinit();

    // Clean up Vulkan context
    renderer.context.deinit();

    // Remove from maps
    _ = platformRenderers.remove(handle.?.*);

    // Find and remove from surfaceRenderers by value
    var sr_it = surfaceRenderers.iterator();
    while (sr_it.next()) |entry| {
        if (std.meta.eql(entry.value_ptr.*, handle.?.*)) {
            _ = surfaceRenderers.remove(entry.key_ptr.*);
            break;
        }
    }

    renderAllocator.destroy(renderer);
    renderAllocator.destroy(handle.?);

    logger.info("Vulkan renderer destroyed.", .{});
}

pub export fn render(handle: ?*PlatformRenderer) void {
    logger.info("Render function called with handle: {*}", .{handle});

    // Get renderer...
    var renderer = platformRenderers.get(handle.?.*) orelse {
        logger.err("Could not find renderer for handle {*}", .{handle});
        return;
    };
    logger.info("Found renderer: {*}", .{renderer});

    const activeFrame = &renderer.frame;
    const frameIndex = activeFrame.index;
    logger.info("Active frame index: {}, width: {}, height: {}", .{ frameIndex, activeFrame.width, activeFrame.height });

    // Acquire next image using the context
    const imageIndex = renderer.context.acquireNextImage(frameIndex) catch |err| {
        if (err == error.NotReady) {
            return;
        }
        if (err == error.OutOfDate) {
            // Swapchain was recreated, continue on next frame
            return;
        }
        logger.err("Failed to acquire next image: {s}", .{@errorName(err)});
        return;
    };

    logger.debug("Acquired image index: {}", .{imageIndex});
    logger.debug("Swapchain image length: {}", .{renderer.context.swapchainImages.len});
    logger.debug("Swapchain image: {any}", .{renderer.context.swapchainImages[0]});

    std.debug.print(
        "Swapchain image resource: {any}\n",
        .{renderer.swapchainImageResource},
    );
    renderer.swapchainImageResource.handle = task.ResourceHandle{ .image = renderer.context.swapchainImages[imageIndex] };
    renderer.swapchainImageResource.createView(renderer.context.device, vk.IMAGE_VIEW_TYPE_2D, vk.Format.B8G8R8A8Srgb) catch |err| {
        std.debug.print("Failed to create image view: {s}\n", .{@errorName(err)});
        return;
    };

    logger.info("Executing render commands for frame {}", .{frameIndex});

    // Log command buffer state
    logger.info("Using command buffer: {*}", .{renderer.context.command_buffers[frameIndex]});

    // Execute the graph with the CURRENT frame's command buffer and synchronization objects
    const passContext = PassContext{
        .cmd = renderer.context.command_buffers[frameIndex],
        .queue = renderer.context.queue,
        .swapchain = renderer.context.swapchain,
        .render_finished_semaphore = renderer.context.render_finished_semaphores[frameIndex],
        .image_available_semaphore = renderer.context.image_available_semaphores[frameIndex],
        .in_flight_fence = renderer.context.in_flight_fences[frameIndex],
        .frame = activeFrame,
        .userData = renderer,
    };

    logger.info("Starting graph execution with context: cmd={*}, queue={*}, fence={*}", .{ passContext.cmd, passContext.queue, passContext.in_flight_fence });

    renderer.graph.execute(renderer.context.command_buffers[frameIndex], // Use frame-specific command buffer
        passContext // Pass context to the execute function
    ) catch |err| {
        logger.err("Failed to execute render graph: {s}", .{@errorName(err)});
        return;
    };

    logger.info("Graph execution completed successfully", .{});
    // Advance to next frame
}

pub export fn setCamera(handle: ?*include.render.Renderer, camera: *const include.render.Camera) void {
    if (handle == null) return;

    var renderer = platformRenderers.get(handle.?.*) orelse {
        return;
    };
    const position = camera.position;
    const rotation = camera.rotation;
    const translationMatrix = math.m4TransV3(position);
    const rotationMatrix = math.qToM4(rotation);
    const transform = math.m4Mul(translationMatrix, rotationMatrix);
    const view = math.m4Inv(transform);
    // If the camera system is available, update it
    if (renderer.camera != null) {
        _ = renderer.camera.?.update(view, camera.projection) catch |err| {
            std.debug.print("Failed to update camera in setCamera: {s}\n", .{@errorName(err)});
            return;
        };
    }
}
