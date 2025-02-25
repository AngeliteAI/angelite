use crate::{
    component::{archetype::Archetype, registry::Registry, sink::Sink},
    system::param::Param,
};
use base::rt::UnsafeLocal;
use fetch::{Fetch, Scan};
use std::{iter, marker::PhantomData, mem};

use crate::world::World;

pub mod fetch;

//SAFETY: Query will only be used by one thread at a time, so its inner RefCell is safe.
pub struct Query<'a, Q: fetch::Query + 'static + ?Sized>(UnsafeLocal<Fetch<'a, Q>>);

impl<'a, 'b: 'a, Q: fetch::Query> IntoIterator for &'a Query<'b, Q> {
    type Item = Q::Ref;
    type IntoIter = Scan<&'b Fetch<'b, Q>>;

    fn into_iter(self) -> Self::IntoIter {
        Self::IntoIter::new(unsafe { mem::transmute(&self.0) })
    }
}
impl<'a, 'b: 'a, Q: fetch::Query> IntoIterator for &'a mut Query<'b, Q> {
    type Item = Q::Mut;
    type IntoIter = Scan<&'b mut Fetch<'b, Q>>;

    fn into_iter(mut self) -> Self::IntoIter {
        Self::IntoIter::new_mut(unsafe { mem::transmute(&mut self.0) })
    }
}

impl<'a, Q: fetch::Query> Param<'a> for Query<'a, Q> {
    fn inject(archetypes: &mut Vec<Archetype>) {
        let mut index = 0;
        let mut iter = iter::repeat_with(|| {
            let archetype = Q::archetype(index);
            index += 1;
            archetype
        });

        while let Some(archetype) = iter.next().flatten() {
            archetypes.push(archetype);
        }
    }

    fn create(
        archetypes: &'a [Archetype],
        tables: &'a mut [&'a mut crate::component::table::Table],
    ) -> Self
    where
        Self: Sized + 'a,
    {
        Query(UnsafeLocal(Fetch {
            supertypes: archetypes,
            tables,
            marker: PhantomData,
        }))
    }
}
