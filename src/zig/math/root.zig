pub const math = struct {
    pub usingnamespace @import("src/scalar.zig"); // Corrected paths
    pub usingnamespace @import("src/vec.zig"); // Corrected paths
    pub usingnamespace @import("src/mat.zig"); // Corrected paths
    pub usingnamespace @import("src/quat.zig"); // Corrected paths
};

pub usingnamespace math;
