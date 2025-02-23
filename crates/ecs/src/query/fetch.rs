use crate::component::{sink::Sink, table::Table};
use crate::{
    component::{archetype::Archetype, registry::Shard},
    world::World,
};
use base::{
    Simd,
    collections::{array::Array, arrayvec::ArrayVec},
    prelude::{Pattern, Vector, X, Y, Z},
};
use std::cmp::max;
use std::{marker::PhantomData, ops::AddAssign};

pub trait Query: ?Sized {
    type Ref;
    type Mut;

    fn archetype() -> Archetype;
    fn offsets() -> Array<usize, { Archetype::MAX }>;
    fn deduce(state: &mut State, fetcher: &Fetch<Self>) -> Option<Self::Ref>;
    fn deduce_mut(state: &mut State, fetcher: &mut Fetch<Self>) -> Option<Self::Mut>;
}

use paste::paste;
ecs_macro::query!();

pub struct Fetch<'a, Q: Query + ?Sized> {
    pub(crate) supertype: Archetype,
    pub(crate) table: &'a mut Table,
    pub(crate) marker: PhantomData<Q>,
}

unsafe impl<Q: Query> Send for Fetch<'_, Q> {}

#[derive(Default, Clone, Copy)]
pub struct Cursor {
    route: usize,
    max: usize,
}

impl Cursor {
    fn init(table: &Table) -> Cursor {
        Self {
            route: Default::default(),
            max: table.count(),
        }
    }

    fn row(&self) -> usize {
        self.route
    }
}

impl AddAssign<usize> for Cursor {
    fn add_assign(&mut self, rhs: usize) {
        self.route += rhs;
        if self.route > self.max {
            self.route = self.max;
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
    fn init<Q: Query>(shard: &Table) -> State {
        Self {
            offsets: Q::offsets(),
            supertype: Q::archetype(),
            cursor: Cursor::init(shard),
        }
    }
}

pub struct Scan<F> {
    fetcher: F,
    state: State,
}

impl<'a, Q: Query> Scan<&'a Fetch<'a, Q>> {
    pub fn new(fetcher: &'a Fetch<Q>) -> Self {
        Scan {
            state: State::init::<Q>(&fetcher.table),
            fetcher,
        }
    }
}
impl<'a, Q: Query> Scan<&'a mut Fetch<'a, Q>> {
    pub fn new_mut(fetcher: &'a mut Fetch<'a, Q>) -> Self {
        Scan {
            state: State::init::<Q>(&fetcher.table),
            fetcher,
        }
    }
}

impl<'a, Q: Query> Iterator for Scan<&'a Fetch<'a, Q>> {
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

impl<'a, Q: Query> Iterator for Scan<&'a mut Fetch<'a, Q>> {
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
