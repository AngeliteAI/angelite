//! CPU buffer related functions and types

use libc::{size_t, c_void,  c_uchar};
use crate::types::Buffer;

unsafe extern "C" {
    pub fn create(cap: usize) -> *mut Buffer;
    pub fn wrap(data: *mut c_uchar, len: usize) -> *mut Buffer;
    pub fn release(buffer: *mut Buffer) -> bool;
}