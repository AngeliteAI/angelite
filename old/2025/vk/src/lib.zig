// Vulkan abstraction library for Zig
// This library provides an ergonomic wrapper around Vulkan API

pub const core = @import("core.zig");
pub const instance = @import("instance.zig");
pub const device = @import("device.zig");
pub const swapchain = @import("swapchain.zig");
pub const commands = @import("commands.zig");
pub const pipeline = @import("pipeline.zig");
pub const memory = @import("memory.zig");
pub const sync = @import("sync.zig");
pub const errors = @import("errors.zig");

pub const raw = @import("raw.zig");

// Re-export the most commonly used types
pub const Instance = instance.Instance;
pub const Device = device.Device;
pub const PhysicalDevice = device.PhysicalDevice;
pub const Swapchain = swapchain.Swapchain;
pub const CommandPool = commands.CommandPool;
pub const CommandBuffer = commands.CommandBuffer;
pub const Pipeline = pipeline.Pipeline;
pub const Buffer = memory.Buffer;
pub const Image = memory.Image;
pub const Fence = sync.Fence;
pub const Semaphore = sync.Semaphore;

// Common error type
pub const Error = errors.Error;
