use std::fmt::Debug;

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
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