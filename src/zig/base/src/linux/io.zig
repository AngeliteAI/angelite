const io = @import("io");

pub fn handleType(handle: *anyopaque) *io.HandleType {
    const handleTypePtr = @as(*const HandleType, @ptrCast(handle));
    
    const type_value = handleTypePtr.*;
    switch (type_value) {
        .FILE, .SOCKET => return handleTypePtr,
        else => return null,
    }
}
