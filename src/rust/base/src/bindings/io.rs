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

#[repr(C)]
pub struct Operation {
    pub id: u64,
    pub r#type: OperationType,
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
    Begin = 0,
    Current = 1,
    End = 2,
}

#[repr(C, packed)]
pub struct ModeFlags {
    pub read: bool,
    pub write: bool,
    pub append: bool,
    pub create: bool,
    pub truncate: bool,
    _padding: u26,
}

#[repr(C)]
pub enum SockType {
    Stream = 0,
    Dgram = 1,
}

#[repr(C)]
pub enum HandleType {
    File = 0,
    Socket = 1,
}

extern "C" {
    #[link_name = "handleType"]
    pub fn handle_type(handle: *mut libc::c_void) -> HandleType;
}