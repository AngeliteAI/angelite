const std = @import("std");
const vk = @import("vulkan");
const renderer = @import("../../gfx/vk/render.zig");
const vertex_pool = @import("../../gfx/vk/vertex_pool.zig");
const PipelineManager = @import("../../gfx/vk/PipelineManager.zig");

// Push constants structure for physics shaders
const PhysicsPushConstants = struct {
    rigidbodies_address: u64,
    collision_pairs_address: u64,
    contacts_address: u64,
    delta_time: f32,
    gravity_x: f32,
    gravity_y: f32,
    gravity_z: f32,
    body_count: u32,
    substeps: u32,
    padding: [2]u32 = [_]u32{0} ** 2,
};

const Vec3f = extern struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zero() Vec3f {
        return .{ .x = 0, .y = 0, .z = 0 };
    }

    pub fn scale(self: Vec3f, s: f32) Vec3f {
        return .{ .x = self.x * s, .y = self.y * s, .z = self.z * s };
    }

    pub fn add(self: Vec3f, other: Vec3f) Vec3f {
        return .{ .x = self.x + other.x, .y = self.y + other.y, .z = self.z + other.z };
    }

    pub fn sub(self: Vec3f, other: Vec3f) Vec3f {
        return .{ .x = self.x - other.x, .y = self.y - other.y, .z = self.z - other.z };
    }
};

const Quat = extern struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub fn identity() Quat {
        return .{ .x = 0, .y = 0, .z = 0, .w = 1 };
    }
};

// GPU-side rigid body data (must match compute shader layout)
const RigidBodyGPU = extern struct {
    // Current state
    position: Vec3f,
    orientation: Quat,

    // Previous state for Verlet integration
    prev_position: Vec3f,
    prev_orientation: Quat,

    // Physical properties
    mass: f32,
    inv_mass: f32,
    friction: f32,
    restitution: f32,

    linear_damping: f32,
    angular_damping: f32,
    angular_moment: Vec3f,
    center_of_mass: Vec3f,

    // Oriented bounding box
    half_extents: Vec3f,

    // Forces accumulated this frame
    force_accumulator: Vec3f,
    torque_accumulator: Vec3f,

    // Collision response
    collision_normal: Vec3f,
    collision_depth: f32,

    // Flags
    is_static: u32,
    is_active: u32,
    padding: [2]u32,
};

// CPU-side handle to a rigid body
const RigidBodyHandle = struct {
    index: u32,
    generation: u32,
};

const MAX_BODIES = 1024;
const MAX_COLLISION_PAIRS = 4096;
const MAX_CONTACTS = 4096;

