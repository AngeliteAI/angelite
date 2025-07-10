
// Encoding opcode modules
pub mod copy;
pub mod primitive;
pub mod slice;
pub mod int;
use std::{any::Any, ops};

use crate::{registry, Serialize};

pub trait OpCode  {
   type Repr: Serialize;
   const ID: Self::Repr;
   const NAME: registry::OpName;
   fn execute(&mut self);
}

// Re-export the main opcodes
pub use copy::SerializeCopy;