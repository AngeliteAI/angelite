const std = @import("std");

pub const Palette = struct {
    const Self = @This();

    bits: u32 = 32,
    palette: std.ArrayList(u32),
    count: usize,
    data: std.ArrayList(u32),
    allocator: *std.mem.Allocator,

    pub fn initSingle(allocator: *std.mem.Allocator, single: u32, count: usize) !Self {
        var palette = std.ArrayList(u32).init(allocator);
        try palette.append(single);

        return Self{
            .allocator = allocator,
            .palette = palette,
            .count = count,
            .data = std.ArrayList(u32).init(allocator),
        };
    }

    pub fn initUncompressed(allocator: *std.mem.Allocator, uncompressed: []const u32) !Self {
        var palette = std.ArrayList(u32).init(allocator);
        var seen = std.AutoHashMap(u32, void).init(allocator);
        defer seen.deinit();

        // Build palette of unique values
        for (uncompressed) |value| {
            if (!seen.contains(value)) {
                try seen.put(value, {});
                try palette.append(value);
            }
        }

        const bits_needed = if (palette.items.len <= 1) @as(u5, 0) else blk: {
            var bits: u5 = 0;
            var len = palette.items.len - 1;
            while (len > 0) : (len >>= 1) {
                bits += 1;
            }
            break :blk bits;
        };

        if (bits_needed == 0) {
            // No need to compress if there's only one value
            return Self{
                .allocator = allocator,
                .palette = palette,
                .count = uncompressed.len,
                .data = std.ArrayList(u32).init(allocator),
            };
        }

        const size = (uncompressed.len * bits_needed) / 32 + 1;
        var data = try std.ArrayList(u32).initCapacity(allocator, size);
        data.appendNTimesAssumeCapacity(0, size);

        var bit_cursor: usize = 0;

        for (uncompressed) |value| {
            const outer_offset = bit_cursor / 32;
            const inner_offset = bit_cursor % 32;

            if (outer_offset >= size) {
                break;
            }

            // Find index of value in palette
            const palette_index: u32 = blk: {
                var i: usize = 0;
                while (i < palette.items.len) : (i += 1) {
                    if (palette.items[i] == value) break :blk @as(u32, i);
                }
                break :blk 0; // Default fallback (should not happen)
            };

            const mask = (@as(u32, 1) << @as(u5, @intCast(bits_needed))) - 1;
            const remaining_bits = 32 - inner_offset;

            if (bits_needed <= remaining_bits) {
                const shift_amount1 = @as(u5, inner_offset);
                data.items[outer_offset] |= (palette_index << shift_amount1) & (mask << shift_amount1);
            } else {
                const bits_in_current = remaining_bits;
                const bits_in_next = bits_needed - bits_in_current;

                // First part in current u32
                const shift_amount2 = @as(u5, inner_offset);
                data.items[outer_offset] |= (palette_index << shift_amount2);

                // Second part in next u32
                if (outer_offset + 1 < size) {
                    const shift_amount3 = @as(u5, bits_in_current);
                    const shift_amount4 = @as(u5, bits_in_next);
                    data.items[outer_offset + 1] |= (palette_index >> shift_amount3) &
                        ((@as(u32, 1) << shift_amount4) - 1);
                } else {
                    @panic("out of bounds of data array");
                }
            }

            bit_cursor += bits_needed;
        }

        return Self{
            .allocator = allocator,
            .palette = palette,
            .count = uncompressed.len,
            .data = data,
        };
    }

    pub fn deinit(self: *Self) void {
        self.palette.deinit();
        self.data.deinit();
    }

    pub fn decompress(self: *const Self) ![]u32 {
        if (self.palette.items.len == 0) {
            return &[_]u32{};
        }

        const bits_needed = if (self.palette.items.len <= 1) @as(u5, 1) else blk: {
            var bits: u5 = 0;
            var len = self.palette.items.len - 1;
            while (len > 0) : (len >>= 1) {
                bits += 1;
            }
            break :blk bits;
        };

        var result = try self.allocator.alloc(u32, self.count);
        errdefer self.allocator.free(result);

        // If there's only one value, fill with it
        if (self.palette.items.len == 1) {
            @memset(result, self.palette.items[0]);
            return result;
        }

        // If no compressed data, return empty
        if (self.data.items.len == 0) {
            return result;
        }

        var bit_cursor: u32 = 0;
        const total_bits = @as(u32, self.data.items.len) * 32;
        const max_values = @min(total_bits / bits_needed, @as(u32, self.count));

        var i: usize = 0;
        while (i < max_values and i < result.len) : (i += 1) {
            const outer_offset = bit_cursor / 32;
            const inner_offset = bit_cursor % 32;

            var palette_index: u32 = 0;
            const remaining_bits = 32 - inner_offset;

            if (bits_needed <= remaining_bits) {
                if (outer_offset < self.data.items.len) {
                    const shift_amount1 = @as(u5, inner_offset);
                    palette_index = (self.data.items[outer_offset] >> shift_amount1) &
                        ((@as(u32, 1) << bits_needed) - 1);
                } else {
                    break; // Out of data bounds
                }
            } else {
                const bits_in_current = @as(u32, @intCast(remaining_bits));
                const bits_in_next = bits_needed - bits_in_current;

                if (outer_offset < self.data.items.len) {
                    const shift_amount2 = @as(u5, inner_offset);
                    const shift_amount3 = @as(u5, bits_in_current);
                    palette_index |= (self.data.items[outer_offset] >> shift_amount2) &
                        ((@as(u32, 1) << shift_amount3) - 1);
                } else {
                    break; // Out of data bounds
                }

                if (outer_offset + 1 < self.data.items.len) {
                    const shift_amount4 = @as(u5, bits_in_next);
                    const shift_amount5 = @as(u5, bits_in_current);
                    palette_index |= (self.data.items[outer_offset + 1] &
                        ((@as(u32, 1) << shift_amount4) - 1)) << shift_amount5;
                } else {
                    @panic("Palette index calculation error");
                }
            }

            if (palette_index < self.palette.items.len) {
                result[i] = self.palette.items[palette_index];
            } else {
                @panic("Palette index out of bounds");
            }

            bit_cursor += bits_needed;
        }

        return result;
    }

    pub fn get(self: *const Self, index: u32) u32 {
        std.debug.assert(index < self.count);

        // Handle simple cases
        if (self.palette.items.len == 0) {
            @panic("Palette is empty");
        }

        if (self.data.items.len == 0) {
            return self.palette.items[0];
        }

        // Calculate bits per index (must match compression)
        const bits_needed = std.math.max(1, blk: {
            var bits: u5 = 0;
            var len = self.palette.items.len - 1;
            while (len > 0) : (len >>= 1) {
                bits += 1;
            }
            break :blk bits;
        });

        const bit_cursor = index * bits_needed;
        const outer_offset = bit_cursor / 32;
        const inner_offset = bit_cursor % 32;

        // Safety check to ensure we don't read past allocated data
        const required_data_index = (bit_cursor + bits_needed - 1) / 32;
        std.debug.assert(required_data_index < self.data.items.len);

        // Extract the palette index from data
        var palette_index: u32 = 0;
        const remaining_bits = 32 - inner_offset;
        const mask = (@as(u32, 1) << bits_needed) - 1;

        if (bits_needed <= remaining_bits) {
            // Value fits entirely in the current u32
            const shift_amount1 = @as(u5, inner_offset);
            palette_index = (self.data.items[outer_offset] >> shift_amount1) & mask;
        } else {
            // Value spans across two u32s
            const bits_in_current = remaining_bits;
            const bits_in_next = bits_needed - bits_in_current;

            // Get lower bits from current u32
            const shift_amount2 = @as(u5, inner_offset);
            const part1 = self.data.items[outer_offset] >> shift_amount2;

            // Get upper bits from next u32
            const shift_amount3 = @as(u5, bits_in_next);
            const mask_next = (@as(u32, 1) << shift_amount3) - 1;
            const part2 = self.data.items[outer_offset + 1] & mask_next;

            // Combine parts
            const shift_amount4 = @as(u5, bits_in_current);
            palette_index = part1 | (part2 << shift_amount4);
            palette_index &= mask;
        }

        // Look up value in palette
        std.debug.assert(palette_index < self.palette.items.len);
        return self.palette.items[palette_index];
    }
};

pub const PaletteId = struct {
    id: u32,

    pub fn init(id: u32) PaletteId {
        return .{ .id = id };
    }

    pub fn hash(self: PaletteId) u64 {
        return @as(u64, self.id);
    }

    pub fn eql(self: PaletteId, other: PaletteId) bool {
        return self.id == other.id;
    }
};