const PhysicsEngine = struct {
    // Vulkan resources (optional - only if graphics is available)
    device: ?vk.Device,
    command_pool: ?vk.CommandPool,
    compute_queue: ?vk.Queue,
    device_dispatch: ?*const vk.DeviceDispatch,
    physical_device: ?vk.PhysicalDevice,
    instance_dispatch: ?*const vk.InstanceDispatch,

    // Pipeline manager for compute pipelines
    pipeline_manager: ?*PipelineManager.PipelineManager,
    
    // Device address compute pipelines
    broad_phase_pipeline: ?PipelineManager.DeviceAddressPipeline,
    narrow_phase_pipeline: ?PipelineManager.DeviceAddressPipeline,
    integration_pipeline: ?PipelineManager.DeviceAddressPipeline,
    resolve_pipeline: ?PipelineManager.DeviceAddressPipeline,

    // GPU buffers
    rigidbody_buffer: ?vk.Buffer,
    rigidbody_memory: ?vk.DeviceMemory,
    collision_pairs_buffer: ?vk.Buffer,
    collision_pairs_memory: ?vk.DeviceMemory,
    contact_buffer: ?vk.Buffer,
    contact_memory: ?vk.DeviceMemory,

    // Command buffer for compute
    compute_command_buffer: ?vk.CommandBuffer,

    // CPU-side data (always available)
    rigidbodies: std.ArrayList(RigidBodyGPU),
    handles: std.ArrayList(RigidBodyHandle),
    free_list: std.ArrayList(u32),
    generation_counter: u32,

    // Physics settings
    gravity: Vec3f,
    substeps: u32,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*PhysicsEngine {
        const engine = try allocator.create(PhysicsEngine);
        engine.* = .{
            .device = null,
            .command_pool = null,
            .compute_queue = null,
            .device_dispatch = null,
            .physical_device = null,
            .instance_dispatch = null,
            .pipeline_manager = null,
            .broad_phase_pipeline = null,
            .narrow_phase_pipeline = null,
            .integration_pipeline = null,
            .resolve_pipeline = null,
            .rigidbody_buffer = null,
            .rigidbody_memory = null,
            .collision_pairs_buffer = null,
            .collision_pairs_memory = null,
            .contact_buffer = null,
            .contact_memory = null,
            .compute_command_buffer = null,
            .rigidbodies = std.ArrayList(RigidBodyGPU).init(allocator),
            .handles = std.ArrayList(RigidBodyHandle).init(allocator),
            .free_list = std.ArrayList(u32).init(allocator),
            .generation_counter = 1,
            .gravity = Vec3f{ .x = 0, .y = 0, .z = -9.81 },
            .substeps = 1,
            .allocator = allocator,
        };
        return engine;
    }

    pub fn deinit(self: *PhysicsEngine) void {
        // Clean up GPU resources if they exist
        if (self.device) |device| {
            if (self.device_dispatch) |dispatch| {
                // Clean up buffers
                if (self.rigidbody_buffer) |buffer| {
                    dispatch.vkDestroyBuffer.?(device, buffer, null);
                }
                if (self.rigidbody_memory) |memory| {
                    dispatch.vkFreeMemory.?(device, memory, null);
                }
                if (self.collision_pairs_buffer) |buffer| {
                    dispatch.vkDestroyBuffer.?(device, buffer, null);
                }
                if (self.collision_pairs_memory) |memory| {
                    dispatch.vkFreeMemory.?(device, memory, null);
                }
                if (self.contact_buffer) |buffer| {
                    dispatch.vkDestroyBuffer.?(device, buffer, null);
                }
                if (self.contact_memory) |memory| {
                    dispatch.vkFreeMemory.?(device, memory, null);
                }
                
                // Clean up pipelines
                if (self.integration_pipeline) |*pipeline| {
                    pipeline.deinit();
                }
                if (self.broad_phase_pipeline) |*pipeline| {
                    pipeline.deinit();
                }
                if (self.narrow_phase_pipeline) |*pipeline| {
                    pipeline.deinit();
                }
                if (self.resolve_pipeline) |*pipeline| {
                    pipeline.deinit();
                }
                
                // Clean up pipeline manager
                if (self.pipeline_manager) |manager| {
                    manager.deinit();
                    self.allocator.destroy(manager);
                }
            }
        }

        self.rigidbodies.deinit();
        self.handles.deinit();
        self.free_list.deinit();
        self.allocator.destroy(self);
    }

    // Initialize GPU acceleration if Vulkan is available
    pub fn initGPU(self: *PhysicsEngine, device: vk.Device, command_pool: vk.CommandPool, queue: vk.Queue) !void {
        self.device = device;
        self.command_pool = command_pool;
        self.compute_queue = queue;

        std.debug.print("Physics GPU initialization started\n", .{});
        
        // Check that dispatch tables have been set
        if (self.device_dispatch == null) {
            std.debug.print("ERROR: device_dispatch not set before initGPU. Call physics_engine_set_dispatch_tables first!\n", .{});
            return error.MissingDispatchTables;
        }

        // Create buffers for GPU physics
        try self.createGPUBuffers();

        // Create compute pipelines
        try self.createComputePipelines();

        // Allocate command buffer
        try self.allocateCommandBuffer();

        std.debug.print("Physics GPU initialization completed\n", .{});
    }

    fn createGPUBuffers(self: *PhysicsEngine) !void {
        const device = self.device orelse return error.NoDevice;
        const dispatch = self.device_dispatch orelse return error.NoDispatch;

        // Create rigidbody SSBO with device address support
        const rigidbody_buffer_size = @sizeOf(RigidBodyGPU) * MAX_BODIES;
        const buffer_info = vk.BufferCreateInfo{
            .size = rigidbody_buffer_size,
            .usage = .{ 
                .storage_buffer_bit = true, 
                .transfer_src_bit = true, 
                .transfer_dst_bit = true,
                .shader_device_address_bit = true,
            },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        var buffer: vk.Buffer = undefined;
        _ = dispatch.vkCreateBuffer.?(device, &buffer_info, null, &buffer);
        self.rigidbody_buffer = buffer;

        // Get memory requirements and allocate
        var mem_requirements: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, buffer, &mem_requirements);

        const alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        
        const alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = &alloc_flags_info,
            .allocation_size = mem_requirements.size,
            .memory_type_index = try self.findMemoryType(mem_requirements.memory_type_bits, .{ .host_visible_bit = true, .host_coherent_bit = true }),
        };

        var memory: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &alloc_info, null, &memory);
        self.rigidbody_memory = memory;

        _ = dispatch.vkBindBufferMemory.?(device, buffer, memory, 0);

        // Create collision pairs buffer with device address support
        const collision_pairs_size = @sizeOf(u64) * MAX_COLLISION_PAIRS;
        const pairs_buffer_info = vk.BufferCreateInfo{
            .size = collision_pairs_size,
            .usage = .{ 
                .storage_buffer_bit = true, 
                .shader_device_address_bit = true,
                .transfer_dst_bit = true,  // Required for vkCmdFillBuffer
            },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        var pairs_buffer: vk.Buffer = undefined;
        _ = dispatch.vkCreateBuffer.?(device, &pairs_buffer_info, null, &pairs_buffer);
        self.collision_pairs_buffer = pairs_buffer;

        var pairs_mem_requirements: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, pairs_buffer, &pairs_mem_requirements);

        const pairs_alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        
        const pairs_alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = &pairs_alloc_flags_info,
            .allocation_size = pairs_mem_requirements.size,
            .memory_type_index = try self.findMemoryType(pairs_mem_requirements.memory_type_bits, .{ .device_local_bit = true }),
        };

        var pairs_memory: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &pairs_alloc_info, null, &pairs_memory);
        self.collision_pairs_memory = pairs_memory;

        _ = dispatch.vkBindBufferMemory.?(device, pairs_buffer, pairs_memory, 0);

        // Create contact buffer
        // ContactInfo struct is vec3 position + float penetration + vec3 normal + float padding = 32 bytes
        // Plus 4 bytes for contact count at the beginning
        const contact_buffer_size = 4 + (32 * MAX_CONTACTS);
        const contact_buffer_info = vk.BufferCreateInfo{
            .size = contact_buffer_size,
            .usage = .{ 
                .storage_buffer_bit = true, 
                .shader_device_address_bit = true,
                .transfer_dst_bit = true,  // Required for vkCmdFillBuffer
            },
            .sharing_mode = .exclusive,
            .queue_family_index_count = 0,
            .p_queue_family_indices = undefined,
        };

        var contact_buf: vk.Buffer = undefined;
        _ = dispatch.vkCreateBuffer.?(device, &contact_buffer_info, null, &contact_buf);
        self.contact_buffer = contact_buf;

        var contact_mem_requirements: vk.MemoryRequirements = undefined;
        dispatch.vkGetBufferMemoryRequirements.?(device, contact_buf, &contact_mem_requirements);

        const contact_alloc_flags_info = vk.MemoryAllocateFlagsInfo{
            .s_type = .memory_allocate_flags_info,
            .p_next = null,
            .flags = .{ .device_address_bit = true },
            .device_mask = 0,
        };
        
        const contact_alloc_info = vk.MemoryAllocateInfo{
            .s_type = .memory_allocate_info,
            .p_next = &contact_alloc_flags_info,
            .allocation_size = contact_mem_requirements.size,
            .memory_type_index = try self.findMemoryType(contact_mem_requirements.memory_type_bits, .{ .device_local_bit = true }),
        };

        var contact_mem: vk.DeviceMemory = undefined;
        _ = dispatch.vkAllocateMemory.?(device, &contact_alloc_info, null, &contact_mem);
        self.contact_memory = contact_mem;

        _ = dispatch.vkBindBufferMemory.?(device, contact_buf, contact_mem, 0);

        std.debug.print("Physics GPU buffers created successfully\n", .{});
    }

    fn loadShaderModule(self: *PhysicsEngine, comptime path: []const u8) !vk.ShaderModule {
        const shader_code = @embedFile(path);
        
        const create_info = vk.ShaderModuleCreateInfo{
            .code_size = shader_code.len,
            .p_code = @ptrCast(@alignCast(shader_code.ptr)),
        };
        
        var shader_module: vk.ShaderModule = .null_handle;
        const dispatch = self.device_dispatch orelse return error.NoDispatch;
        const device = self.device orelse return error.NoDevice;
        const result = dispatch.vkCreateShaderModule.?(device, &create_info, null, &shader_module);
        
        if (result != .success) {
            return error.ShaderModuleCreationFailed;
        }
        
        return shader_module;
    }

    fn createComputePipelines(self: *PhysicsEngine) !void {
        const device = self.device orelse return error.NoDevice;
        const dispatch = self.device_dispatch orelse return error.NoDispatch;

        std.debug.print("Creating physics pipelines with PipelineManager\n", .{});

        // Create pipeline manager
        self.pipeline_manager = try self.allocator.create(PipelineManager.PipelineManager);
        self.pipeline_manager.?.* = try PipelineManager.PipelineManager.init(
            self.allocator,
            device,
            dispatch.*
        );

        // Push constant size for physics pipelines
        const push_constant_size = @sizeOf(PhysicsPushConstants);

        // Load shader SPIRVs
        const integration_code align(4) = @embedFile("physics_integration.comp.spirv").*;
        const broadphase_code align(4) = @embedFile("physics_broadphase.comp.spirv").*;
        const narrowphase_code align(4) = @embedFile("physics_narrowphase.comp.spirv").*;
        const resolve_code align(4) = @embedFile("physics_resolve.comp.spirv").*;

        // Create pipelines with device address support
        self.integration_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            self.pipeline_manager.?,
            std.mem.bytesAsSlice(u32, &integration_code),
            push_constant_size
        );

        self.broad_phase_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            self.pipeline_manager.?,
            std.mem.bytesAsSlice(u32, &broadphase_code),
            push_constant_size
        );

        self.narrow_phase_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            self.pipeline_manager.?,
            std.mem.bytesAsSlice(u32, &narrowphase_code),
            push_constant_size
        );

        self.resolve_pipeline = try PipelineManager.DeviceAddressPipeline.create(
            self.pipeline_manager.?,
            std.mem.bytesAsSlice(u32, &resolve_code),
            push_constant_size
        );

        std.debug.print("Physics compute pipelines created successfully\n", .{});
    }

    fn allocateCommandBuffer(self: *PhysicsEngine) !void {
        const device = self.device orelse return error.NoDevice;
        const pool = self.command_pool orelse return error.NoCommandPool;
        const dispatch = self.device_dispatch orelse return error.NoDispatch;

        const alloc_info = vk.CommandBufferAllocateInfo{
            .command_pool = pool,
            .level = .primary,
            .command_buffer_count = 1,
        };

        std.debug.print("Allocating physics command buffer\n", .{});
        var cmd_buffer: vk.CommandBuffer = undefined;
        _ = dispatch.vkAllocateCommandBuffers.?(device, &alloc_info, @as([*]vk.CommandBuffer, @ptrCast(&cmd_buffer)));
        self.compute_command_buffer = cmd_buffer;

        // No descriptor sets needed with device address approach
        
        std.debug.print("Physics command buffer allocated successfully\n", .{});
    }

    pub fn createRigidBody(self: *PhysicsEngine) !RigidBodyHandle {
        var index: u32 = undefined;

        // Reuse freed slot or allocate new
        if (self.free_list.items.len > 0) {
            index = self.free_list.pop() orelse return error.NoFreeSlots;
        } else {
            index = @intCast(self.rigidbodies.items.len);
            try self.rigidbodies.append(.{
                .position = Vec3f.zero(),
                .orientation = Quat.identity(),
                .prev_position = Vec3f.zero(),
                .prev_orientation = Quat.identity(),
                .mass = 1.0,
                .inv_mass = 1.0,
                .friction = 0.5,
                .restitution = 0.3,
                .linear_damping = 0.99,
                .angular_damping = 0.99,
                .angular_moment = Vec3f{ .x = 1, .y = 1, .z = 1 },
                .center_of_mass = Vec3f.zero(),
                .half_extents = Vec3f{ .x = 0.5, .y = 0.5, .z = 0.5 },
                .force_accumulator = Vec3f.zero(),
                .torque_accumulator = Vec3f.zero(),
                .collision_normal = Vec3f.zero(),
                .collision_depth = 0,
                .is_static = 0,
                .is_active = 1,
                .padding = .{ 0, 0 },
            });
            try self.handles.append(.{
                .index = index,
                .generation = self.generation_counter,
            });
        }

        self.generation_counter += 1;
        self.handles.items[index].generation = self.generation_counter;

        return self.handles.items[index];
    }

    pub fn destroyRigidBody(self: *PhysicsEngine, handle: RigidBodyHandle) void {
        if (handle.index >= self.handles.items.len or
            self.handles.items[handle.index].generation != handle.generation)
        {
            return;
        }

        self.rigidbodies.items[handle.index].is_active = 0;
        self.free_list.append(handle.index) catch {};
    }

    pub fn setMass(self: *PhysicsEngine, handle: RigidBodyHandle, mass: f32) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        body.mass = mass;
        body.inv_mass = if (mass > 0) 1.0 / mass else 0.0;
        body.is_static = if (mass == 0) 1 else 0;
    }

    pub fn setPosition(self: *PhysicsEngine, handle: RigidBodyHandle, position: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        // For Verlet integration, setting position updates both current and previous
        body.position = position;
        body.prev_position = position;
    }

    pub fn move(self: *PhysicsEngine, handle: RigidBodyHandle, new_position: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        // Verlet integration: new position implies velocity
        body.prev_position = body.position;
        body.position = new_position;
    }

    pub fn applyForce(self: *PhysicsEngine, handle: RigidBodyHandle, force: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        body.force_accumulator = body.force_accumulator.add(force);
    }
    
    pub fn applyForceAtPoint(self: *PhysicsEngine, handle: RigidBodyHandle, force: Vec3f, point: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        
        // Apply force to linear accumulator
        body.force_accumulator = body.force_accumulator.add(force);
        
        // Calculate torque from off-center force
        // torque = (point - (position + center_of_mass)) × force
        const world_com = body.position.add(body.center_of_mass);
        const r = point.sub(world_com);
        
        // Cross product r × force
        const torque = Vec3f{
            .x = r.y * force.z - r.z * force.y,
            .y = r.z * force.x - r.x * force.z,
            .z = r.x * force.y - r.y * force.x,
        };
        
        body.torque_accumulator = body.torque_accumulator.add(torque);
    }

    pub fn applyImpulse(self: *PhysicsEngine, handle: RigidBodyHandle, impulse: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        // For Verlet, impulse directly modifies position
        const delta = impulse.scale(body.inv_mass);
        body.position = body.position.add(delta);
    }
    
    pub fn applyImpulseAtPoint(self: *PhysicsEngine, handle: RigidBodyHandle, impulse: Vec3f, point: Vec3f) void {
        if (handle.index >= self.rigidbodies.items.len) return;
        var body = &self.rigidbodies.items[handle.index];
        
        // Apply linear impulse
        const delta = impulse.scale(body.inv_mass);
        body.position = body.position.add(delta);
        
        // Calculate angular impulse from off-center impulse
        // angular_impulse = (point - (position + center_of_mass)) × impulse
        const world_com = body.position.add(body.center_of_mass);
        const r = point.sub(world_com);
        
        // Cross product r × impulse
        const angular_impulse = Vec3f{
            .x = r.y * impulse.z - r.z * impulse.y,
            .y = r.z * impulse.x - r.x * impulse.z,
            .z = r.x * impulse.y - r.y * impulse.x,
        };
        
        // For angular impulse, we need to directly update the orientation
        // Convert angular impulse to angular velocity change
        const angular_delta = Vec3f{
            .x = angular_impulse.x / body.angular_moment.x,
            .y = angular_impulse.y / body.angular_moment.y,
            .z = angular_impulse.z / body.angular_moment.z,
        };
        
        // Apply as small rotation
        const angle = @sqrt(angular_delta.x * angular_delta.x + 
                          angular_delta.y * angular_delta.y + 
                          angular_delta.z * angular_delta.z);
        
        if (angle > 0.0001) {
            const inv_angle = 1.0 / angle;
            const axis = Vec3f{
                .x = angular_delta.x * inv_angle,
                .y = angular_delta.y * inv_angle,
                .z = angular_delta.z * inv_angle,
            };
            
            const half_angle = angle * 0.5;
            const s = @sin(half_angle);
            const c = @cos(half_angle);
            const rotation = Quat{
                .x = axis.x * s,
                .y = axis.y * s,
                .z = axis.z * s,
                .w = c,
            };
            
            body.orientation = quatNormalize(quatMul(rotation, body.orientation));
        }
    }

    pub fn step(self: *PhysicsEngine, delta_time: f32) void {
        const dt = delta_time / @as(f32, @floatFromInt(self.substeps));

        var substep: u32 = 0;
        while (substep < self.substeps) : (substep += 1) {
            if (self.device != null) {
                // GPU path
                self.stepGPU(dt);
            } else {
                // CPU fallback
                self.stepCPU(dt);
            }
        }
    }

    fn stepCPU(self: *PhysicsEngine, dt: f32) void {
        // Clear collision state from previous frame
        for (self.rigidbodies.items) |*body| {
            body.collision_normal = Vec3f.zero();
            body.collision_depth = 0;
        }

        // Apply forces and integrate positions
        for (self.rigidbodies.items) |*body| {
            if (body.is_active == 0 or body.is_static == 1) continue;

            // Apply gravity
            const gravity_force = self.gravity.scale(body.mass);
            body.force_accumulator = body.force_accumulator.add(gravity_force);

            // Verlet integration for linear motion
            const acceleration = body.force_accumulator.scale(body.inv_mass);
            
            // Calculate velocity for damping
            const velocity = body.position.sub(body.prev_position).scale(1.0 / dt);
            const damped_velocity = velocity.scale(body.linear_damping);
            
            // Standard Verlet integration with damped velocity
            const new_position = body.position
                .add(damped_velocity.scale(dt))
                .add(acceleration.scale(dt * dt));

            body.prev_position = body.position;
            body.position = new_position;

            // Angular integration if there's torque
            if (body.torque_accumulator.x != 0 or body.torque_accumulator.y != 0 or body.torque_accumulator.z != 0) {
                // Convert torque to angular acceleration
                const angular_acceleration = Vec3f{
                    .x = body.torque_accumulator.x / body.angular_moment.x,
                    .y = body.torque_accumulator.y / body.angular_moment.y,
                    .z = body.torque_accumulator.z / body.angular_moment.z,
                };
                
                // Compute angular velocity from orientation difference
                const q_current = body.orientation;
                const q_prev = body.prev_orientation;
                
                // Conjugate of previous quaternion
                const q_prev_conj = Quat{ .x = -q_prev.x, .y = -q_prev.y, .z = -q_prev.z, .w = q_prev.w };
                
                // Quaternion difference: q_delta = q_current * q_prev^-1
                const q_delta = quatMul(q_current, q_prev_conj);
                
                // Extract angular velocity (2 * q_delta.xyz / dt)
                var angular_velocity = Vec3f{
                    .x = 2.0 * q_delta.x / dt,
                    .y = 2.0 * q_delta.y / dt,
                    .z = 2.0 * q_delta.z / dt,
                };
                
                // Apply angular acceleration
                angular_velocity = angular_velocity.add(angular_acceleration.scale(dt));
                
                // Apply angular damping
                angular_velocity = angular_velocity.scale(body.angular_damping);
                
                // Integrate orientation
                const angle = @sqrt(angular_velocity.x * angular_velocity.x + 
                                  angular_velocity.y * angular_velocity.y + 
                                  angular_velocity.z * angular_velocity.z) * dt;
                
                if (angle > 0.0001) {
                    // Normalize axis
                    const inv_len = 1.0 / (angle / dt);
                    const axis = Vec3f{
                        .x = angular_velocity.x * inv_len,
                        .y = angular_velocity.y * inv_len,
                        .z = angular_velocity.z * inv_len,
                    };
                    
                    // Create rotation quaternion
                    const half_angle = angle * 0.5;
                    const s = @sin(half_angle);
                    const c = @cos(half_angle);
                    const rotation_delta = Quat{
                        .x = axis.x * s,
                        .y = axis.y * s,
                        .z = axis.z * s,
                        .w = c,
                    };
                    
                    // Update orientation
                    body.prev_orientation = body.orientation;
                    body.orientation = quatNormalize(quatMul(rotation_delta, body.orientation));
                }
            }

            // Clear force and torque accumulators
            body.force_accumulator = Vec3f.zero();
            body.torque_accumulator = Vec3f.zero();
        }

        // Simple collision detection and response
        for (self.rigidbodies.items, 0..) |*body_a, i| {
            if (body_a.is_active == 0) continue;

            for (self.rigidbodies.items[i + 1 ..], i + 1..) |*body_b, j| {
                _ = j;
                if (body_b.is_active == 0) continue;
                if (body_a.is_static == 1 and body_b.is_static == 1) continue;

                // Simple AABB vs AABB collision
                const min_a = body_a.position.sub(body_a.half_extents);
                const max_a = body_a.position.add(body_a.half_extents);
                const min_b = body_b.position.sub(body_b.half_extents);
                const max_b = body_b.position.add(body_b.half_extents);

                // Check overlap on all axes
                if (min_a.x <= max_b.x and max_a.x >= min_b.x and
                    min_a.y <= max_b.y and max_a.y >= min_b.y and
                    min_a.z <= max_b.z and max_a.z >= min_b.z)
                {
                    // Calculate penetration depth
                    const overlap_x = @min(max_a.x - min_b.x, max_b.x - min_a.x);
                    const overlap_y = @min(max_a.y - min_b.y, max_b.y - min_a.y);
                    const overlap_z = @min(max_a.z - min_b.z, max_b.z - min_a.z);

                    // Find minimum penetration axis
                    var normal = Vec3f.zero();
                    var depth: f32 = 0;

                    if (overlap_x < overlap_y and overlap_x < overlap_z) {
                        depth = overlap_x;
                        normal.x = if (body_a.position.x < body_b.position.x) -1.0 else 1.0;
                    } else if (overlap_y < overlap_z) {
                        depth = overlap_y;
                        normal.y = if (body_a.position.y < body_b.position.y) -1.0 else 1.0;
                    } else {
                        depth = overlap_z;
                        normal.z = if (body_a.position.z < body_b.position.z) -1.0 else 1.0;
                    }

                    // Apply collision response
                    if (body_a.is_static == 0 and body_b.is_static == 1) {
                        // Move dynamic body A away from static body B
                        body_a.position = body_a.position.add(normal.scale(depth));
                        body_a.collision_normal = normal;
                        body_a.collision_depth = depth;
                    } else if (body_a.is_static == 1 and body_b.is_static == 0) {
                        // Move dynamic body B away from static body A
                        body_b.position = body_b.position.sub(normal.scale(depth));
                        body_b.collision_normal = normal.scale(-1.0);
                        body_b.collision_depth = depth;
                    } else {
                        // Both dynamic - move both equally
                        const half_depth = depth * 0.5;
                        body_a.position = body_a.position.add(normal.scale(half_depth));
                        body_b.position = body_b.position.sub(normal.scale(half_depth));
                        body_a.collision_normal = normal;
                        body_b.collision_normal = normal.scale(-1.0);
                        body_a.collision_depth = depth;
                        body_b.collision_depth = depth;
                    }
                }
            }
        }
    }

    fn stepGPU(self: *PhysicsEngine, dt: f32) void {
        const device = self.device orelse return self.stepCPU(dt);
        const dispatch = self.device_dispatch orelse return self.stepCPU(dt);
        const cmd = self.compute_command_buffer orelse return self.stepCPU(dt);
        const pipeline_manager = self.pipeline_manager orelse return self.stepCPU(dt);
        
        // Get buffer device addresses
        const rb_addr = pipeline_manager.*.getBufferDeviceAddress(self.rigidbody_buffer.?);
        const pairs_addr = pipeline_manager.*.getBufferDeviceAddress(self.collision_pairs_buffer.?);
        const contacts_addr = pipeline_manager.*.getBufferDeviceAddress(self.contact_buffer.?);
        
        // Setup push constants
        const push_constants = PhysicsPushConstants{
            .rigidbodies_address = rb_addr,
            .collision_pairs_address = pairs_addr,
            .contacts_address = contacts_addr,
            .delta_time = dt,
            .gravity_x = self.gravity.x,
            .gravity_y = self.gravity.y,
            .gravity_z = self.gravity.z,
            .body_count = @intCast(self.rigidbodies.items.len),
            .substeps = self.substeps,
        };
        
        // Begin command buffer
        const begin_info = vk.CommandBufferBeginInfo{
            .flags = .{ .one_time_submit_bit = true },
            .p_inheritance_info = null,
        };
        _ = dispatch.vkBeginCommandBuffer.?(cmd, &begin_info);
        
        // Upload rigidbody data
        var mapped_ptr: ?*anyopaque = null;
        _ = dispatch.vkMapMemory.?(device, self.rigidbody_memory.?, 0, vk.WHOLE_SIZE, .{}, &mapped_ptr);
        if (mapped_ptr) |ptr| {
            const dst = @as([*]RigidBodyGPU, @ptrCast(@alignCast(ptr)));
            @memcpy(dst[0..self.rigidbodies.items.len], self.rigidbodies.items);
            dispatch.vkUnmapMemory.?(device, self.rigidbody_memory.?);
        }
        
        // Clear contact count (first u32 in contact buffer)
        const zero: u32 = 0;
        dispatch.vkCmdFillBuffer.?(cmd, self.contact_buffer.?, 0, 4, zero);
        
        // Memory barrier
        const barrier = vk.MemoryBarrier{
            .src_access_mask = .{ .host_write_bit = true, .transfer_write_bit = true },
            .dst_access_mask = .{ .shader_read_bit = true, .shader_write_bit = true },
        };
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .host_bit = true, .transfer_bit = true },
            .{ .compute_shader_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&barrier)),
            0,
            null,
            0,
            null
        );
        
        // 1. Broad phase - find potential collisions
        if (self.broad_phase_pipeline) |*pipeline| {
            pipeline.bind(cmd);
            pipeline.pushConstants(cmd, &push_constants, @sizeOf(PhysicsPushConstants));
            const groups = (@as(u32, @intCast(self.rigidbodies.items.len)) + 63) / 64;
            pipeline.dispatch(cmd, groups, 1, 1);
        }
        
        // Barrier between broad and narrow phase
        const compute_barrier = vk.MemoryBarrier{
            .src_access_mask = .{ .shader_write_bit = true },
            .dst_access_mask = .{ .shader_read_bit = true, .shader_write_bit = true },
        };
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .compute_shader_bit = true },
            .{ .compute_shader_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&compute_barrier)),
            0,
            null,
            0,
            null
        );
        
        // 2. Narrow phase - test actual collisions
        if (self.narrow_phase_pipeline) |*pipeline| {
            pipeline.bind(cmd);
            pipeline.pushConstants(cmd, &push_constants, @sizeOf(PhysicsPushConstants));
            const groups = (MAX_COLLISION_PAIRS + 63) / 64;
            pipeline.dispatch(cmd, groups, 1, 1);
        }
        
        // Barrier before resolution
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .compute_shader_bit = true },
            .{ .compute_shader_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&compute_barrier)),
            0,
            null,
            0,
            null
        );
        
        // 3. Collision resolution
        if (self.resolve_pipeline) |*pipeline| {
            pipeline.bind(cmd);
            pipeline.pushConstants(cmd, &push_constants, @sizeOf(PhysicsPushConstants));
            const groups = (MAX_CONTACTS + 63) / 64;
            pipeline.dispatch(cmd, groups, 1, 1);
        }
        
        // Barrier before integration
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .compute_shader_bit = true },
            .{ .compute_shader_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&compute_barrier)),
            0,
            null,
            0,
            null
        );
        
        // 4. Integration - update positions
        if (self.integration_pipeline) |*pipeline| {
            pipeline.bind(cmd);
            pipeline.pushConstants(cmd, &push_constants, @sizeOf(PhysicsPushConstants));
            const groups = (@as(u32, @intCast(self.rigidbodies.items.len)) + 63) / 64;
            pipeline.dispatch(cmd, groups, 1, 1);
        }
        
        // Final barrier before readback
        const readback_barrier = vk.MemoryBarrier{
            .src_access_mask = .{ .shader_write_bit = true },
            .dst_access_mask = .{ .host_read_bit = true },
        };
        dispatch.vkCmdPipelineBarrier.?(
            cmd,
            .{ .compute_shader_bit = true },
            .{ .host_bit = true },
            .{},
            1,
            @as([*]const vk.MemoryBarrier, @ptrCast(&readback_barrier)),
            0,
            null,
            0,
            null
        );
        
        // End command buffer
        _ = dispatch.vkEndCommandBuffer.?(cmd);
        
        // Submit work
        const submit_info = vk.SubmitInfo{
            .wait_semaphore_count = 0,
            .p_wait_semaphores = undefined,
            .p_wait_dst_stage_mask = undefined,
            .command_buffer_count = 1,
            .p_command_buffers = @as([*]const vk.CommandBuffer, @ptrCast(&cmd)),
            .signal_semaphore_count = 0,
            .p_signal_semaphores = undefined,
        };
        
        _ = dispatch.vkQueueSubmit.?(self.compute_queue.?, 1, @as([*]const vk.SubmitInfo, @ptrCast(&submit_info)), .null_handle);
        _ = dispatch.vkQueueWaitIdle.?(self.compute_queue.?);
        
        // Read back rigidbody data
        _ = dispatch.vkMapMemory.?(device, self.rigidbody_memory.?, 0, vk.WHOLE_SIZE, .{}, &mapped_ptr);
        if (mapped_ptr) |ptr| {
            const src = @as([*]const RigidBodyGPU, @ptrCast(@alignCast(ptr)));
            @memcpy(self.rigidbodies.items, src[0..self.rigidbodies.items.len]);
            dispatch.vkUnmapMemory.?(device, self.rigidbody_memory.?);
        }
    }

    fn findMemoryType(self: *PhysicsEngine, type_filter: u32, properties: vk.MemoryPropertyFlags) !u32 {
        const physical_device = self.physical_device orelse return error.NoPhysicalDevice;
        const instance_dispatch = self.instance_dispatch orelse return error.NoInstanceDispatch;

        var mem_properties: vk.PhysicalDeviceMemoryProperties = undefined;
        instance_dispatch.vkGetPhysicalDeviceMemoryProperties.?(physical_device, &mem_properties);

        for (0..mem_properties.memory_type_count) |i| {
            const suitable_type = (type_filter & (@as(u32, 1) << @intCast(i))) != 0;
            const suitable_properties = mem_properties.memory_types[i].property_flags.contains(properties);

            if (suitable_type and suitable_properties) {
                return @intCast(i);
            }
        }

        return error.NoSuitableMemoryType;
    }
};

