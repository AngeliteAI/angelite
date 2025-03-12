use libc;
use std::fmt::Debug;

#[repr(C)]
#[derive(Debug, Clone, Copy)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub cap: usize,
    pub owned: bool,
}

unsafe extern "C" {
    #[link_name = "cpuBufferCreate"]
    pub fn create(cap: usize) -> std::option::Option<*mut Buffer>;
    #[link_name = "cpuBufferWrap"]
    pub fn wrap(data: *mut u8, len: usize) -> *mut Buffer;
    #[link_name = "cpuBufferRelease"]
    pub fn release(buffer: *mut Buffer) -> bool;
}