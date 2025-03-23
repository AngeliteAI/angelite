const c = @cImport({
    @cInclude("vulkan/vulkan.h");
});

pub const StructureType = enum(c_uint) {
    AppInfo = 0,
    InstanceInfo = 1,
};

pub const NULL = c.VK_NULL_HANDLE;

pub fn sTy(ty: StructureType) c.VkStructureType {
    // Using a direct cast since we know StructureType uses c_uint as its tag type
    return @as(c.VkStructureType, @intFromEnum(ty));
}

pub const API_VERSION_1_0 = c.VK_API_VERSION_1_0;
pub const MAKE_VERSION = c.VK_MAKE_VERSION;

pub const AppInfo = c.VkApplicationInfo;
pub const InstanceInfo = c.VkInstanceCreateInfo;

pub const Result = c.VkResult;
pub const Instance = c.VkInstance;

pub const createInstance = c.vkCreateInstance;
