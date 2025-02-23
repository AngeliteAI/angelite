use derive_more::derive::{Deref, DerefMut};
use std::fmt::Formatter;
use std::{any::TypeId, fmt, mem, ptr, sync::Arc};

pub mod archetype;
pub mod registry;
pub mod sink;
pub mod source;
pub mod table;

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

pub trait Component {
    fn meta() -> Meta
    where
        Self: Sized;
}

pub use ecs_macro::Component;

pub struct Handle<'a>(Arc<dyn Component + 'a>);
impl Handle<'_> {
    fn as_mut_ptr(&mut self) -> *mut u8 {
        //SAFETY: Arc only has one strong reference to the component
        //Well here technically two but were just hacking it to get the raw pointer
        let ptr = Arc::into_raw(self.0.clone()) as *mut _;
        ptr
    }
}

impl fmt::Debug for Handle<'_> {
    fn fmt(&self, f: &mut Formatter<'_>) -> fmt::Result {
        f.debug_tuple("Handle").finish()
    }
}
