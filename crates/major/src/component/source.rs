use std::{mem, ptr, sync::Arc};

use fast::collections::array::Array;

use super::{Component, Handle, archetype::Archetype, table::Data};

pub trait Source {
    unsafe fn erase_component_data<'a>(self) -> Array<Handle<'a>, { Archetype::MAX }>
    where
        Self: 'a;
    unsafe fn archetype(&self) -> Archetype;
}

impl<T: Component> Source for T {
    unsafe fn erase_component_data<'a>(mut self) -> Array<Handle<'a>, { Archetype::MAX }>
    where
        Self: 'a,
    {
        let mut arr = Array::new();
        arr.push(Handle(Arc::new(self)));
        arr
    }

    unsafe fn archetype(&self) -> Archetype {
        todo!()
    }
}
