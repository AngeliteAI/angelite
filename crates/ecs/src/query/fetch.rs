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

    fn archetype(index: usize) -> Option<Archetype>;
    fn offsets(index: usize) -> Option<Array<usize, { Archetype::MAX }>>;
    fn deduce(state: &mut State, fetcher: &Fetch<Self>) -> Option<Self::Ref>;
    fn deduce_mut(state: &mut State, fetcher: &mut Fetch<Self>) -> Option<Self::Mut>;
}

use paste::paste;
ecs_macro::query!();

pub struct Fetch<'a, Q: Query + ?Sized> {
    pub(crate) supertypes: &'a [Archetype],
    pub(crate) tables: &'a mut [&'a mut Table],
    pub(crate) marker: PhantomData<Q>,
}

unsafe impl<Q: Query> Send for Fetch<'_, Q> {}

#[derive(Default, Debug, Clone, Copy)]
pub struct Cursor {
    route: Vector<2, usize>,
    max: Vector<2, usize>,
}

impl Cursor {
    fn init(tables: & [&mut Table]) -> Cursor {
        Self {
            route: Default::default(),
            max: Vector(Simd([tables[0].count(), tables.len()])),
        }
    }

    fn row(&self) -> usize {
        self.route[0]
    }
    fn table(&self) -> usize {
        self.route[1]
    }
}

impl AddAssign<usize> for Cursor {
    fn add_assign(&mut self, rhs: usize) {
        self.route += Vector::<2, usize>::X;
        for i in (0..1).rev() {
            if self.route[i] >= self.max[i]  {
                self.route[i] = 0;
                self.route[i+1] +=1;
            }
        }
    }
}

impl Cursor {
    fn row_finished(&self) -> bool {
        self.route[0] == self.max[0]
    }
    fn table_finished(&self) -> bool {
         self.route[1] == self.max[1]
    }
}

#[derive(Clone)]
pub struct State {
    index: usize,
    offsets: Array<usize, 256>,
    supertype: Archetype,
    cursor: Cursor,
}

impl State {
    fn init<Q: Query>(shard: &[&mut Table], old: Option<State>) -> Option<State> {
        let index = old.map(|state| state.index + 1).unwrap_or(0);
        Some(Self {
            index,
            offsets: Q::offsets(index)?,
            supertype: Q::archetype(index)?,
            cursor: Cursor::init(shard),
        })
    }
    fn check<Q: Query>(&mut self, fetcher: &Fetch<Q>) -> bool {
        if self.cursor.row_finished() {
            if let Some(state) = State::init::<Q>(fetcher.tables, Some(self.clone())) {
                *self = state;
            }
        }
        if self.cursor.table_finished() {
            return true;
        }
        false
    }
}

pub struct Scan<F> {
    fetcher: F,
    state: State,
}

impl<'a, 'b, Q: Query> Scan<&'b Fetch<'a, Q>> {
    pub fn new(fetcher: &'a Fetch<'a, Q>) -> Self {
        Scan {
            state: State::init::<Q>(fetcher.tables, None).unwrap(),
            fetcher,
        }
    }
}
impl<'a, 'b, Q: Query> Scan<&'b mut Fetch<'a, Q>> {
    pub fn new_mut(fetcher: &'a mut Fetch<'a, Q>) -> Self {
        Scan {
            state: State::init::<Q>(fetcher.tables, None).unwrap(),
            fetcher,
        }
    }
}

impl<'a, Q: Query> Iterator for Scan<&'a Fetch<'a, Q>> {
    type Item = Q::Ref;

    fn next(&mut self) -> Option<Self::Item> {
        let ret = Q::deduce(&mut self.state, self.fetcher);

        self.state.cursor += 1;

        ret
    }
}

impl<'a, Q: Query> Iterator for Scan<&'a mut Fetch<'a, Q>> {
    type Item = Q::Mut;

    fn next(&mut self) -> Option<Self::Item> {
        let ret = Q::deduce_mut(&mut self.state, self.fetcher);

        self.state.cursor += 1;

        ret
    }
}