// C-compatible exports for FFI
export fn physics_engine_create() ?*PhysicsEngine {
    const allocator = std.heap.c_allocator;
    return PhysicsEngine.init(allocator) catch return null;
}

export fn physics_engine_destroy(engine: *PhysicsEngine) void {
    engine.deinit();
}

export fn physics_engine_init_gpu(engine: *PhysicsEngine, device: vk.Device, command_pool: vk.CommandPool, queue: vk.Queue) void {
    engine.initGPU(device, command_pool, queue) catch {};
}

export fn physics_engine_set_dispatch_tables(
    engine: *PhysicsEngine,
    device_dispatch: *const vk.DeviceDispatch,
    physical_device: vk.PhysicalDevice,
    instance_dispatch: *const vk.InstanceDispatch,
) void {
    engine.device_dispatch = device_dispatch;
    engine.physical_device = physical_device;
    engine.instance_dispatch = instance_dispatch;
}

export fn physics_engine_step(engine: *PhysicsEngine, delta_time: f32) void {
    engine.step(delta_time);
}

export fn rigidbody_create(engine: *PhysicsEngine) u64 {
    const handle = engine.createRigidBody() catch return 0;
    // Pack handle into u64 (index in low 32 bits, generation in high 32 bits)
    return (@as(u64, handle.generation) << 32) | handle.index;
}

