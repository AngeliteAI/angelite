use libc;
use std::mem::ManuallyDrop;

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
#[derive(Debug, Clone)]
pub struct Operation {
    pub id: u64,
    pub r#type: OperationType,
    pub user_data: *mut libc::c_void,
    pub handle: *mut libc::c_void,
}

#[repr(C)]
#[derive(Debug, Clone)]
pub struct Complete {
    pub op: Operation,
    pub result: i32,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SeekOrigin {
    Begin,
    Current,
    End,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct ModeFlags {
    pub read: bool,
    pub write: bool,
    pub append: bool,
    pub create: bool,
    pub truncate: bool,
    pub _padding: [u8; 4], // 26 bits = 3.25 bytes, round up to 4
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SockType {
    Stream,
    Dgram,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum HandleType {
    File,
    Socket,
}

unsafe extern "C" {
    #[link_name = "ioHandleType"]
    pub fn handle_type(handle: *mut libc::c_void) -> HandleType;
    #[link_name = "ioLastOperationId"]
    pub fn last_operation_id() -> u64;
}