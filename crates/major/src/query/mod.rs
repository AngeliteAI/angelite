use std::marker::PhantomData;

use fast::{collections::arrayvec::ArrayVec, prelude::Vector};

use crate::component::archetype::Archetype;

pub trait Query {
    type Ref;
    type Mut;

    fn archetype() -> Archetype;

    fn query<'a>(world: &'a mut World) -> Fetch<Self>
    where
        Self: Sized,
    {
        todo!()
    }

    fn offsets() -> Array<usize, { Archetype::MAX }>;
    fn deduce(state: &mut State) -> Option<Self::Ref>;
    fn deduce_mut(state: &mut State) -> Option<Self::Mut>;
}

pub struct Fetch<Q: Query> {
    shard: Shard,
    marker: PhantomData<Q>,
}

unsafe impl<Q: Query> Send for Fetch<Q> {}

impl<'a, Q: Query> IntoIterator for &'a Fetch<Q> {
    type Item = Q::Ref;
    type IntoIter = Scan<'a, Q>;

    fn into_iter(self) -> Self::IntoIter {
        todo!()
    }
}

impl<'a, Q: Query> IntoIterator for &'a mut Fetch<Q> {
    type Item = Q::Mut;
    type IntoIter = Scan<'a, Q>;

    fn into_iter(self) -> Self::IntoIter {
        todo!()
    }
}

pub struct Cursor {
    route: Vector<3, usize>,
    max: Vector<3, usize>,
}

impl Cursor {
    fn shard(&self) -> usize {
        let [x] = self.route.x();
    }
}