export fn rigidbody_destroy(engine: *PhysicsEngine, handle: u64) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.destroyRigidBody(rb_handle);
}

export fn rigidbody_set_mass(engine: *PhysicsEngine, handle: u64, mass: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.setMass(rb_handle, mass);
}

export fn rigidbody_set_friction(engine: *PhysicsEngine, handle: u64, friction: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].friction = friction;
}

export fn rigidbody_set_restitution(engine: *PhysicsEngine, handle: u64, restitution: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].restitution = restitution;
}

export fn rigidbody_set_linear_damping(engine: *PhysicsEngine, handle: u64, damping: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].linear_damping = damping;
}

export fn rigidbody_set_angular_damping(engine: *PhysicsEngine, handle: u64, damping: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].angular_damping = damping;
}

export fn rigidbody_set_angular_moment(engine: *PhysicsEngine, handle: u64, moment: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].angular_moment = moment;
}

export fn rigidbody_set_center_of_mass(engine: *PhysicsEngine, handle: u64, com: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].center_of_mass = com;
}

export fn rigidbody_set_half_extents(engine: *PhysicsEngine, handle: u64, half_extents: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].half_extents = half_extents;
}

export fn rigidbody_reposition(engine: *PhysicsEngine, handle: u64, position: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.setPosition(rb_handle, position);
}

