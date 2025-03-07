use crate::bindings::file as ffi;
use crate::raw;

pub struct File(*mut ffi::File);

raw!(File, *mut ffi::File);

impl File {}
