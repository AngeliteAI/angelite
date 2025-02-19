use std::ptr;

use crate::entity::Entity;

use super::{Component, Meta, table::Data};

pub trait Sink {
    type Ref;
    type Mut;

    unsafe fn coerce_component_data(entity: Entity, offset: usize, meta: Meta) -> Self::Ref
    where
        Self: Sized,
    {
        Self::interpret_component_data(Data {
            ptr: ptr::slice_from_raw_parts_mut(entity.head().add(offset) as _, meta.size),
            meta,
        })
    }

    unsafe fn interpret_component_data(data: Data) -> Self::Ref
    where
        Self: Sized;

    unsafe fn coerce_component_data_mut(entity: Entity, offset: usize, meta: Meta) -> Self::Mut
    where
        Self: Sized,
    {
        Self::interpret_component_data_mut(Data {
            ptr: ptr::slice_from_raw_parts_mut(entity.head().add(offset) as _, meta.size),
            meta,
        })
    }

    unsafe fn interpret_component_data_mut(data: Data) -> Self::Mut
    where
        Self: Sized;

    fn meta() -> Meta
    where
        Self: Sized;
}

impl<'a, T: Component + 'a> Sink for &'a mut T {
    type Mut = &'a mut T;
    type Ref = &'a T;

    unsafe fn interpret_component_data(data: Data) -> Self::Ref {
        let ptr = data.ptr as *mut T;
        ptr.as_ref().unwrap()
    }
    unsafe fn interpret_component_data_mut(data: Data) -> Self::Mut {
        let ptr = data.ptr as *mut T;
        ptr.as_mut().unwrap()
    }
    fn meta() -> Meta
    where
        Self: Sized,
    {
        T::meta()
    }
}

impl<'a, T: Component + 'a> Sink for &'a T {
    type Mut = &'a T;
    type Ref = &'a T;

    unsafe fn interpret_component_data(data: Data) -> Self::Ref {
        let ptr = data.ptr as *mut T;
        ptr.as_ref().unwrap()
    }
    unsafe fn interpret_component_data_mut(data: Data) -> Self::Mut {
        let ptr = data.ptr as *mut T;
        ptr.as_mut().unwrap()
    }
    fn meta() -> Meta
    where
        Self: Sized,
    {
        T::meta()
    }
}
