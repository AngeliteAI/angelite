const cpu = @import("cpu");
const std = @import("std");

const Buffer = cpu.Buffer;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

pub fn create(cap: usize) ?*Buffer {
    const buffer_ptr = allocator.create(Buffer) catch return null;

    // Allocate memory for the data
    const data = allocator.alloc(u8, capacity) catch {
        allocator.destroy(buffer_ptr);
        return null;
    };

    // Initialize the buffer
    buffer_ptr.* = Buffer{
        .data = data.ptr,
        .capacity = capacity,
        .len = 0,
        .owned = true,
    };

    return buffer_ptr;
}
pub fn wrap(data: [*]u8, len: usize) ?*Buffer {
    const buffer_ptr = allocator.create(Buffer) catch return null;

    buffer_ptr.* = Buffer {
        .data = data catch return null,
        .capacity = len,
        .len = len,
        .owned = false
    };

    return buffer_ptr;
}
pub fn release(buffer: *Buffer) bool {
    if (buffer.owned) {
        const data_slice = buffer.data[0..buffer.capacity];
        allocator.free(data_slice);
    }

    allocator.destroy(buffer);
}