export fn rigidbody_orient(engine: *PhysicsEngine, handle: u64, x: f32, y: f32, z: f32, w: f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    engine.rigidbodies.items[rb_handle.index].orientation = Quat{ .x = x, .y = y, .z = z, .w = w };
    engine.rigidbodies.items[rb_handle.index].prev_orientation = Quat{ .x = x, .y = y, .z = z, .w = w };
}

export fn rigidbody_move(engine: *PhysicsEngine, handle: u64, position: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.move(rb_handle, position);
}

export fn rigidbody_accelerate(engine: *PhysicsEngine, handle: u64, acceleration: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    const body = &engine.rigidbodies.items[rb_handle.index];
    const force = acceleration.scale(body.mass);
    engine.applyForce(rb_handle, force);
}

export fn rigidbody_impulse(engine: *PhysicsEngine, handle: u64, impulse: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.applyImpulse(rb_handle, impulse);
}

export fn rigidbody_angular_impulse(engine: *PhysicsEngine, handle: u64, angular_impulse: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return;
    
    // Apply angular impulse to torque accumulator
    const body = &engine.rigidbodies.items[rb_handle.index];
    body.torque_accumulator = body.torque_accumulator.add(angular_impulse);
}

export fn rigidbody_get_position(engine: *PhysicsEngine, handle: u64) Vec3f {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return Vec3f.zero();
    return engine.rigidbodies.items[rb_handle.index].position;
}

