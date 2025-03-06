extern "C" {
    #[link_name = "cpuBufferCreate"]
    pub fn create(cap: usize) -> *mut libc::c_void;
    #[link_name = "cpuBufferWrap"]
    pub fn wrap(data: *mut u8, len: usize) -> *mut libc::c_void;
    #[link_name = "cpuBufferRelease"]
    pub fn release(buffer: *mut libc::c_void) -> bool;
}

#[repr(C)]
pub struct Buffer {
    pub data: *mut u8,
    pub len: usize,
    pub cap: usize,
    pub owned: bool,
}