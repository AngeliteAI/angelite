use fast::collections::arrayvec::ArrayVec;

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
