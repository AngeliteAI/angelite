use std::{mem, ptr, sync::Arc};

use base::array;
use base::collections::array::Array;

use super::{
    Component, Handle,
    archetype::Archetype,
    table::{Components, Data, Erase},
};

pub trait Source: 'static {
    unsafe fn erase_component_data<'a>(self) -> Components<'a>
    where
        Self: 'a;
    unsafe fn archetype(&self) -> Archetype;
}
ecs_macro::source!();

impl<T: Component + 'static> Source for T {
    unsafe fn erase_component_data<'a>(mut self) -> Components<'a>
    where
        Self: 'a,
    {
        let mut arr = Array::new();
        let mut this = Arc::new(self);
        let data = this.erase();
        arr.push((Handle(this), data));
        arr
    }

    unsafe fn archetype(&self) -> Archetype {
        Archetype::from_iter([T::meta()])
    }
}
