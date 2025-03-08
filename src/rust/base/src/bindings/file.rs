use crate::bindings::cpu;
use libc;

#[repr(C)]
pub struct File {}

unsafe extern "C" {
    #[link_name = "fileCreate"]
    pub fn create(user_data: *mut libc::c_void) -> std::option::Option<*mut File>;
    #[link_name = "fileOpen"]
    pub fn open(file: *mut File, path: *const libc::c_char, mode: i32) -> bool;
    #[link_name = "fileRead"]
    pub fn read(file: *mut File, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    #[link_name = "fileWrite"]
    pub fn write(file: *mut File, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    #[link_name = "fileSeek"]
    pub fn seek(file: *mut File, offset: i64, origin: crate::bindings::io::SeekOrigin) -> bool;
    #[link_name = "fileFlush"]
    pub fn flush(file: *mut File) -> bool;
    #[link_name = "fileClose"]
    pub fn close(file: *mut File) -> bool;
    #[link_name = "fileRelease"]
    pub fn release(file: *mut File) -> bool;
    #[link_name = "fileSize"]
    pub fn size(file: *mut File, size_out: *mut u64) -> bool;
}