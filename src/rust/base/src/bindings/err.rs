#[repr(i32)]
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

extern "C" {
    #[link_name = "fromOsError"]
    pub fn from_os_error(code: i32) -> Error;
    #[link_name = "fromError"]
    pub fn from_error(err: *mut libc::c_void) -> Error;
}