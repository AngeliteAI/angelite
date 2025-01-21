use std::{mem, ptr, sync::Arc};

use super::{Component, Handle, table::Data};

pub trait Source {
    unsafe fn erase_component_data<'a>(self) -> Vec<(Handle<'a>, Data)>
    where
        Self: 'a;
}

impl<T: Component> Source for T {
    unsafe fn erase_component_data<'a>(mut self) -> Vec<(Handle<'a>, Data)>
    where
        Self: 'a,
    {
        let ptr = unsafe {
            ptr::slice_from_raw_parts_mut(&mut self as *mut T as *mut u8, mem::size_of::<T>())
        };
        vec![(Handle(Arc::new(self)), Data {
            ptr,
            meta: T::meta(),
        })]
    }
}
