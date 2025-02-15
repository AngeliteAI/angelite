use std::{marker::PhantomData, ops::AddAssign};

use fast::{
    collections::{array::Array, arrayvec::ArrayVec},
    prelude::{Pattern, Vector, X, Y, Z},
};

use crate::{
    component::{archetype::Archetype, registry::Shard},
    world::World,
};

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
    type IntoIter = Scan<Self>;

    fn into_iter(self) -> Self::IntoIter {
        todo!()
    }
}

impl<'a, Q: Query> IntoIterator for &'a mut Fetch<Q> {
    type Item = Q::Mut;
    type IntoIter = Scan<Self>;

    fn into_iter(self) -> Self::IntoIter {
        todo!()
    }
}

#[derive(Default)]
pub struct Cursor {
    route: Vector<3, usize>,
    max: Vector<3, usize>,
}

impl Cursor {
    fn shard(&self) -> usize {
        let [x] = **self.route.shuffle::<X, 1>();
        x
    }
    fn table(&self) -> usize {
        let [y] = **self.route.shuffle::<Y, 1>();
        y
    }
    fn row(&self) -> usize {
        let [z] = **self.route.shuffle::<Z, 1>();
        z
    }
}

impl AddAssign<usize> for Cursor {
    fn add_assign(&mut self, rhs: usize) {
        self.route += Vector::<3, usize>::X * rhs;
        for i in 0..2 {
            while self.route[i] > self.max[i] {
                self.route[i] -= self.max[i];
                self.route[i + 1] += 1;
            }
        }
    }
}

impl Cursor {
    fn finished(&self) -> bool {
        self.route == self.max
    }
}

pub struct State {
    shard: Shard,
    offsets: Array<usize, 256>,
    supertype: Archetype,
    cursor: Cursor,
}

impl State {
    fn init<Q: Query>(shard: Shard) -> State {
        Self {
            shard,
            offsets: Q::offsets(),
            supertype: Q::archetype(),
            cursor: Cursor::default(),
        }
    }
}

pub struct Scan<F> {
    fetcher: PhantomData<F>,
    state: State,
}

impl<'a, Q: Query> Iterator for Scan<&'a Fetch<Q>> {
    type Item = Q::Ref;

    fn next(&mut self) -> Option<Self::Item> {
        if self.state.cursor.finished() {
            return None;
        }

        let ret = Q::deduce(&mut self.state);

        self.state.cursor += 1;

        ret
    }
}

impl<'a, Q: Query> Iterator for Scan<&'a mut Fetch<Q>> {
    type Item = Q::Mut;

    fn next(&mut self) -> Option<Self::Item> {
        if self.state.cursor.finished() {
            return None;
        }

        let ret = Q::deduce_mut(&mut self.state);

        self.state.cursor += 1;

        ret
    }
}
