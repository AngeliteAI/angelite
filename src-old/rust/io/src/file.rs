use std::ptr;

use crate::bindings::file as ffi;
use crate::raw;

pub struct File {
    handle: *mut ffi::File,
}

impl Default for File {
    fn default() -> Self {
        File {
            handle: ptr::null_mut(),
        }
    }
}

raw!(File, *mut ffi::File);

impl File {}
