const std = @import("std");
const vk = @import("vk.zig");
const logger = @import("../logger.zig");

pub const HeapError = error{
    AllocationFailed,
    OutOfMemory,
    GrowthFailed,
};

/// Heap is a dynamic allocation abstraction for Vulkan buffers
pub const Heap = struct {
    device: vk.Device,
    physical_device: vk.PhysicalDevice,
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,
    size: vk.DeviceSize,
    usage: vk.BufferUsageFlags,
    memory_properties: vk.MemoryPropertyFlags,
    device_address: u64,
    mutex: std.Thread.Mutex,

    /// Create a new heap with a buffer of the specified initial size
    pub fn create(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        size: vk.DeviceSize,
        usage: vk.BufferUsageFlags,
        memory_properties: vk.MemoryPropertyFlags,
        allocator: *std.mem.Allocator,
    ) !*Heap {
        logger.info("[HEAP] Creating heap with size: {d}, usage: {any}", .{ size, usage });
        var heap = try allocator.create(Heap);
        heap.* = Heap{
            .device = device,
            .physical_device = physical_device,
            .buffer = undefined,
            .memory = undefined,
            .size = size,
            .usage = usage,
            .memory_properties = memory_properties,
            .device_address = 0,
            .mutex = std.Thread.Mutex{},
        };

        // Create the buffer with explicit device address usage
        const buffer_info = vk.BufferCreateInfo{
            .sType = vk.sTy(.BufferCreateInfo),
            .pNext = null,
            .size = size,
            .usage = usage | vk.BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            .sharingMode = vk.SHARING_MODE_EXCLUSIVE,
        };

        const result = vk.createBuffer(device, &buffer_info, null, &heap.buffer);
        if (result != vk.SUCCESS) {
            logger.err("[HEAP] Buffer creation failed", .{});
            return error.VulkanError;
        }
        logger.info("[HEAP] Buffer created successfully: {any}", .{heap.buffer});
        errdefer vk.destroyBuffer(device, heap.buffer, null);

        // Get memory requirements
        var memory_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(device, heap.buffer, &memory_requirements);
        logger.debug("[HEAP] Buffer memory requirements - size: {d}, alignment: {d}, memoryTypeBits: {b}", .{ memory_requirements.size, memory_requirements.alignment, memory_requirements.memoryTypeBits });

        // Get memory properties
        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties_info);
        logger.debug("[HEAP] Physical device has {d} memory types", .{memory_properties_info.memoryTypeCount});

        // Find suitable memory type
        const memory_type_index = try findMemoryType(physical_device, memory_requirements.memoryTypeBits, memory_properties);
        logger.debug("[HEAP] Found suitable memory type index: {d}", .{memory_type_index});

        // Allocate memory with device address flag
        const device_address_info = vk.MemoryAllocateFlagsInfo{
            .sType = vk.sTy(.MemoryAllocateFlagsInfo),
            .pNext = null,
            .flags = vk.MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
            .deviceMask = 0,
        };

        const memory_allocate_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = &device_address_info,
            .allocationSize = memory_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        const memory_result = vk.allocateMemory(device, &memory_allocate_info, null, &heap.memory);
        if (memory_result != vk.SUCCESS) {
            logger.err("[HEAP] Memory allocation failed", .{});
            vk.destroyBuffer(device, heap.buffer, null);
            return error.VulkanError;
        }
        logger.info("[HEAP] Memory allocated successfully: {any}", .{heap.memory});
        errdefer vk.freeMemory(device, heap.memory, null);

        // Bind memory to buffer
        const bind_result = vk.bindBufferMemory(device, heap.buffer, heap.memory, 0);
        if (bind_result != vk.SUCCESS) {
            logger.err("[HEAP] Memory binding failed", .{});
            vk.freeMemory(device, heap.memory, null);
            vk.destroyBuffer(device, heap.buffer, null);
            return error.VulkanError;
        }
        logger.info("[HEAP] Memory bound to buffer successfully", .{});

        // Get device address
        const device_address_info2 = vk.BufferDeviceAddressInfo{
            .sType = vk.sTy(.BufferDeviceAddressInfo),
            .pNext = null,
            .buffer = heap.buffer,
        };

        heap.device_address = vk.getBufferDeviceAddress(device, &device_address_info2);
        logger.info("Heap created with device address: 0x{x}", .{heap.device_address});

        std.debug.print("[HEAP] Heap created successfully with size: {d}\n", .{size});
        return heap;
    }

    /// Get the underlying buffer
    pub fn getBuffer(self: *Heap) vk.Buffer {
        return self.buffer;
    }

    /// Get the device address of the buffer for bindless access
    pub fn getDeviceAddress(self: *Heap) !u64 {
        // Lock the mutex for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        if (self.device_address == 0) {
            // Get device address if not already set
            const device_address_info = vk.BufferDeviceAddressInfo{
                .buffer = self.buffer,
            };

            self.device_address = vk.getBufferDeviceAddress(self.device, &device_address_info);
            logger.info("Retrieved device address for heap: 0x{x}", .{self.device_address});

            // Verify the address is valid
            if (self.device_address == 0) {
                logger.err("Failed to get valid device address for heap", .{});
                return error.InvalidDeviceAddress;
            }
        }

        // Double-check the address is valid before returning
        if (self.device_address == 0) {
            logger.err("Heap device address is 0, which is invalid", .{});
            return error.InvalidDeviceAddress;
        }

        logger.info("Returning heap device address: 0x{x}", .{self.device_address});
        return self.device_address;
    }

    /// Grow the heap to at least the specified size
    pub fn grow(self: *Heap, new_min_size: usize, command_buffer: vk.CommandBuffer) !void {
        logger.info("[HEAP] Attempting to grow heap from {d} to minimum size {d}", .{ self.size, new_min_size });

        // Don't grow if we're already big enough
        if (self.size >= new_min_size) {
            logger.info("[HEAP] No growth needed, current size {d} >= requested size {d}", .{ self.size, new_min_size });
            return;
        }

        // Calculate new size (grow by doubling)
        const new_size = @max(new_min_size, self.size * 2);
        logger.info("[HEAP] Growing to new size: {d}", .{new_size});

        // Create a new, larger buffer
        const buffer_create_info = vk.BufferCreateInfo{
            .sType = vk.sTy(.BufferCreateInfo),
            .pNext = null,
            .flags = 0,
            .size = new_size,
            .usage = self.usage | vk.BUFFER_USAGE_TRANSFER_DST_BIT | vk.BUFFER_USAGE_TRANSFER_SRC_BIT, // Ensure we can copy data
            .sharingMode = vk.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };
        logger.debug("[HEAP] Creating new buffer with size: {d}, usage: {any}", .{ new_size, self.usage | vk.BUFFER_USAGE_TRANSFER_DST_BIT | vk.BUFFER_USAGE_TRANSFER_SRC_BIT });

        var new_buffer: vk.Buffer = undefined;
        if (vk.createBuffer(self.device, &buffer_create_info, null, &new_buffer) != vk.SUCCESS) {
            logger.err("[HEAP] Failed to create new buffer for growth", .{});
            return error.VulkanError;
        }
        logger.info("[HEAP] New buffer created successfully: {any}", .{new_buffer});
        errdefer vk.destroyBuffer(self.device, new_buffer, null);

        // Get memory requirements
        var mem_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(self.device, new_buffer, &mem_requirements);
        logger.debug("[HEAP] New buffer memory requirements - size: {d}, alignment: {d}, memoryTypeBits: {b}", .{ mem_requirements.size, mem_requirements.alignment, mem_requirements.memoryTypeBits });

        // Get memory properties
        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(self.device, &memory_properties_info);
        logger.debug("[HEAP] Physical device has {d} memory types for growth", .{memory_properties_info.memoryTypeCount});

        // Find suitable memory type
        const memory_type_index = try findMemoryType(
            self.physical_device,
            mem_requirements.memoryTypeBits,
            self.memory_properties,
        );
        logger.debug("[HEAP] Found suitable memory type index for growth: {d}", .{memory_type_index});

        // Allocate memory
        const device_address_info = vk.MemoryAllocateFlagsInfo{
            .sType = vk.sTy(.MemoryAllocateFlagsInfo),
            .pNext = null,
            .flags = vk.MEMORY_ALLOCATE_DEVICE_ADDRESS_BIT,
            .deviceMask = 0,
        };

        const alloc_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = &device_address_info,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };
        logger.debug("[HEAP] Allocating new memory of size: {d}", .{mem_requirements.size});

        var new_memory: vk.DeviceMemory = undefined;
        if (vk.allocateMemory(self.device, &alloc_info, null, &new_memory) != vk.SUCCESS) {
            logger.err("[HEAP] Memory allocation failed for growth", .{});
            return error.VulkanError;
        }
        logger.info("[HEAP] New memory allocated successfully: {any}", .{new_memory});
        errdefer vk.freeMemory(self.device, new_memory, null);

        // Bind memory to buffer
        if (vk.bindBufferMemory(self.device, new_buffer, new_memory, 0) != vk.SUCCESS) {
            logger.err("[HEAP] Memory binding failed for growth", .{});
            return error.VulkanError;
        }
        logger.info("[HEAP] New memory bound to buffer successfully", .{});

        // Record a copy from old buffer to new buffer
        const copy_region = vk.BufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = self.size, // Copy existing content
        };
        logger.debug("[HEAP] Setting up buffer copy of {d} bytes from old to new buffer", .{self.size});

        // Begin command buffer recording if needed
        const begin_info = vk.CommandBufferBeginInfo{
            .sType = vk.sTy(.CommandBufferBeginInfo),
            .flags = vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        };

        const begin_result = vk.BeginCommandBuffer(command_buffer, &begin_info);
        if (begin_result != vk.SUCCESS) {
            logger.err("[HEAP] Failed to begin command buffer, result: {any}", .{begin_result});
            return error.VulkanError;
        }
        logger.debug("[HEAP] Command buffer recording started", .{});

        // Copy data from old buffer to new buffer
        logger.debug("[HEAP] Copying from old buffer: {any} to new buffer: {any}", .{ self.buffer, new_buffer });
        vk.CmdCopyBuffer(command_buffer, self.buffer, new_buffer, 1, &copy_region);

        // End command buffer recording
        const end_result = vk.EndCommandBuffer(command_buffer);
        if (end_result != vk.SUCCESS) {
            logger.err("[HEAP] Failed to end command buffer, result: {any}", .{end_result});
            return error.VulkanError;
        }
        logger.debug("[HEAP] Command buffer recording completed", .{});

        // Free old resources
        logger.debug("[HEAP] Freeing old buffer: {any}", .{self.buffer});
        vk.destroyBuffer(self.device, self.buffer, null);
        logger.debug("[HEAP] Freeing old memory: {any}", .{self.memory});
        vk.freeMemory(self.device, self.memory, null);

        // Update the heap with the new buffer, memory and size
        logger.info("[HEAP] Updating heap with new buffer: {any}, new memory: {any}, new size: {d}", .{ new_buffer, new_memory, new_size });
        self.buffer = new_buffer;
        self.memory = new_memory;
        self.size = new_size;
        // Reset device address since we have a new buffer
        self.device_address = 0;
        logger.info("[HEAP] Heap growth completed successfully", .{});
    }

    /// Destroy the heap and free its resources
    pub fn destroy(self: *Heap, device: vk.Device, allocator: *std.mem.Allocator) void {
        // Lock the mutex for thread safety
        self.mutex.lock();
        defer self.mutex.unlock();

        logger.info("Destroying heap with device address: 0x{x}", .{self.device_address});

        vk.freeMemory(device, self.memory, null);
        vk.destroyBuffer(device, self.buffer, null);
        allocator.destroy(self);
        logger.debug("[HEAP] Heap object destroyed", .{});
    }
};

/// Get the maximum memory allocation size for a device
pub fn getMaxAllocationSize(physical_device: vk.PhysicalDevice) u64 {
    var device_limits: vk.PhysicalDeviceProperties = undefined;
    vk.getPhysicalDeviceProperties(physical_device, &device_limits);

    // As a safety measure, don't use more than 80% of the max allocation size
    return (device_limits.limits.maxMemoryAllocationSize * 8) / 10;
}

/// Find a suitable memory type index for the requested properties
pub fn findMemoryType(
    physical_device: vk.PhysicalDevice,
    type_filter: u32,
    properties: vk.MemoryPropertyFlags,
) !u32 {
    var memory_properties: vk.PhysicalDeviceMemoryProperties = undefined;
    vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties);

    var i: u32 = 0;
    while (i < memory_properties.memoryTypeCount) : (i += 1) {
        if ((type_filter & (@as(u32, 1) << @intCast(i))) != 0 and
            (memory_properties.memoryTypes[i].propertyFlags & properties) == properties)
        {
            return i;
        }
    }

    return error.VulkanError;
}
