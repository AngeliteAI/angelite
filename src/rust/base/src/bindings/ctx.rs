use crate::bindings::io;
use crate::bindings::err;
use libc;

#[repr(C)]
pub struct Context {
    // Opaque type, no fields
}

unsafe extern "C" {
    #[link_name = "ctxCurrent"]
    pub fn current() -> std::option::Option<*mut Context>;
    #[link_name = "ctxInit"]
    pub fn init(desired_concurrency: usize) -> std::option::Option<*mut Context>;
    #[link_name = "ctxShutdown"]
    pub fn shutdown();
    #[link_name = "ctxSubmit"]
    pub fn submit() -> usize;
    #[link_name = "ctxPoll"]
    pub fn poll(completions: *mut io::Complete, max_completions: usize) -> usize;
    #[link_name = "ctxLastError"]
    pub fn last_error() -> std::option::Option<*mut err::Error>;
}