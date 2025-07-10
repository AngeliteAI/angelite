use std::any::TypeId;

pub enum Type {
    Struct,
    Enum,
    Union,
}

pub enum Error {
    EncodingError,
    DecodingError,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct OpName(pub &'static str);

pub type OpRepr = u8;

pub struct Op {
    pub name: OpName,
    pub id: OpRepr,
    pub type_id: TypeId,
    pub size: usize,
    pub execute: fn() -> Result<(), Error>,
}