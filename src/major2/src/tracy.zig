const std = @import("std");
const builtin = @import("builtin");

// Tracy C API bindings
pub const c = @cImport({
    // Enable Tracy profiler
    @cDefine("TRACY_ENABLE", "1");
    // Allow Tracy to broadcast its presence for discovery
    // @cDefine("TRACY_NO_BROADCAST", "1");
    // Allow code transfer for better debugging
    // @cDefine("TRACY_NO_CODE_TRANSFER", "1");
    // Allow connections from any host for development
    // @cDefine("TRACY_ONLY_LOCALHOST", "1");
    @cInclude("tracy/TracyC.h");
});

// Zone context for scoped profiling
pub const ZoneCtx = struct {
    ctx: c.___tracy_c_zone_context,
    
    pub fn end(self: ZoneCtx) void {
        c.___tracy_emit_zone_end(self.ctx);
    }
    
    pub fn text(self: ZoneCtx, txt: []const u8) void {
        c.___tracy_emit_zone_text(self.ctx, txt.ptr, txt.len);
    }
    
    pub fn name(self: ZoneCtx, n: []const u8) void {
        c.___tracy_emit_zone_name(self.ctx, n.ptr, n.len);
    }
    
    pub fn color(self: ZoneCtx, col: u32) void {
        c.___tracy_emit_zone_color(self.ctx, col);
    }
    
    pub fn value(self: ZoneCtx, val: u64) void {
        c.___tracy_emit_zone_value(self.ctx, val);
    }
};

