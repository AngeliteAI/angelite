use std::{any::TypeId, ptr, sync::Arc};

use derive_more::derive::{Deref, DerefMut};

pub mod archetype;
pub mod source;
pub mod table;
pub mod world;

#[derive(Copy, Clone, Ord, PartialOrd, Eq, PartialEq, Debug, Deref, DerefMut, Hash)]
pub struct Id(pub TypeId);

#[derive(Copy, Clone, Ord, PartialOrd, Eq, PartialEq, Debug, Hash)]
pub struct Meta {
    pub id: Id,
    pub size: usize,
}

pub trait Component {
    fn meta() -> Meta
    where
        Self: Sized;
}

pub struct Handle<'a>(Arc<dyn Component + 'a>);

impl<'a> Handle<'a> {
    pub fn coalese(&mut self, src: *const u8, meta: &Meta) {
        let Self(this) = self;
        unsafe { ptr::copy(src, Arc::as_ptr(this) as *mut _, meta.size) };
    }
    pub fn write_to(&self, dst: *mut u8, meta: &Meta) {
        let Self(this) = self;
        unsafe { ptr::copy(Arc::as_ptr(this) as *const u8, dst, meta.size) }
    }
}
