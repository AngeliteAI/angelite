use base::collections::arrayvec::ArrayVec;
use std::cell::UnsafeCell;
use std::ops::AddAssign;
use std::{collections::HashMap, iter};

use crate::entity::Entity;

use super::{archetype::Archetype, source::Source, table::Table};

pub const STACK: usize = 1024;
pub type Entities = ArrayVec<Entity, STACK>;

pub(crate) enum Shard {
    Map {
        tables: UnsafeCell<HashMap<Archetype, &'static mut Table>>,
    },
    Linear {
        tables: UnsafeCell<Vec<(Archetype, &'static mut Table)>>,
    },
}

impl AddAssign<Shard> for Shard {
    fn add_assign(&mut self, other: Shard) {
        match (self, other) {
            (
                Shard::Map { tables },
                Shard::Map {
                    tables: other_tables,
                },
            ) => {
                let tables = unsafe { tables.get().as_mut().unwrap() };
                let other_tables = unsafe { other_tables.get().as_mut().unwrap() };
                for (archetype, table) in other_tables.drain() {
                    tables.insert(archetype, table);
                }
            }
            (
                Shard::Linear { tables },
                Shard::Linear {
                    tables: other_tables,
                },
            ) => {
                let tables = unsafe { tables.get().as_mut().unwrap() };
                let other_tables = unsafe { other_tables.get().as_mut().unwrap() };
                tables.extend(other_tables.drain(..));
            }
            (
                Shard::Linear { tables },
                Shard::Map {
                    tables: other_tables,
                },
            ) => {
                let tables = unsafe { tables.get().as_mut().unwrap() };
                let other_tables = unsafe { other_tables.get().as_mut().unwrap() };
                for (archetype, table) in other_tables.drain() {
                    tables.push((archetype, table));
                }
            }
            (
                Shard::Map { tables },
                Shard::Linear {
                    tables: other_tables,
                },
            ) => {
                let tables = unsafe { tables.get().as_mut().unwrap() };
                let other_tables = unsafe { other_tables.get().as_mut().unwrap() };
                for (archetype, table) in other_tables.drain(..) {
                    tables.insert(archetype, table);
                }
            }
        }
    }
}

impl Shard {
    pub(crate) fn table_map(&self) -> Option<&HashMap<Archetype, &'static mut Table>> {
        match self {
            Shard::Map { tables } => Some(unsafe { tables.get().as_mut().unwrap() }),
            Shard::Linear { .. } => {
                panic!("not a table map")
            }
        }
    }

    pub(crate) fn table_slice(&self) -> Option<&[(Archetype, &'static mut Table)]> {
        match self {
            Shard::Map { tables } => panic!("not a table slice"),
            Shard::Linear { tables } => Some(unsafe { tables.get().as_mut().unwrap() }),
        }
    }

    pub(crate) fn table_vec(&self) -> Option<&mut Vec<(Archetype, &'static mut Table)>> {
        match self {
            Shard::Map { tables } => panic!("not a table slice"),
            Shard::Linear { tables } => Some(unsafe { tables.get().as_mut().unwrap() }),
        }
    }

    pub(crate) fn table_map_mut(&self) -> Option<&mut HashMap<Archetype, &'static mut Table>> {
        match self {
            Shard::Map { tables } => Some(unsafe { tables.get().as_mut().unwrap() }),
            Shard::Linear { .. } => {
                panic!("not a table map")
            }
        }
    }

    pub(crate) fn table_slice_mut(&self) -> Option<&mut [(Archetype, &'static mut Table)]> {
        match self {
            Shard::Map { tables } => panic!("not a table slice"),
            Shard::Linear { tables } => Some(unsafe { tables.get().as_mut().unwrap() }),
        }
    }
}

impl Default for Shard {
    fn default() -> Self {
        Self::Map {
            tables: Default::default(),
        }
    }
}

#[derive(Default)]
pub struct Registry(Shard);

impl Registry {
    pub fn extend<Src: Source + 'static>(
        &mut self,
        src: impl IntoIterator<Item = Src>,
    ) -> Entities {
        let Self(shard) = self;
        let mut src = src.into_iter();
        let Some(first) = src.next() else {
            return Entities::new();
        };
        let archetype = unsafe { first.archetype() };
        let components = unsafe { first.erase_component_data() };
        let table = shard
            .table_map_mut()
            .expect("main shard should be a table map")
            .entry(archetype.clone())
            .or_insert_with(|| unsafe {
                Box::into_raw(Box::new(Table::with_archetype(archetype)))
                    .as_mut()
                    .unwrap()
            });
        let src =
            iter::once(components).chain(src.map(|src| unsafe { src.erase_component_data() }));
        table.extend(src).collect::<Entities>()
    }
    pub fn drop(&mut self, entity: impl IntoIterator<Item = Entity>) {
        let Self(shard) = self;
        let mut buckets = HashMap::<Archetype, Vec<Entity>>::default();

        let entities = entity.into_iter().collect::<Vec<Entity>>();
        entities
            .into_iter()
            .for_each(|x| buckets.entry(x.archetype().clone()).or_default().push(x));

        for (archetype, buckets) in buckets {
            let table = shard
                .table_map_mut()
                .expect("main shard should be a table map")
                .get_mut(&archetype)
                .unwrap();
            table.free(buckets);
        }
    }
    pub(crate) fn shard(&mut self, archetype: Archetype) -> Shard {
        let mut shard = Shard::Linear {
            tables: vec![].into(),
        };

        let mut table_take = vec![];
        if let Some(tables) = self.0.table_map() {
            for (table_arch, table) in tables {
                if table_arch >= &archetype {
                    table_take.push(table_arch.clone());
                }
            }
        }

        for table_arch in table_take {
            let table = dbg!(self.0.table_map_mut().unwrap().remove(&table_arch).unwrap());
            shard.table_vec().unwrap().push((table_arch, table));
        }

        shard
    }
}
