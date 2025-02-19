use crate::component::sink::Sink;
use base::{
    collections::{array::Array, arrayvec::ArrayVec},
    prelude::{Pattern, Vector, X, Y, Z},
};
use std::{marker::PhantomData, ops::AddAssign};

use crate::{
    component::{archetype::Archetype, registry::Shard},
    world::World,
};

pub trait Query: Sized {
    type Ref;
    type Mut;

    fn archetype() -> Archetype;
    fn offsets() -> Array<usize, { Archetype::MAX }>;
    fn deduce(state: &mut State, fetcher: &Fetch<Self>) -> Option<Self::Ref>;
    fn deduce_mut(state: &mut State, fetcher: &mut Fetch<Self>) -> Option<Self::Mut>;
}

use paste::paste;
ecs_macro::query!();

pub struct Fetch<Q: Query> {
    shard: Shard,
    marker: PhantomData<Q>,
}

unsafe impl<Q: Query> Send for Fetch<Q> {}

#[derive(Default)]
pub struct Cursor {
    route: Vector<2, usize>,
    max: Vector<2, usize>,
}

impl Cursor {
    fn table(&self) -> usize {
        let [x] = **self.route.shuffle::<X, 1>();
        x
    }
    fn row(&self) -> usize {
        let [y] = **self.route.shuffle::<Y, 1>();
        y
    }
}

impl AddAssign<usize> for Cursor {
    fn add_assign(&mut self, rhs: usize) {
        self.route += Vector::<2, usize>::X * rhs;
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
    offsets: Array<usize, 256>,
    supertype: Archetype,
    cursor: Cursor,
}

impl State {
    fn init<Q: Query>() -> State {
        Self {
            offsets: Q::offsets(),
            supertype: Q::archetype(),
            cursor: Cursor::default(),
        }
    }
}

pub struct Scan<F> {
    fetcher: F,
    state: State,
}

impl<'a, Q: Query> Scan<&'a Fetch<Q>> {
    pub fn new(fetcher: &'a Fetch<Q>) -> Self {
        Scan {
            fetcher,
            state: State::init::<Q>(),
        }
    }
}
impl<'a, Q: Query> Scan<&'a mut Fetch<Q>> {
    pub fn new_mut(fetcher: &'a mut Fetch<Q>) -> Self {
        Scan {
            fetcher,
            state: State::init::<Q>(),
        }
    }
}

impl<'a, Q: Query> Iterator for Scan<&'a Fetch<Q>> {
    type Item = Q::Ref;

    fn next(&mut self) -> Option<Self::Item> {
        if self.state.cursor.finished() {
            return None;
        }

        let ret = Q::deduce(&mut self.state, self.fetcher);

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

        let ret = Q::deduce_mut(&mut self.state, self.fetcher);

        self.state.cursor += 1;

        ret
    }
}
