const std = @import("std");
const vk = @import("vk.zig");

pub const HeapError = error{
    AllocationFailed,
    OutOfMemory,
    GrowthFailed,
};

/// Heap is a dynamic allocation abstraction for Vulkan buffers
pub const Heap = struct {
    buffer: vk.Buffer,
    memory: vk.DeviceMemory,  // Added memory field
    size: usize,
    device: vk.Device,      // Store device for resize operations
    usage: vk.BufferUsageFlags, // Store usage for resize operations
    memory_properties: vk.MemoryPropertyFlags, // Store memory properties for resize
    device_address: u64 = 0, // Store the device address for bindless access
    
    /// Create a new heap with a buffer of the specified initial size
    pub fn create(
        device: vk.Device,
        physical_device: vk.PhysicalDevice,
        size: usize,
        usage: vk.BufferUsageFlags,
        memory_properties: vk.MemoryPropertyFlags,
        allocator: std.mem.Allocator,
    ) !*Heap {
        const self = try allocator.create(Heap);
        errdefer allocator.destroy(self);

        const buffer_create_info = vk.BufferCreateInfo{
            .sType = vk.sTy(.BufferCreateInfo),
            .pNext = null,
            // Add the device address bit to enable getting buffer addresses
            .flags = vk.BUFFER_CREATE_DEVICE_ADDRESS_CAPTURE_REPLAY_BIT,
            .size = size,
            // Add device address usage flag
            .usage = usage | vk.BUFFER_USAGE_SHADER_DEVICE_ADDRESS_BIT,
            .sharingMode = vk.SHARING_MODE_EXCLUSIVE,
            .queueFamilyIndexCount = 0,
            .pQueueFamilyIndices = null,
        };

        var buffer: vk.Buffer = undefined;
        if (vk.createBuffer(device, &buffer_create_info, null, &buffer) != vk.SUCCESS) {
            return HeapError.AllocationFailed;
        }
        errdefer vk.destroyBuffer(device, buffer, null);
        
        // Get memory requirements
        var mem_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(device, buffer, &mem_requirements);

        // Get memory properties
        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(physical_device, &memory_properties_info);

        // Find suitable memory type
        const memory_type_index = try findMemoryType(
            mem_requirements.memoryTypeBits,
            memory_properties,
            memory_properties_info,
        );

        // Allocate memory
        const alloc_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var memory: vk.DeviceMemory = undefined;
        if (vk.allocateMemory(device, &alloc_info, null, &memory) != vk.SUCCESS) {
            return HeapError.OutOfMemory;
        }
        errdefer vk.freeMemory(device, memory, null);

        // Bind memory to buffer
        if (vk.bindBufferMemory(device, buffer, memory, 0) != vk.SUCCESS) {
            return HeapError.AllocationFailed;
        }
        
        self.* = .{
            .buffer = buffer,
            .memory = memory,
            .size = size,
            .device = device,
            .usage = usage,
            .memory_properties = memory_properties,
        };

        return self;
    }

    /// Get the underlying buffer
    pub fn getBuffer(self: *Heap) vk.Buffer {
        return self.buffer;
    }
    
    /// Get the device address of the buffer for bindless access
    pub fn getDeviceAddress(self: *Heap) !u64 {
        // If we already have the address, return it
        if (self.device_address != 0) {
            return self.device_address;
        }
        
        // Create the device address info
        const addressInfo = vk.BufferDeviceAddressInfo{
            .sType = vk.sTy(.BufferDeviceAddressInfo),
            .pNext = null,
            .buffer = self.buffer,
        };
        
        // Get the device address
        self.device_address = vk.getBufferDeviceAddress(self.device, &addressInfo);
        return self.device_address;
    }
    
    /// Grow the heap to at least the specified size
    pub fn grow(self: *Heap, new_min_size: usize, command_buffer: vk.CommandBuffer) !void {
        // Don't grow if we're already big enough
        if (self.size >= new_min_size) return;
        
        // Calculate new size (grow by doubling)
        const new_size = @max(new_min_size, self.size * 2);
        
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
        
        var new_buffer: vk.Buffer = undefined;
        if (vk.createBuffer(self.device, &buffer_create_info, null, &new_buffer) != vk.SUCCESS) {
            return HeapError.GrowthFailed;
        }
        errdefer vk.destroyBuffer(self.device, new_buffer, null);
        
        // Get memory requirements
        var mem_requirements: vk.MemoryRequirements = undefined;
        vk.getBufferMemoryRequirements(self.device, new_buffer, &mem_requirements);

        // Get memory properties
        var memory_properties_info: vk.PhysicalDeviceMemoryProperties = undefined;
        vk.getPhysicalDeviceMemoryProperties(self.device, &memory_properties_info);

        // Find suitable memory type
        const memory_type_index = try findMemoryType(
            mem_requirements.memoryTypeBits,
            self.memory_properties,
            memory_properties_info,
        );

        // Allocate memory
        const alloc_info = vk.MemoryAllocateInfo{
            .sType = vk.sTy(.MemoryAllocateInfo),
            .pNext = null,
            .allocationSize = mem_requirements.size,
            .memoryTypeIndex = memory_type_index,
        };

        var new_memory: vk.DeviceMemory = undefined;
        if (vk.allocateMemory(self.device, &alloc_info, null, &new_memory) != vk.SUCCESS) {
            return HeapError.OutOfMemory;
        }
        errdefer vk.freeMemory(self.device, new_memory, null);

        // Bind memory to buffer
        if (vk.bindBufferMemory(self.device, new_buffer, new_memory, 0) != vk.SUCCESS) {
            return HeapError.GrowthFailed;
        }
        
        // Record a copy from old buffer to new buffer
        const copy_region = vk.BufferCopy{
            .srcOffset = 0,
            .dstOffset = 0,
            .size = self.size, // Copy existing content
        };
        
        // Begin command buffer recording if needed
        const begin_info = vk.CommandBufferBeginInfo{
            .sType = vk.sTy(.CommandBufferBeginInfo),
            .flags = vk.COMMAND_BUFFER_USAGE_ONE_TIME_SUBMIT_BIT,
            .pInheritanceInfo = null,
        };
        
        _ = vk.BeginCommandBuffer(command_buffer, &begin_info);
        
        // Copy data from old buffer to new buffer
        vk.CmdCopyBuffer(command_buffer, self.buffer, new_buffer, 1, &copy_region);
        
        // End command buffer recording
        _ = vk.EndCommandBuffer(command_buffer);
        
        // Free old resources
        vk.destroyBuffer(self.device, self.buffer, null);
        vk.freeMemory(self.device, self.memory, null);
        
        // Update the heap with the new buffer, memory and size
        self.buffer = new_buffer;
        self.memory = new_memory;
        self.size = new_size;
    }
    
    /// Destroy the heap and free its resources
    pub fn destroy(self: *Heap, device: vk.Device, allocator: std.mem.Allocator) void {
        vk.destroyBuffer(device, self.buffer, null);
        vk.freeMemory(device, self.memory, null);
        allocator.destroy(self);
    }
};

/// Find a suitable memory type index for the requested properties
pub fn findMemoryType(
    type_filter: u32,
    properties: vk.MemoryPropertyFlags,
    memory_properties: vk.PhysicalDeviceMemoryProperties,
) !u32 {
    for (0..memory_properties.memoryTypeCount) |i| {
        const type_i = @as(u32, @intCast(i));
        if ((type_filter & (@as(u32, 1) << @intCast(type_i & 0x1F)) != 0) and
            (memory_properties.memoryTypes[i].propertyFlags & properties) == properties)
        {
            return type_i;
        }
    }

    return HeapError.AllocationFailed;
}