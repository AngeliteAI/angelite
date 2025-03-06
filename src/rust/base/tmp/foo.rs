RUST -> C

```rust
// src/bindings/ctx.rs
#[repr(C)]
pub struct Context {
    _data: [u8; 0],
    _marker: core::marker::PhantomData<(*mut u8, core::marker::UnsafeCell<Context>)>,
}

extern "C" {
    pub fn current() -> *mut Context;
    pub fn init(desired_concurrency: usize) -> *mut Context;
    pub fn shutdown();
    pub fn submit() -> usize;
    pub fn poll(completions: *mut io::Complete, max_completions: usize) -> usize;
    pub fn lastError() -> *mut err::Error;
}
```

```rust
// src/bindings/err.rs
#[repr(i32)]
pub enum Error {
    OK = 0,
    OUT_OF_MEMORY = 1,
    IO_ERROR = 10,
    BAD_FILE_DESCRIPTOR = 11,
    BAD_ADDRESS = 12,
    BUFFER_FULL = 13,
    RESOURCE_UNAVAILABLE = 14,
    INVALID_ARGUMENT = 20,
    OPERATION_TIMEOUT = 30,
    OPERATION_INTERRUPTED = 31,
    OPERATION_NOT_SUPPORTED = 32,
    NETWORK_UNREACHABLE = 40,
    CONNECTION_REFUSED = 41,
    CONNECTION_RESET = 42,
    ADDRESS_IN_USE = 43,
    ADDRESS_NOT_AVAILABLE = 44,
    CONTEXT_NOT_INITIALIZED = 50,
    SUBMISSION_QUEUE_FULL = 51,
    SYSTEM_LIMIT_REACHED = 60,
    UNKNOWN = 999,
}
```

```rust
// src/bindings/cpu.rs
#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub cap: usize,
    pub owned: bool,
}

extern "C" {
    pub fn create(cap: usize) -> *mut Buffer;
    pub fn wrap(data: *mut u8, len: usize) -> *mut Buffer;
    pub fn release(buffer: *mut Buffer) -> bool;
}
```

```rust
// src/bindings/io.rs
#[repr(C)]
pub enum OperationType {
    ACCEPT,
    CONNECT,
    READ,
    WRITE,
    CLOSE,
    SEEK,
    FLUSH,
}

#[repr(C)]
pub struct Operation {
    pub id: u64,
    pub type_: OperationType,
    pub user_data: *mut libc::c_void,
    pub handle: *mut libc::c_void,
}

#[repr(C)]
pub struct Complete {
    pub op: Operation,
    pub result: i32,
}

#[repr(C)]
pub enum SeekOrigin {
    BEGIN,
    CURRENT,
    END,
}

#[repr(C)]
#[derive(Copy, Clone)]
pub struct ModeFlags {
    pub read: bool,
    pub write: bool,
    pub append: bool,
    pub create: bool,
    pub truncate: bool,
    _padding: [u8; 3],
}

#[repr(C)]
pub enum SockType {
    STREAM,
    DGRAM,
}

#[repr(C)]
pub enum HandleType {
    FILE,
    SOCKET,
}

extern "C" {
    pub fn handleType(handle: *mut libc::c_void) -> HandleType;
}
```

```rust
// src/bindings/file.rs
#[repr(C)]
pub struct File {
    _data: [u8; 0],
    _marker: core::marker::PhantomData<(*mut u8, core::marker::UnsafeCell<File>)>,
}

extern "C" {
    pub fn create(user_data: *mut libc::c_void) -> *mut File;
    pub fn open(file: *mut File, path: *const libc::c_char, mode: i32) -> bool;
    pub fn read(file: *mut File, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    pub fn write(file: *mut File, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    pub fn seek(file: *mut File, offset: i64, origin: io::SeekOrigin) -> bool;
    pub fn flush(file: *mut File) -> bool;
    pub fn close(file: *mut File) -> bool;
    pub fn release(file: *mut File) -> bool;
    pub fn size(file: *mut File, size_out: *mut u64) -> bool;
}
```

```rust
// src/bindings/socket.rs
#[repr(C)]
pub struct Socket {
    _data: [u8; 0],
    _marker: core::marker::PhantomData<(*mut u8, core::marker::UnsafeCell<Socket>)>,
}

#[repr(C)]
pub struct IpAddress {
    pub is_ipv6: bool,
    pub addr: IpAddressAddr,
}

#[repr(C)]
pub union IpAddressAddr {
    pub ipv4: IpAddressAddrIpv4,
    pub ipv6: IpAddressAddrIpv6,
}

#[repr(C)]
pub struct IpAddressAddrIpv4 {
    pub addr: [u8; 4],
    pub port: u16,
}

#[repr(C)]
pub struct IpAddressAddrIpv6 {
    pub addr: [u8; 16],
    pub port: u16,
}

#[repr(i32)]
pub enum Option {
    REUSEADDR = 2,
    RCVTIMEO = 3,
    SNDTIMEO = 4,
    KEEPALIVE = 5,
    LINGER = 6,
    BUFFER_SIZE = 7,
    NODELAY = 8,
}

extern "C" {
    pub fn create(ipv6: bool, user_data: *mut libc::c_void) -> *mut Socket;
    pub fn bind(sock: *mut Socket, address: *const IpAddress) -> bool;
    pub fn listen(sock: *mut Socket, backlog: i32) -> bool;
    pub fn accept(sock: *mut Socket) -> bool;
    pub fn connect(sock: *mut Socket, address: *const IpAddress) -> bool;
    pub fn recv(sock: *mut Socket, buffer: *mut cpu::Buffer) -> bool;
    pub fn send(sock: *mut Socket, buffer: *mut cpu::Buffer) -> bool;
    pub fn close(sock: *mut Socket) -> bool;
    pub fn release(sock: *mut Socket) -> bool;
    pub fn setOption(sock: *mut Socket, option: Option, value: *const libc::c_void, len: u32) -> bool;
}
```

```rust
// src/bindings/mod.rs
pub mod ctx;
pub mod err;
pub mod cpu;
pub mod io;
pub mod file;
pub mod socket;
```