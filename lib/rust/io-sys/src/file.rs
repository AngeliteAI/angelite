//! File operations

use libc::{c_int, c_char, size_t, c_longlong, c_void};
use crate::types::{File, Buffer, SeekOrigin, ModeFlags};

#[link(name = "example")]
unsafe extern "C" {
    pub fn create(user_data: *mut c_void) -> *mut File;
    pub fn open(file: *mut File, path: *const c_char, mode: c_int) -> bool;
    pub fn read(file: *mut File, buffer: *mut Buffer, offset: c_longlong) -> bool;
    pub fn write(file: *mut File, buffer: *mut Buffer, offset: c_longlong) -> bool;
    pub fn seek(file: *mut File, offset: c_longlong, origin: SeekOrigin) -> bool;
    pub fn flush(file: *mut File) -> bool;
    pub fn close(file: *mut File) -> bool;
    pub fn release(file: *mut File) -> bool;
    pub fn size(file: *mut File, size_out: *mut u64) -> bool;
}