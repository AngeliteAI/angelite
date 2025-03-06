use crate::bindings::file as ffi;

pub struct File(*mut ffi::File);

impl File {}
