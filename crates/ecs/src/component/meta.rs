use base::collections::{array::Array, arrayvec::ArrayVec};

use super::archetype::Archetype;

pub struct Metashard {
    tables: Array<Metatable, 64>,
}

pub struct Metatable {
    supertype: Archetype,
    pub(crate) page_heads: ArrayVec<*mut u8, 64>,
}

impl Metatable {
    pub fn init(supertype: Archetype) -> Self {
        Metatable {
            supertype,
            page_heads: Default::default(),
        }
    }
}

unsafe impl Send for Metatable {}
