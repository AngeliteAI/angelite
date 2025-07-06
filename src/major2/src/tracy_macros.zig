const tracy = @import("tracy.zig");

/// Convenience function to create a zone that automatically ends when the scope exits
pub inline fn zone(comptime name: []const u8) tracy.Zone(name) {
    return tracy.Zone(name).init();
}

/// Convenience function to create a colored zone
pub inline fn zoneColor(comptime name: []const u8, color: u32) type {
    return struct {
        z: tracy.Zone(name),
        
        pub fn init() @This() {
            var self = @This(){
                .z = tracy.Zone(name).init(),
            };
            self.z.zone.color(color);
            return self;
        }
        
        pub fn deinit(self: *@This()) void {
            self.z.deinit();
        }
    };
}

/// Profile a function with automatic zone creation
pub inline fn profileFn() tracy.Zone(null) {
    return tracy.Zone(null).init();
}

/// GPU zone helper for Vulkan
var gpu_query_counter: u16 = 0;

pub const VkZone = struct {
    ctx: tracy.VkZoneCtx,
    
    pub fn init(vk_ctx: tracy.VkCtx, cmd_buffer: *anyopaque, comptime name: []const u8) @This() {
        _ = cmd_buffer;
        
        // Allocate source location
        const src = @src();
        const srcloc = tracy.c.___tracy_alloc_srcloc_name(
            src.line,
            src.file.ptr,
            src.file.len,
            src.fn_name.ptr,
            src.fn_name.len,
            name.ptr,
            name.len,
            tracy.Colors.Gold,
        );
        
        const query_id = gpu_query_counter;
        gpu_query_counter += 1;
        
        // Begin GPU zone
        const begin_data = tracy.c.___tracy_gpu_zone_begin_data{
            .srcloc = srcloc,
            .queryId = query_id,
            .context = vk_ctx.context,
        };
        tracy.c.___tracy_emit_gpu_zone_begin(begin_data);
        
        return .{
            .ctx = tracy.VkZoneCtx{
                .context = vk_ctx.context,
                .query_id = query_id,
            },
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.ctx.end();
    }
};

/// Helper to mark frame boundaries
pub inline fn frameMark(name: ?[]const u8) void {
    if (name) |n| {
        tracy.frameMarkNamed(n);
    } else {
        tracy.frameMark();
    }
}

/// Helper to plot values
pub inline fn plot(name: []const u8, value: anytype) void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .Float => tracy.plotF64(name, @as(f64, value)),
        .Int => tracy.plotU64(name, @as(u64, value)),
        else => @compileError("plot() only supports integer and float types"),
    }
}

/// Helper for memory tracking
pub const MemoryTracking = struct {
    pub inline fn alloc(ptr: anytype, size: usize, name: []const u8) void {
        tracy.allocN(@ptrCast(ptr), size, name);
    }
    
    pub inline fn free(ptr: anytype, name: []const u8) void {
        tracy.freeN(@ptrCast(ptr), name);
    }
};

/// Message logging helpers
pub const Log = struct {
    pub inline fn info(text: []const u8) void {
        tracy.messageColor(text, tracy.Colors.Green);
    }
    
    pub inline fn warn(text: []const u8) void {
        tracy.messageColor(text, tracy.Colors.Yellow);
    }
    
    pub inline fn err(text: []const u8) void {
        tracy.messageColor(text, tracy.Colors.Red);
    }
    
    pub inline fn debug(text: []const u8) void {
        tracy.messageColor(text, tracy.Colors.Gray);
    }
};