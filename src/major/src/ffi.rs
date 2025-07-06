pub use crate::error::Error;
pub use crate::file;
pub use crate::log::Level;
pub use crate::runtime;
pub use crate::socket;
pub use crate::string::String;
pub use crate::task;

pub type Job = extern "C" fn(context: *mut (), event: u32);
pub type Wake = extern "C" fn(context: *mut ());

unsafe extern "C" {
    pub fn log(lvl: Level, msg: *const String);
    pub fn error() -> Option<*const Error>;

    pub fn runtime_start() -> *mut runtime::Handle;
    pub fn runtime_stop(handle: *mut runtime::Handle);
    pub fn runtime_yield(handle: *mut runtime::Handle);

    pub fn task_spawn(
        handle: *mut runtime::Handle,
        job: Job,
        wake: Wake,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn task_wake(task: *mut task::Handle);
    pub fn task_complete(task: *mut task::Handle);
    pub fn task_yield(task: *mut task::Handle);
    pub fn task_sleep(
        task: *mut task::Handle,
        duration: u64,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;

    pub fn file_open(
        handle: *mut runtime::Handle,
        path: *const String,
        flags: u32,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn file_read(
        handle: *mut runtime::Handle,
        fd: file::Desc,
        buf: *mut u8,
        len: usize,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn file_write(
        handle: *mut runtime::Handle,
        fd: file::Desc,
        buf: *const u8,
        len: usize,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn file_close(
        handle: *mut runtime::Handle,
        fd: file::Desc,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;

    pub fn socket_open(
        handle: *mut runtime::Handle,
        domain: socket::Domain,
        type_: socket::Type,
        protocol: socket::Protocol,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_bind(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        addr: *const socket::Address,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_listen(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        backlog: u32,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_accept(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_connect(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        addr: *const socket::Address,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_send(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        buf: *const u8,
        len: usize,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_recv(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        buf: *mut u8,
        len: usize,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
    pub fn socket_close(
        handle: *mut runtime::Handle,
        sock: *mut socket::Desc,
        job: Job,
        context: *mut (),
    ) -> *mut task::Handle;
}
