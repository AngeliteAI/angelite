#![allow(unused)]
use num_traits::Zero;

use crate::{reinterpret, Decode, Decoder, Encode, Encoder, Error, Owner, Serialize};
use core::mem;
use core::slice::SlicePattern;
use std::default;
use crate::ops2::OpCode;
use crate::registry::OpName;
use crate::op;

/// Opcode for encoding slices using smart encoding
#[derive(Debug, Clone)]
#[op]
pub enum SerializeSlice<'a, T> {
    Owned(Vec<T>),
    Borrowed(&'a [T])
}

impl<'a, T> SlicePattern for SerializeSlice<'a, T> {
    type Item = T;

    fn as_slice(&self) -> &[Self::Item] {
        match self {
            Self::Owned(x) => x.as_slice(),
            Self::Borrowed(x) => x,
        }
    }
}


impl<'a, T: Encode + Decode > Encode for SerializeSlice<'a, T>  {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        // Encode the operation ID first
        Self::ID.encode(encoder)?;
        
        // Use SmartSlice encoding
          self.as_slice().len().encode(encoder);
        let mut subencoder = encoder.sub();
        let mut items = vec![];
        for item in self.as_slice() {
            items.push(item.encode(&mut *subencoder))
        }
        let bytes = subencoder.bytes().to_vec();
        drop(subencoder);
        encoder.write_bytes(&bytes); 
        Ok(())
    }
}


impl<'a, T: Encode + Decode > Decode for SerializeSlice<'a, T> {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> where Self: Sized {
        // Verify the operation ID matches
        let decoded_id = <Self as OpCode>::Repr::decode(decoder)?;
        if decoded_id != Self::ID {
            return Err(Error::DecodingError);
        }
        
        // Use SmartSlice decoding
        let len = usize::decode(decoder)?;
        let mut vec = vec![];
        for i in 0..len {
            vec.push(T::decode(decoder)?);
        }
        Ok(unsafe { reinterpret(SerializeSlice::Owned(vec).to_owned())})
    }
}


impl<'a, T: Encode + Decode > Encode for &'a [T] {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        SerializeSlice::Borrowed(self).encode(encoder)
    }
}
impl<'a, T: Encode + Decode > Decode for &'a [T] where <SerializeSlice<'a, T> as Owner>::Owned: SlicePattern<Item = T> {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> where Self: Sized {
         SerializeSlice::<T>::decode(decoder).map(|x| unsafe { reinterpret(x.as_slice().to_owned()) })
    }
}