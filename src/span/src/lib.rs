#![feature(more_maybe_bounds, box_as_ptr, ptr_metadata, rustc_attrs, anonymous_lifetime_in_impl_trait, allocator_api, auto_traits, negative_impls, negative_bounds, specialization)] 

use std::sync::{Arc, RwLock};

pub use span_macro::bytecode;

use crate::serde::{Codec, Deserialize, Serialize};
pub mod error;
pub mod interface;
pub mod raft;
pub mod rng;
pub mod serde;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Node(pub u128);
pub trait State<Cmd> {
    type Output;
    type Error;

    /// Note: This method takes reference, not mutable, to self; this allows for
    /// easier composition of state.
    fn process(&self, command: &[(Node, Cmd)]) -> Result<Self::Output, Self::Error>;
    fn tick(&self) -> Result<Vec<(Node, Cmd)>, Self::Error>;
}

pub trait Encoder {
    fn encode_bytes(self) -> Vec<u8>;
}

pub trait Decoder {
    fn decode_bytes(bytes: &[u8]) -> Self;
}

pub fn raft<C: Codec, T: Serialize + for<'de> Deserialize<'de> + Clone>() -> raft::Processor<raft::Req<T>, raft::FineGrained<raft::Resp<T>, C>, raft::Resp<T>> {
    raft::Processor {
        machine: raft::FineGrained {
        inner: std::sync::Arc::new(raft::FineGrained::<T, Bincode>::default()),
        state: std::sync::Arc::new(std::sync::RwLock::new(raft::State::<T>::default())),
        rng: std::sync::Arc::new(rng::Time::default()),
        ser: std::marker::PhantomData,
    },
    state: Arc::new(RwLock::new(raft::State::<T>::default())),
}
}