export fn rigidbody_get_orientation(engine: *PhysicsEngine, handle: u64, out_x: *f32, out_y: *f32, out_z: *f32, out_w: *f32) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) {
        out_x.* = 0;
        out_y.* = 0;
        out_z.* = 0;
        out_w.* = 1;
        return;
    }
    const orientation = engine.rigidbodies.items[rb_handle.index].orientation;
    out_x.* = orientation.x;
    out_y.* = orientation.y;
    out_z.* = orientation.z;
    out_w.* = orientation.w;
}

export fn rigidbody_get_linear_velocity(engine: *PhysicsEngine, handle: u64) Vec3f {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return Vec3f.zero();
    
    const body = &engine.rigidbodies.items[rb_handle.index];
    // Velocity from Verlet integration: v = (position - prev_position) / dt
    // Since we don't store dt, we return the difference (caller should divide by their dt)
    return body.position.sub(body.prev_position);
}

export fn rigidbody_apply_force_at_point(engine: *PhysicsEngine, handle: u64, force: Vec3f, point: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.applyForceAtPoint(rb_handle, force, point);
}

export fn rigidbody_apply_impulse_at_point(engine: *PhysicsEngine, handle: u64, impulse: Vec3f, point: Vec3f) void {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    engine.applyImpulseAtPoint(rb_handle, impulse, point);
}

