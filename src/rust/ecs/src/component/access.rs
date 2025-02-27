use std::any::Any;
use std::ptr::DynMetadata;
use super::{Component, Handle, Meta};

pub trait Access: ?Sized {
    fn access<'a>(ptr: *mut u8, vtable: DynMetadata<dyn Component>) -> &'a mut Self;
    fn meta() -> Vec<Meta>;
}
