use std::pin::Pin;
use flume::Receiver;
use base::rt::Handle;
use func::{Finished, Return};
use crate::system::func::Cmd;

pub mod func;
pub mod graph;
pub mod param;
pub mod sequence;

pub type System = Pin<Box<dyn Fn(Receiver<Cmd>) -> Handle<Result<Return, Finished>>>>;
