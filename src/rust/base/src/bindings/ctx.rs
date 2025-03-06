extern "C" {
    #[link_name = "ctxCurrent"]
    pub fn current() -> *mut libc::c_void;
    #[link_name = "ctxInit"]
    pub fn init(desired_concurrency: usize) -> *mut libc::c_void;
    #[link_name = "ctxShutdown"]
    pub fn shutdown();
    #[link_name = "ctxSubmit"]
    pub fn submit() -> usize;
    #[link_name = "ctxPoll"]
    pub fn poll(completions: *mut io::Complete, max_completions: usize) -> usize;
    #[link_name = "ctxLastError"]
    pub fn last_error() -> *mut err::Error;
}

pub struct Context {}