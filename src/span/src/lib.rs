#![feature(random)] // Enable the random feature for nightly

pub use serde::{Deserialize, Serialize};
pub mod error;
pub mod interface;
pub mod raft;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub struct Node(pub u128);
pub trait State<Cmd> {
    type Output;
    type Error;

    /// Note: This method takes reference, not mutable, to self; this allows for
    /// easier composition of state.
    fn process(&self, command: &[(Node, Cmd)]) -> Result<Self::Output, Self::Error>;
    fn tick(&self) -> Result<(), Self::Error>;
}
