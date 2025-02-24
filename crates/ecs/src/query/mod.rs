use crate::{
    component::{archetype::Archetype, registry::Registry, sink::Sink},
    system::param::Param,
};
use base::rt::UnsafeLocal;
use fetch::{Fetch, Scan};
use std::marker::PhantomData;

use crate::world::World;

pub mod fetch;

//SAFETY: Query will only be used by one thread at a time, so its inner RefCell is safe.
pub struct Query<'a, Q: fetch::Query + ?Sized>(UnsafeLocal<Fetch<'a, Q>>);

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

impl<'a, Q: fetch::Query> Param<'a> for Query<'a, Q> {
    fn inject(archetype: &mut Archetype) {
        archetype.merge(Q::archetype())
    }

    fn create(archetype: Archetype, table: &'a mut crate::component::table::Table) -> Self
    where
        Self: Sized + 'a,
    {
        dbg!(&table);
        Query(UnsafeLocal(Fetch {
            supertype: archetype,
            table,
            marker: PhantomData,
        }))
    }
}
