pub const heap = @import("heap.zig");
pub const stage = @import("stage.zig");

pub const Allocator = struct {
    heap: *heap.Heap,
    stage: *stage.Stage,
};