// Source location for static profiling zones
pub const SourceLocation = struct {
    name: ?[*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
};

// Initialize a profiling zone
pub fn zoneBegin(comptime src_loc: SourceLocation, active: bool) ZoneCtx {
    const static = struct {
        var loc = c.___tracy_source_location_data{
            .name = src_loc.name,
            .function = src_loc.function,
            .file = src_loc.file,
            .line = src_loc.line,
            .color = src_loc.color,
        };
    };
    
    return ZoneCtx{
        .ctx = c.___tracy_emit_zone_begin(&static.loc, if (active) 1 else 0),
    };
}

// Scoped zone helper
pub fn Zone(comptime name_str: ?[]const u8) type {
    return struct {
        zone: ZoneCtx,
        name: ?[*:0]const u8,
        
        pub fn init() @This() {
            const src = @src();
            const static = struct {
                var loc = c.___tracy_source_location_data{
                    .name = if (name_str) |n| (n ++ "\x00").ptr else null,
                    .function = src.fn_name.ptr,
                    .file = src.file.ptr,
                    .line = src.line,
                    .color = 0,
                };
            };
            
            return .{
                .zone = ZoneCtx{
                    .ctx = c.___tracy_emit_zone_begin(&static.loc, 1),
                },
                .name = if (name_str) |n| (n ++ "\x00").ptr else null,
            };
        }
        
        pub fn deinit(self: *@This()) void {
            self.zone.end();
        }
    };
}

// Memory profiling
pub fn allocN(ptr: ?*anyopaque, size: usize, name: []const u8) void {
    if (ptr) |p| {
        var name_buf: [256]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch return;
        c.___tracy_emit_memory_alloc_named(p, size, 0, name_z.ptr);
    }
}

pub fn alloc(ptr: ?*anyopaque, size: usize) void {
    if (ptr) |p| {
        c.___tracy_emit_memory_alloc(p, size, 0);
    }
}

pub fn freeN(ptr: ?*anyopaque, name: []const u8) void {
    if (ptr) |p| {
        var name_buf: [256]u8 = undefined;
        const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch return;
        c.___tracy_emit_memory_free_named(p, 0, name_z.ptr);
    }
}

pub fn free(ptr: ?*anyopaque) void {
    if (ptr) |p| {
        c.___tracy_emit_memory_free(p, 0);
    }
}

// Frame marking
pub fn frameMark() void {
    c.___tracy_emit_frame_mark(null);
}

pub fn frameMarkNamed(name: []const u8) void {
    c.___tracy_emit_frame_mark(name.ptr);
}

// Plot values
pub fn plotU64(name: []const u8, val: u64) void {
    c.___tracy_emit_plot(name.ptr, val);
}

pub fn plotF64(name: []const u8, val: f64) void {
    c.___tracy_emit_plot_float(name.ptr, @floatCast(val));
}

// Message logging
pub fn message(txt: []const u8) void {
    c.___tracy_emit_message(txt.ptr, txt.len, 0);
}

pub fn messageColor(txt: []const u8, color: u32) void {
    c.___tracy_emit_messageC(txt.ptr, txt.len, color, 0);
}

// GPU profiling context
var gpu_context_counter: u8 = 0;

pub const VkCtx = struct {
    context: u8,
    
    pub fn init(device: anytype, physical_device: anytype, queue: anytype, cmd_buffer: anytype) !VkCtx {
        _ = device;
        _ = physical_device;
        _ = queue;
        _ = cmd_buffer;
        
        const ctx = gpu_context_counter;
        gpu_context_counter += 1;
        
        // Initialize GPU context
        const gpu_ctx_data = c.___tracy_gpu_new_context_data{
            .gpuTime = 0,
            .period = 1.0,
            .context = ctx,
            .flags = 0,
            .type = 1, // Vulkan
        };
        c.___tracy_emit_gpu_new_context(gpu_ctx_data);
        
        return VkCtx{ .context = ctx };
    }
    
    pub fn deinit(self: VkCtx) void {
        _ = self;
        // No explicit cleanup needed
    }
    
    pub fn collect(self: VkCtx) void {
        _ = self;
        // Collection happens automatically
    }
};

pub const VkZoneCtx = struct {
    context: u8,
    query_id: u16,
    
    pub fn end(self: VkZoneCtx) void {
        const end_data = c.___tracy_gpu_zone_end_data{
            .queryId = self.query_id,
            .context = self.context,
        };
        c.___tracy_emit_gpu_zone_end(end_data);
    }
};

// Thread naming
pub fn setThreadName(name: []const u8) void {
    var name_buf: [256]u8 = undefined;
    const name_z = std.fmt.bufPrintZ(&name_buf, "{s}", .{name}) catch return;
    c.___tracy_set_thread_name(name_z.ptr);
}

// App info
pub fn setAppInfo(info: []const u8) void {
    c.___tracy_emit_message_appinfo(info.ptr, info.len);
}

// Check if Tracy profiler is connected
pub fn isConnected() bool {
    return c.___tracy_connected() != 0;
}

// Force a connection attempt
pub fn startup() void {
    // Tracy will automatically start when first used, but we can force it
    // Create a dummy zone to force initialization
    const loc = c.___tracy_source_location_data{
        .name = "TracyStartup",
        .function = "startup",
        .file = "tracy.zig",
        .line = @as(u32, @intCast(@src().line)),
        .color = 0xFF0000,
    };
    const ctx = c.___tracy_emit_zone_begin(&loc, 1);
    c.___tracy_emit_zone_end(ctx);
    
    // Emit a frame mark to help Tracy detect the application
    c.___tracy_emit_frame_mark(null);
    
    // Set app info
    const app_info = "Angelite Game Engine";
    c.___tracy_emit_message_appinfo(app_info.ptr, app_info.len);
    
    _ = c.___tracy_connected();
}

// FFI exports for Rust integration
var ffi_zone_locations: [1024]c.___tracy_source_location_data = undefined;
var ffi_zone_counter: usize = 0;

var ffi_zone_contexts: [1024]c.___tracy_c_zone_context = undefined;
var ffi_zone_ctx_counter: usize = 0;

export fn tracy_zone_begin(
    name: [*:0]const u8,
    function: [*:0]const u8,
    file: [*:0]const u8,
    line: u32,
    color: u32,
) u64 {
    // Tracy requires static storage for location data
    const loc_idx = ffi_zone_counter % ffi_zone_locations.len;
    ffi_zone_counter += 1;
    
    ffi_zone_locations[loc_idx] = c.___tracy_source_location_data{
        .name = if (name[0] != 0) name else null,
        .function = function,
        .file = file,
        .line = line,
        .color = color,
    };
    
    const ctx_idx = ffi_zone_ctx_counter % ffi_zone_contexts.len;
    ffi_zone_ctx_counter += 1;
    
    // Active = 1 means the zone is enabled
    const ctx = c.___tracy_emit_zone_begin(&ffi_zone_locations[loc_idx], 1);
    ffi_zone_contexts[ctx_idx] = ctx;
    
    // Return the index as the handle
    return ctx_idx;
}

export fn tracy_zone_end(ctx_idx: u64) void {
    if (ctx_idx < ffi_zone_contexts.len) {
        const zone_ctx = ZoneCtx{
            .ctx = ffi_zone_contexts[ctx_idx],
        };
        zone_ctx.end();
    }
}

export fn tracy_frame_mark() void {
    frameMark();
}

export fn tracy_frame_mark_named(name: [*:0]const u8) void {
    frameMarkNamed(std.mem.span(name));
}

export fn tracy_plot(name: [*:0]const u8, value: f64) void {
    plotF64(std.mem.span(name), value);
}

export fn tracy_message(text: [*]const u8, len: usize) void {
    message(text[0..len]);
}

export fn tracy_message_color(text: [*]const u8, len: usize, color: u32) void {
    messageColor(text[0..len], color);
}

export fn tracy_thread_name(name: [*]const u8, len: usize) void {
    _ = len;
    c.___tracy_set_thread_name(name);
}

export fn tracy_alloc(ptr: *const anyopaque, size: usize, name: [*]const u8, name_len: usize) void {
    allocN(@constCast(ptr), size, name[0..name_len]);
}

export fn tracy_free(ptr: *const anyopaque, name: [*]const u8, name_len: usize) void {
    freeN(@constCast(ptr), name[0..name_len]);
}

export fn tracy_is_connected() bool {
    return isConnected();
}

export fn tracy_startup() void {
    startup();
}

// Convenience macros for common patterns
pub fn zone(comptime name_str: ?[]const u8) Zone(name_str) {
    return Zone(name_str).init();
}

// Color constants for profiling zones
pub const Colors = struct {
    pub const Default = 0x000000;
    pub const Aqua = 0x00FFFF;
    pub const Blue = 0x0000FF;
    pub const Brown = 0xA52A2A;
    pub const Crimson = 0xDC143C;
    pub const DarkBlue = 0x00008B;
    pub const DarkGreen = 0x006400;
    pub const DarkRed = 0x8B0000;
    pub const ForestGreen = 0x228B22;
    pub const Fuchsia = 0xFF00FF;
    pub const Gold = 0xFFD700;
    pub const Gray = 0x808080;
    pub const Green = 0x008000;
    pub const GreenYellow = 0xADFF2F;
    pub const Lime = 0x00FF00;
    pub const Magenta = 0xFF00FF;
    pub const Maroon = 0x800000;
    pub const Navy = 0x000080;
    pub const Olive = 0x808000;
    pub const Orange = 0xFFA500;
    pub const OrangeRed = 0xFF4500;
    pub const Orchid = 0xDA70D6;
    pub const Pink = 0xFFC0CB;
    pub const Purple = 0x800080;
    pub const Red = 0xFF0000;
    pub const RoyalBlue = 0x4169E1;
    pub const Silver = 0xC0C0C0;
    pub const SkyBlue = 0x87CEEB;
    pub const SlateBlue = 0x6A5ACD;
    pub const SteelBlue = 0x4682B4;
    pub const Teal = 0x008080;
    pub const Tomato = 0xFF6347;
    pub const Turquoise = 0x40E0D0;
    pub const Violet = 0xEE82EE;
    pub const Yellow = 0xFFFF00;
    pub const YellowGreen = 0x9ACD32;
};