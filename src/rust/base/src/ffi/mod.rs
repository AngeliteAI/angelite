use std::{
    ffi::{CStr, c_void},
    fmt,
    net::SocketAddr,
};

/// Operation type as defined in Zig
#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum OperationType {
    Accept,
    Connect,
    Read,
    Write,
    Close,
    Seek,
    Flush,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SocketType {
    Stream,
    Dgram,
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
#[repr(i32)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BaseError {
    // Memory errors
    OutOfMemory = 1,

    // I/O errors
    IoError = 10,
    BadFileDescriptor = 11,
    BadAddress = 12,
    BufferFull = 13,
    ResourceUnavailable = 14,

    // Argument errors
    InvalidArgument = 20,

    // Operation errors
    OperationTimeout = 30,
    OperationInterrupted = 31,
    OperationNotSupported = 32,

    // Network errors
    NetworkUnreachable = 40,
    ConnectionRefused = 41,
    ConnectionReset = 42,
    AddressInUse = 43,
    AddressNotAvailable = 44,

    // Context errors
    ContextNotInitialized = 50,
    SubmissionQueueFull = 51,

    // System errors
    SystemLimitReached = 60,

    // Unknown/unexpected errors
    Unknown = 999,
}

// Implement Display for BaseError
impl fmt::Display for BaseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            BaseError::OutOfMemory => write!(f, "Out of memory"),
            BaseError::IoError => write!(f, "I/O error"),
            BaseError::BadFileDescriptor => write!(f, "Bad file descriptor"),
            BaseError::BadAddress => write!(f, "Bad address"),
            BaseError::BufferFull => write!(f, "Buffer full"),
            BaseError::ResourceUnavailable => write!(f, "Resource unavailable"),
            BaseError::InvalidArgument => write!(f, "Invalid argument"),
            BaseError::OperationTimeout => write!(f, "Operation timed out"),
            BaseError::OperationInterrupted => write!(f, "Operation interrupted"),
            BaseError::OperationNotSupported => write!(f, "Operation not supported"),
            BaseError::NetworkUnreachable => write!(f, "Network unreachable"),
            BaseError::ConnectionRefused => write!(f, "Connection refused"),
            BaseError::ConnectionReset => write!(f, "Connection reset"),
            BaseError::AddressInUse => write!(f, "Address in use"),
            BaseError::AddressNotAvailable => write!(f, "Address not available"),
            BaseError::ContextNotInitialized => write!(f, "Context not initialized"),
            BaseError::SubmissionQueueFull => write!(f, "Submission queue full"),
            BaseError::SystemLimitReached => write!(f, "System limit reached"),
            BaseError::Unknown => write!(f, "Unknown error"),
        }
    }
}

// Implement Error trait for BaseError
impl std::error::Error for BaseError {}

// Extension to convert from i32 to BaseError
impl From<i32> for BaseError {
    fn from(code: i32) -> Self {
        match code {
            1 => BaseError::OutOfMemory,
            10 => BaseError::IoError,
            11 => BaseError::BadFileDescriptor,
            12 => BaseError::BadAddress,
            13 => BaseError::BufferFull,
            14 => BaseError::ResourceUnavailable,
            20 => BaseError::InvalidArgument,
            30 => BaseError::OperationTimeout,
            31 => BaseError::OperationInterrupted,
            32 => BaseError::OperationNotSupported,
            40 => BaseError::NetworkUnreachable,
            41 => BaseError::ConnectionRefused,
            42 => BaseError::ConnectionReset,
            43 => BaseError::AddressInUse,
            44 => BaseError::AddressNotAvailable,
            50 => BaseError::ContextNotInitialized,
            51 => BaseError::SubmissionQueueFull,
            60 => BaseError::SystemLimitReached,
            999 => BaseError::Unknown,
            _ => BaseError::Unknown,
        }
    }
}

// Result type alias for consistent error handling
pub type Result<T> = std::result::Result<T, BaseError>;

// Convenience extension trait for functions that return bool and set last error
pub trait CheckOperation {
    fn check_operation(self) -> Result<()>;
}

