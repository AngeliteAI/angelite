#![feature(specialization, negative_impls, negative_bounds, slice_pattern)]

use core::{mem, slice};
use std::{borrow::Borrow, collections::HashMap, ptr, rc::Rc, sync::Arc};
mod ops2;
use opcode_registry::Op;
use ops2::SerializeCopy;
use ops2::slice::*;

pub use opcode_macro::op;
pub use opcode_registry as registry;

use crate::ops2::OpCode;

unsafe fn reinterpret<T, U>(input: T) -> U {
       let out = unsafe { ptr::read(&input as *const _ as *const _) };
        mem::forget(input);
        out
    
}



// Core encoder trait - simple and focused
pub trait Encoder {
    fn write_bytes(&mut self, bytes: &[u8]) -> Result<(), Error>;
    fn bytes(&self) -> &[u8];
    fn stack(&mut self) -> &mut Vec<Op>;
    fn sub(&'_ self) -> Box<dyn Encoder + '_>;
}

// Basic decoder trait
pub trait Decoder {
    fn decode_bytes(&mut self, bytes: &[u8]) -> Result<(), Error>;
    fn interpret<T: Decode>(self) -> Result<<T as Owner>::Owned, Error>;
    fn read_bytes(&mut self, len: usize) -> Result<&[u8], Error>;
}

// Core encoding trait - types implement this to define how they encode
pub trait Encode {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error>;
}

// Extension trait for ergonomic encoding methods using opcodes
pub trait Encodable: Encode {
    /// Encode a Copy type using the EncodeCopyable opcode
    fn encode_copyable<E: Encoder>(&self, encoder: &mut E) -> Result<(), Error> 
    where 
        Self: Copy + 'static,
    {
        let opcode = SerializeCopy::new(*self);
        opcode.encode(encoder)
    }
    
    /// Encode to a Vec<u8> using a simple byte encoder
    fn to_bytes(&self) -> Result<Vec<u8>, Error> {
        let mut encoder = ByteVecEncoder::new();
        self.encode(&mut encoder)?;
        Ok(encoder.bytes().to_vec())
    }
    
    /// Encode with a specific encoder type
    fn encode_with<E: Encoder>(&self, mut encoder: E) -> Result<Vec<u8>, Error> {
        self.encode(&mut encoder)?;
       Ok(encoder.bytes().to_vec())
    }
    
}

// Blanket implementation - all Encode types get Encodable methods
impl<T: Encode> Encodable for T {}

// Blanket implementation for anything that implements Encode + Decode
impl<T: Encode + Decode> Serialize for T {}

// Simple byte vector encoder implementation
// Simple byte vector encoder implementation
pub struct ByteVecEncoder {
    buffer: Vec<u8>,
    stack: Vec<Op>,
}

impl ByteVecEncoder {
    pub fn new() -> Self {
        Self {
            buffer: vec!(),
            stack: vec!(),
        }
    }
    
    pub fn with_capacity(capacity: usize) -> Self {
        Self {
            buffer: Vec::with_capacity(capacity),
            stack: vec![],
        }
    }
}

impl Encoder for ByteVecEncoder {
    fn write_bytes(&mut self, bytes: &[u8]) -> Result<(), Error> {
        self.buffer.extend_from_slice(bytes);
        Ok(())
    }
    

    fn bytes(&self) -> &[u8] {
        &self.buffer
    }
    
    fn sub(&'_ self) -> Box<dyn Encoder + '_> {
    Box::new(ByteVecEncoder::new())
    }
    
    fn stack(&mut self) -> &mut Vec<Op> {
        &mut self.stack
    }
}

// Implement Encoder for mutable references to Encoders
impl<E: Encoder> Encoder for &mut E {
    fn write_bytes(&mut self, bytes: &[u8]) -> Result<(), Error> {
        (**self).write_bytes(bytes)
    }
    
 
    fn bytes(&self) -> &[u8] {
    (**self).bytes()
    }
    
    fn sub(&'_ self) -> Box<dyn Encoder + '_> {
        (**self).sub()
    }
    
    fn stack(&mut self) -> &mut Vec<Op> {
        (&mut (**self)).stack()
    }
}

pub trait Owner {
    type Owned;
    fn to_owned(self) -> Self::Owned;
}

impl<'a, T: Clone> Owner for &'a [T] {
    type Owned = Vec<T>;
    fn to_owned(self) -> Self::Owned {
    self.to_vec()
    }
}

impl<T> Owner for T {
    default type Owned = Self;
    default fn to_owned(self) -> Self::Owned {
        unsafe { reinterpret(self) }
    }
}

pub trait Decode: Owner {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> where Self: Sized;
}


pub trait Serialize: Encode + Decode {
    fn serialize(&self) -> Result<Vec<u8>, Error> where Self: Encode {
        let mut encoder = ByteVecEncoder::new();
        self.encode(&mut encoder)?;
        Ok(encoder.bytes().to_vec())
    }
    
    fn deserialize(bytes: &[u8]) -> Result<<Self as Owner>::Owned, Error> where Self: Sized {
        let mut decoder = ByteSliceDecoder::new(bytes);
        Self::decode(&mut decoder)
    }
}

// Simple decoder implementation
pub struct ByteSliceDecoder<'a> {
    data: &'a [u8],
    position: usize,
}

impl<'a> ByteSliceDecoder<'a> {
    pub fn new(data: &'a [u8]) -> Self {
        Self { data, position: 0 }
    }
    
    pub fn read_bytes(&mut self, len: usize) -> Result<&'a [u8], Error> {
        if self.position + len > self.data.len() {
            return Err(Error::DecodingError);
        }
        let result = &self.data[self.position..self.position + len];
        self.position += len;
        Ok(result)
    }
}

impl<'a> Decoder for ByteSliceDecoder<'a> {
    fn decode_bytes(&mut self, bytes: &[u8]) -> Result<(), Error> {
        // This could verify the bytes match what we're reading
        let _read = self.read_bytes(bytes.len())?;
        Ok(())
    }
    
    fn interpret<T: Decode>(mut self) -> Result<<T as Owner>::Owned, Error> {
        T::decode(&mut self)
    }
    
    fn read_bytes(&mut self, len: usize) -> Result<&[u8], Error> {
        if self.position + len > self.data.len() {
            return Err(Error::DecodingError);
        }
        let result = &self.data[self.position..self.position + len];
        self.position += len;
        Ok(result)
    }
}

#[test]
fn test() {
    let mut encoder = ByteVecEncoder::new();
    let slice = [0u16, 5, 2, 10];
    slice.as_slice().encode(&mut encoder);
    dbg!(encoder.bytes());

}