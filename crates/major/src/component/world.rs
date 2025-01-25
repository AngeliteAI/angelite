use std::{collections::HashMap, iter};

use fast::collections::arrayvec::ArrayVec;

use crate::entity::Entity;

use super::{archetype::Archetype, source::Source, table::Table};

pub const STACK: usize = 1024;
pub type Entities = ArrayVec<Entity, STACK>;

pub(crate) struct Shard {
    pub tables: HashMap<Archetype, Table>,
}

pub struct World(Shard);

impl World {
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
            .tables
            .entry(archetype.clone())
            .or_insert_with(|| Table::with_archetype(archetype));
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
            let table = shard.tables.get_mut(&archetype).unwrap();
            table.free(buckets);
        }
    }
}
