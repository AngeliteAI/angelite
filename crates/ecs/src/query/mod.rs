use crate::{
    component::{archetype::Archetype, registry::Registry, sink::Sink},
    system::param::Param,
};
use base::rt::UnsafeLocal;
use fetch::{Fetch, Scan};

use crate::world::World;

pub mod fetch;

//SAFETY: Query will only be used by one thread at a time, so its inner RefCell is safe.
pub struct Query<'a, Q: fetch::Query>(UnsafeLocal<Fetch<'a, Q>>);

impl<'a, Q: fetch::Query> IntoIterator for &'a Query<'a, Q> {
    type Item = Q::Ref;
    type IntoIter = Scan<&'a Fetch<'a, Q>>;

    fn into_iter(self) -> Self::IntoIter {
        Self::IntoIter::new(&self.0)
    }
}
impl<'a, Q: fetch::Query> IntoIterator for &'a mut Query<'a, Q> {
    type Item = Q::Mut;
    type IntoIter = Scan<&'a mut Fetch<'a, Q>>;

    fn into_iter(mut self) -> Self::IntoIter {
        Self::IntoIter::new_mut(&mut self.0)
    }
}

impl<Q: fetch::Query> Param for Query<'_, Q> {
    fn inject(archetype: &mut Archetype) {
        archetype.merge(Q::archetype())
    }

    fn create(archetype: Archetype, table: &mut crate::component::table::Table) -> Self
    where
        Self: Sized,
    {
        todo!()
    }
}

impl Sink for () {
    type Ref = ();

    type Mut = ();

    unsafe fn interpret_component_data(data: crate::component::table::Data) -> Self::Ref
    where
        Self: Sized,
    {
        todo!()
    }

    unsafe fn interpret_component_data_mut(data: crate::component::table::Data) -> Self::Mut
    where
        Self: Sized,
    {
        todo!()
    }

    fn meta() -> crate::component::Meta
    where
        Self: Sized,
    {
        todo!()
    }
}
