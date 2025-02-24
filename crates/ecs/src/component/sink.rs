use std::ptr;

use crate::entity::Entity;

use super::{Component, Handle, Meta, access::Access, table::Data};

pub trait Sink: ?Sized {
    type Ref;
    type Mut;

    unsafe fn coerce_component_data(
        entity: Entity,
        offset: usize,
        meta: Meta,
        handle: &Handle,
    ) -> Self::Ref
    where
        Self: Sized,
    {
        Self::interpret_component_data(
            Data {
                ptr: ptr::slice_from_raw_parts_mut(dbg!(entity.data()).add(offset) as _, meta.size),
                meta,
            },
            handle,
        )
    }

    unsafe fn interpret_component_data(data: Data, handle: &Handle) -> Self::Ref
    where
        Self: Sized;

    unsafe fn coerce_component_data_mut(
        entity: Entity,
        offset: usize,
        meta: Meta,
        handle: &Handle,
    ) -> Self::Mut
    where
        Self: Sized,
    {
        Self::interpret_component_data_mut(
            Data {
                ptr: ptr::slice_from_raw_parts_mut(entity.head().add(offset) as _, meta.size),
                meta,
            },
            handle,
        )
    }

    unsafe fn interpret_component_data_mut(data: Data, handle: &Handle) -> Self::Mut
    where
        Self: Sized;

    fn meta() -> Meta
    where
        Self: Sized;
}

impl<'a, T: Access + ?Sized + 'a> Sink for &'a mut T {
    type Mut = &'a mut T;
    type Ref = &'a T;

    unsafe fn interpret_component_data(data: Data, handle: &Handle) -> Self::Ref {
        T::access(data.ptr as *const u8, handle.vtable())
    }
    unsafe fn interpret_component_data_mut(data: Data, handle: &Handle) -> Self::Mut {
        T::access(data.ptr as *const u8, handle.vtable())
    }
    fn meta() -> Meta
    where
        Self: Sized,
    {
        T::meta()
    }
}

impl<'a, T: Access + ?Sized + 'a> Sink for &'a T {
    type Mut = &'a T;
    type Ref = &'a T;

    unsafe fn interpret_component_data(data: Data, handle: &Handle) -> Self::Ref {
        T::access(data.ptr as *const u8, handle.vtable())
    }
    unsafe fn interpret_component_data_mut(data: Data, handle: &Handle) -> Self::Mut {
        T::access(data.ptr as *const u8, handle.vtable())
    }
    fn meta() -> Meta
    where
        Self: Sized,
    {
        T::meta()
    }
}
