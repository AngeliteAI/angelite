use std::ffi::{CStr, c_void};

/// Operation type as defined in Zig
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperationType {
    ACCEPT,
    CONNECT,
    READ,
    WRITE,
    CLOSE,
    SEEK,
    FLUSH,
}

/// Operation structure matching Zig's Operation
#[repr(C)]
pub struct Operation {
    pub id: u64,
    pub type_: OperationType,
    pub user_data: *mut c_void,
    pub handle: *mut c_void,
}

/// Completion structure matching Zig's Complete
#[repr(C)]
pub struct Complete {
    pub op: Operation,
    pub result: i32,
}

/// Seek origin matching Zig's SeekOrigin
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SeekOrigin {
    BEGIN,
    CURRENT,
    END,
}

/// File mode flags matching Zig's ModeFlags
#[repr(C, packed)]
pub struct ModeFlags {
    pub read: bool,
    pub write: bool,
    pub append: bool,
    pub create: bool,
    pub truncate: bool,
    _padding: u32, // Padding to match Zig's u26 padding
}

/// Error structure matching Zig's Error
#[repr(C)]
pub struct Error {
    pub msg: *const i8,
    pub trace: *const i8,
}

/// Context structure opaque in Rust but defined in Zig
#[repr(C)]
pub struct Context {
    _private: [u8; 0],
}

/// Buffer structure matching Zig's Buffer
#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub cap: usize,
    pub owned: bool,
}

/// File structure opaque in Rust but defined in Zig
#[repr(C)]
pub struct File {
    _private: [u8; 0],
}

/// Socket structure opaque in Rust but defined in Zig
#[repr(C)]
pub struct Socket {
    _private: [u8; 0],
}

/// IP Address structure matching Zig's IpAddress
#[repr(C)]
pub struct IpAddress {
    pub is_ipv6: bool,
    pub addr: IpAddrUnion,
}

/// IP Address union matching Zig's addr union
#[repr(C)]
#[derive(Clone, Copy)]
pub union IpAddrUnion {
    pub ipv4: Ipv4Addr,
    pub ipv6: Ipv6Addr,
}

/// IPv4 address structure matching Zig's ipv4 struct
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Ipv4Addr {
    pub addr: [u8; 4],
    pub port: u16,
}

/// IPv6 address structure matching Zig's ipv6 struct
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Ipv6Addr {
    pub addr: [u8; 16],
    pub port: u16,
}

/// Socket options matching Zig's Option enum
#[repr(i32)]
pub enum SocketOption {
    REUSEADDR = 2,
    RCVTIMEO = 3,
    SNDTIMEO = 4,
    KEEPALIVE = 5,
    LINGER = 6,
    BUFFER_SIZE = 7,
    NODELAY = 8,
}

// External functions from Zig
// Context func#[repr(C)]
pub enum HandleType {
    FILE,
    SOCKET,
}

extern "C" {
    // Context functions
    pub fn current() -> *mut Context;
    pub fn init(desired_concurrency: usize) -> *mut Context;
    pub fn shutdown();
    pub fn submit() -> usize;
    pub fn poll(completions: *mut Complete, max_completions: usize) -> usize;
    pub fn lastError() -> *mut Error;

    // Buffer functions
    pub fn cpuBufferCreate(cap: usize) -> *mut Buffer;
    pub fn cpuBufferWrap(data: *mut u8, len: usize) -> *mut Buffer;
    pub fn cpuBufferRelease(buffer: *mut Buffer) -> bool;

    // Gen I/O
    pub fn handleType(handle: *mut std::ffi::c_void) -> *mut HandleType;

    // File functions
    pub fn fileCreate(user_data: *mut c_void) -> *mut File;
    pub fn fileOpen(file: *mut File, path: *const i8, mode: i32) -> bool;
    pub fn fileRead(file: *mut File, buffer: *mut Buffer, offset: i64) -> bool;
    pub fn fileWrite(file: *mut File, buffer: *mut Buffer, offset: i64) -> bool;
    pub fn fileSeek(file: *mut File, offset: i64, origin: SeekOrigin) -> bool;
    pub fn fileFlush(file: *mut File) -> bool;
    pub fn fileClose(file: *mut File) -> bool;
    pub fn fileSize(file: *mut File, size: *mut u64) -> bool;

    // Socket functions
    pub fn socketCreate(ipv6: bool, user_data: *mut c_void) -> *mut Socket;
    pub fn socketBind(sock: *mut Socket, address: *const IpAddress) -> bool;
    pub fn socketListen(sock: *mut Socket, backlog: i32) -> bool;
    pub fn socketAccept(sock: *mut Socket) -> bool;
    pub fn socketConnect(sock: *mut Socket, address: *const IpAddress) -> bool;
    pub fn socketRecv(sock: *mut Socket, buffer: *mut Buffer) -> bool;
    pub fn socketSend(sock: *mut Socket, buffer: *mut Buffer) -> bool;
    pub fn socketClose(sock: *mut Socket) -> bool;
    pub fn socketSetOption(
        sock: *mut Socket,
        option: SocketOption,
        value: *const c_void,
        len: u32,
    ) -> bool;
}