impl CheckOperation for bool {
    fn check_operation(self) -> Result<()> {
        if self {
            Ok(())
        } else {
            // This assumes there's an FFI function to get the last error
            // You would call it here and map the error code to a BaseError
            Err(unsafe { lastError().unwrap().read() })
        }
    }
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

impl IpAddress {
    /// Create an IpAddress from a standard library SocketAddr
    pub fn from_socket_addr(socket_addr: SocketAddr) -> Self {
        match socket_addr {
            SocketAddr::V4(socket_addr_v4) => {
                let addr_bytes = socket_addr_v4.ip().octets();
                let port = socket_addr_v4.port();

                Self {
                    is_ipv6: false,
                    addr: IpAddrUnion {
                        ipv4: Ipv4Addr {
                            addr: addr_bytes,
                            port,
                        },
                    },
                }
            }
            SocketAddr::V6(socket_addr_v6) => {
                let addr_bytes = socket_addr_v6.ip().octets();
                let port = socket_addr_v6.port();

                Self {
                    is_ipv6: true,
                    addr: IpAddrUnion {
                        ipv6: Ipv6Addr {
                            addr: addr_bytes,
                            port,
                        },
                    },
                }
            }
        }
    }
}

// You might also want a method to convert back to a SocketAddr
impl From<&IpAddress> for SocketAddr {
    fn from(ip_address: &IpAddress) -> Self {
        if ip_address.is_ipv6 {
            // Safety: We're checking is_ipv6 flag before accessing the union
            let ipv6 = unsafe { ip_address.addr.ipv6 };
            let std_ipv6 = std::net::Ipv6Addr::from(ipv6.addr);
            SocketAddr::V6(std::net::SocketAddrV6::new(std_ipv6, ipv6.port, 0, 0))
        } else {
            // Safety: We're checking is_ipv6 flag before accessing the union
            let ipv4 = unsafe { ip_address.addr.ipv4 };
            let std_ipv4 = std::net::Ipv4Addr::from(ipv4.addr);
            SocketAddr::V4(std::net::SocketAddrV4::new(std_ipv4, ipv4.port))
        }
    }
}

// Additional convenience From implementations
impl From<SocketAddr> for IpAddress {
    fn from(socket_addr: SocketAddr) -> Self {
        Self::from_socket_addr(socket_addr)
    }
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
    ReuseAddr = 2,
    RcvTime0 = 3,
    SndTime0 = 4,
    KeepAlive = 5,
    Linger = 6,
    BufSize = 7,
    NoDelay = 8,
}

// External functions from Zig
// Context func#[repr(C)]
pub enum HandleType {
    File,
    Socket,
}

unsafe extern "C" {
    // Context functions
    pub fn current() -> Option<*mut Context>;
    pub fn init(desired_concurrency: usize) -> *mut Context;
    pub fn shutdown();
    pub fn submit() -> usize;
    pub fn poll(completions: *mut Complete, max_completions: usize) -> usize;
    pub fn lastError() -> Option<*mut BaseError>;

    // Buffer functions
    pub fn cpuBufferCreate(cap: usize) -> Option<*mut Buffer>;
    pub fn cpuBufferWrap(data: *mut u8, len: usize) -> *mut Buffer;
    pub fn cpuBufferRelease(buffer: *mut Buffer) -> bool;

    // Gen I/O
    pub fn handleType(handle: *mut std::ffi::c_void) -> Option<*mut HandleType>;

    // File functions
    pub fn fileCreate(user_data: *mut c_void) -> Option<*mut File>;
    pub fn fileOpen(file: *mut File, path: *const i8, mode: i32) -> bool;
    pub fn fileRead(file: *mut File, buffer: *mut Buffer, offset: i64) -> bool;
    pub fn fileWrite(file: *mut File, buffer: *mut Buffer, offset: i64) -> bool;
    pub fn fileSeek(file: *mut File, offset: i64, origin: SeekOrigin) -> bool;
    pub fn fileFlush(file: *mut File) -> bool;
    pub fn fileClose(file: *mut File) -> bool;
    pub fn fileSize(file: *mut File, size: *mut u64) -> bool;

    // Socket functions
    pub fn socketCreate(
        ipv6: bool,
        sock_type: SocketType,
        user_data: *mut c_void,
    ) -> Option<*mut Socket>;
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
