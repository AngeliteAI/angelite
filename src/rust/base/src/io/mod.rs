pub mod file;
pub mod net;

pub enum Handle {
    File(file::File),
}

pub struct OperationId(pub(crate) u64);

#[repr(C)]
pub enum OperationType {
    Accept,
    Connect,
    Read,
    Write,
    Close,
    Seek,
    Flush,
}

pub struct Operation {
    pub id: OperationId,
    pub ty: OperationType,
    pub handle: Handle,
    pub user_data: *mut (),
}

pub struct Completion(pub i32);
