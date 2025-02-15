use crate::component::archetype::Archetype;
use fast::rt::UnsafeLocal;
use fetch::Fetch;

use crate::{component::table::Metatable, world::World};

pub mod fetch;

pub trait Param: Send {
    fn inject(archetype: &mut Archetype);
}

//SAFETY: Query will only be used by one thread at a time, so its inner RefCell is safe.
pub struct Query<Q: fetch::Query>(UnsafeLocal<Fetch<Q>>);

impl<Q: fetch::Query> Param for Query<Q> {
    fn inject(archetype: &mut Archetype) {
        archetype.merge(Q::archetype())
    }
}

pub trait Params: Send + 'static {
    fn bind(world: &mut World) -> Metatable;
}

major_macro::params!();
