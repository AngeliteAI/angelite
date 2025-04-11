//! Type definitions for the example library

use libc::{c_int, c_char, c_uchar, c_ushort, c_void, c_longlong, c_ulonglong, c_uint,  size_t};

/// Opaque File handle
#[repr(C)]
pub struct File {
    _private: [u8; 0],
}

/// Opaque Socket handle
#[repr(C)]
pub struct Socket {
    _private: [u8; 0],
}

/// Represents an IP Address
#[repr(C)]
pub struct IpAddress {
    pub is_ipv6: bool,
    pub addr: IpAddressAddrUnion,
}

#[repr(C)]
pub union IpAddressAddrUnion {
    pub ipv4: IpAddressIpv4,
    pub ipv6: IpAddressIpv6,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct IpAddressIpv4 {
    pub addr: [u8; 4],
    pub port: u16,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct IpAddressIpv6 {
    pub addr: [u8; 16],
    pub port: u16,
}

/// Socket options
#[repr(C)]
pub enum Option {
    Reuseaddr = 2,
    Rcvtimeo = 3,
    Sndtimeo = 4,
    Keepalive = 5,
    Linger = 6,
    BufferSize = 7,
    Nodelay = 8,
}

/// Operation types
#[repr(C)]
pub enum OperationType {
    Accept = 0,
    Connect = 1,
    Read = 2,
    Write = 3,
    Close = 4,
    Seek = 5,
    Flush = 6,
}

/// Represents an IO Operation
#[repr(C)]
pub struct Operation {
    pub id: u64,
    pub typ: OperationType, // Renamed to 'typ' to avoid keyword conflict
    pub user_data: *mut c_void,
    pub handle: *mut c_void,
}

/// Represents a completed IO Operation
#[repr(C)]
pub struct Complete {
    pub op: Operation,
    pub result: i32,
}

/// Seek origin for file operations
#[repr(C)]
pub enum SeekOrigin {
    Begin = 0,
    Current = 1,
    End = 2,
}

/// Mode flags for file operations
#[repr(C)]
pub struct ModeFlags {
    pub read: bool,
    pub write: bool,
    pub append: bool,
    pub create: bool,
    pub truncate: bool,
    _padding: [u8; 26 / 8 + (26 % 8 != 0) as usize], // Ensuring at least 26 bits of padding
}

/// Socket types
#[repr(C)]
pub enum SockType {
    Stream,
    Dgram,
}

/// Handle types
#[repr(C)]
pub enum HandleType {
    File,
    Socket,
}

/// CPU Buffer struct
#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub cap: usize,
    pub owned: bool,
}

/// IO Context
#[repr(C)]
pub struct Context {
    _private: [u8; 0],
}

/// Error enum
#[repr(C)]
pub enum Error {
    Ok = 0,
    OutOfMemory = 1,
    IoError = 10,
    BadFileDescriptor = 11,
    BadAddress = 12,
    BufferFull = 13,
    ResourceUnavailable = 14,
    InvalidArgument = 20,
    OperationTimeout = 30,
    OperationInterrupted = 31,
    OperationNotSupported = 32,
    NetworkUnreachable = 40,
    ConnectionRefused = 41,
    ConnectionReset = 42,
    AddressInUse = 43,
    AddressNotAvailable = 44,
    ContextNotInitialized = 50,
    SubmissionQueueFull = 51,
    SystemLimitReached = 60,
    Unknown = 999,
}