pub const OperationType = enum(c_int) {
    ACCEPT,
    CONNECT,
    READ,
    WRITE,
    CLOSE,
    SEEK,
    FLUSH,
};

pub const Operation = extern struct {
    id: u64,
    type: OperationType,
    user_data: ?*anyopaque,
    handle: *anyopaque,
};

pub const Complete = extern struct {
    op: Operation,
    result: i32,
};

pub const SeekOrigin = enum(c_int) {
    BEGIN,
    CURRENT,
    END,
};

pub const ModeFlags = packed struct {
    read: bool = false,
    write: bool = false,
    append: bool = false,
    create: bool = false,
    truncate: bool = false,
    _padding: u26 = 0,
};

pub const SockType = enum { STREAM, DGRAM };

pub const HandleType = enum { FILE, SOCKET };

pub extern fn handleType(handle: *anyopaque) HandleType;
pub extern fn lastOperationId() u64;
