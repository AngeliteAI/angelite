use derive_more::derive::{Deref, DerefMut};
use std::fmt::Formatter;
use std::ptr::DynMetadata;
use std::{any::TypeId, fmt, mem, ptr, sync::Arc};

pub mod access;
pub mod archetype;
pub mod registry;
pub mod sink;
pub mod source;
pub mod table;
pub use ecs_macro::component;

#[derive(Copy, Clone, Ord, PartialOrd, Eq, PartialEq, Debug, Deref, DerefMut, Hash)]
pub struct Id(pub TypeId);

#[derive(Copy, Clone, Ord, PartialOrd, Eq, PartialEq, Debug, Hash)]
pub struct Meta {
    pub id: Id,
    pub size: usize,
}

impl Meta {
    pub fn of<T: Component>() -> Self {
        Self {
            id: Id(typeid::of::<T>()),
            size: mem::size_of::<T>(),
        }
    }
}

pub trait Component: 'static {
    fn meta() -> Meta
    where
        Self: Sized;
}

pub struct Handle(pub Box<dyn Component>, pub DynMetadata<dyn Component>);
impl Handle {
    fn as_mut_ptr(&mut self) -> *mut dyn Component {
        //SAFETY: Arc only has one strong reference to the component
        //Well here technically two but were just hacking it to get the raw pointer
        let ptr = &mut *self.0 as *mut _;
        ptr
    }
    fn vtable(&self) -> DynMetadata<dyn Component> {
        self.1
    }
}

impl fmt::Debug for Handle {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Handle").finish()
    }
}
