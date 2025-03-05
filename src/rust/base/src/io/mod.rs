pub mod file;
pub mod socket;

pub enum Handle {
    File(file::File),
    Socket(socket::Socket),
}

pub struct OperationId(pub(crate) u64);

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
