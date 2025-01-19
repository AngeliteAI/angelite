use std::any::TypeId;

use derive_more::derive::{Deref, DerefMut};

pub mod archetype;
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

pub type Handle<'a> = Box<dyn Component + 'a>;
