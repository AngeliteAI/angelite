extern "C" {
    #[link_name = "fileCreate"]
    pub fn create(user_data: *mut libc::c_void) -> *mut libc::c_void;
    #[link_name = "fileOpen"]
    pub fn open(file: *mut libc::c_void, path: *const i8, mode: i32) -> bool;
    #[link_name = "fileRead"]
    pub fn read(file: *mut libc::c_void, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    #[link_name = "fileWrite"]
    pub fn write(file: *mut libc::c_void, buffer: *mut cpu::Buffer, offset: i64) -> bool;
    #[link_name = "fileSeek"]
    pub fn seek(file: *mut libc::c_void, offset: i64, origin: io::SeekOrigin) -> bool;
    #[link_name = "fileFlush"]
    pub fn flush(file: *mut libc::c_void) -> bool;
    #[link_name = "fileClose"]
    pub fn close(file: *mut libc::c_void) -> bool;
    #[link_name = "fileRelease"]
    pub fn release(file: *mut libc::c_void) -> bool;
    #[link_name = "fileSize"]
    pub fn size(file: *mut libc::c_void, size_out: *mut u64) -> bool;
}

pub struct File {}