export fn rigidbody_get_angular_velocity(engine: *PhysicsEngine, handle: u64) Vec3f {
    const rb_handle = RigidBodyHandle{
        .index = @truncate(handle),
        .generation = @truncate(handle >> 32),
    };
    if (rb_handle.index >= engine.rigidbodies.items.len) return Vec3f.zero();
    
    const body = &engine.rigidbodies.items[rb_handle.index];
    // Calculate angular velocity from quaternion difference
    // This is an approximation: w = 2 * (q_current * q_prev^-1).xyz / dt
    const q_current = body.orientation;
    const q_prev = body.prev_orientation;
    
    // Conjugate of previous quaternion (inverse for unit quaternions)
    const q_prev_conj = Quat{ .x = -q_prev.x, .y = -q_prev.y, .z = -q_prev.z, .w = q_prev.w };
    
    // Quaternion difference: q_delta = q_current * q_prev^-1
    const q_delta = quatMul(q_current, q_prev_conj);
    
    // Extract angular velocity (scaled by 2, caller should divide by dt)
    return Vec3f{ .x = q_delta.x * 2, .y = q_delta.y * 2, .z = q_delta.z * 2 };
}

// Helper function for quaternion multiplication
fn quatMul(a: Quat, b: Quat) Quat {
    return .{
        .x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        .y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        .z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
        .w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
    };
}

// Helper function for quaternion normalization
fn quatNormalize(q: Quat) Quat {
    const len = @sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w);
    if (len > 0.0) {
        const inv_len = 1.0 / len;
        return .{
            .x = q.x * inv_len,
            .y = q.y * inv_len,
            .z = q.z * inv_len,
            .w = q.w * inv_len,
        };
    } else {
        return Quat.identity();
    }
}
