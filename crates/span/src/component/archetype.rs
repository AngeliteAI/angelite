use std::iter;

use derive_more::derive::{Deref, DerefMut};
use fast::collections::array::Array;

use super::Meta;

#[derive(Clone, Ord, Eq, PartialEq, Default, Debug, Deref, DerefMut, Hash)]
pub struct Archetype(Array<Meta, { Self::MAX }>);

impl PartialOrd for Archetype {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        if self == other {
            return Some(std::cmp::Ordering::Equal);
        }

        let supertype = self
            .iter()
            .all(|x| other.iter().find(|y| y.id == x.id).is_some());

        Some(if supertype {
            std::cmp::Ordering::Greater
        } else {
            std::cmp::Ordering::Less
        })
    }
}

impl FromIterator<Meta> for Archetype {
    fn from_iter<I: IntoIterator<Item = Meta>>(iter: I) -> Self {
        Self(iter.into_iter().collect())
    }
}

impl From<Meta> for Archetype {
    fn from(meta: Meta) -> Self {
        Self::from_iter(iter::once(meta))
    }
}

impl Archetype {
    pub const MAX: usize = 256;
    pub fn size(&self) -> usize {
        self.iter().copied().map(|x| x.size).sum::<usize>().max(1)
    }
    pub fn count(&self) -> usize {
        self.len()
    }
}
