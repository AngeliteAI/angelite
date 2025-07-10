use super::OpCode;
use crate::registry::OpName;
use crate::*;
use crate::{Decode, Decoder, Encode, Encoder, Error, Serialize};
use core::mem;
use super::primitive::Primitive;

/// Opcode for encoding Copy types by transmuting to bytes
/// This excludes primitive types which are handled by SerializePrimitive
#[derive(Debug, Clone)]
#[op]
pub struct CopyEncode<T: Copy + 'static>(T);

#[derive(Debug, Clone)]
#[op]
pub struct CopyDecode<T: Copy + 'static>(T);


impl<T: Copy> Encode for CopyEncode<T> {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        // Encode the operation ID first
        Self::ID.encode(encoder)?;

        let size = mem::size_of::<T>();
        let bytes =
            unsafe { core::slice::from_raw_parts(&self.value as *const T as *const u8, size) };

        // Encode size for safety
        (size as u32).encode(encoder)?;
        encoder.write_bytes(bytes)
    }
}

impl<T: Copy> Decode for CopyDecode<T> {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error>
    where
        Self: Sized,
    {
        // Verify the operation ID matches
        let decoded_id = <Self as OpCode>::Repr::decode(decoder)?;
        if decoded_id != Self::ID {
            return Err(Error::DecodingError);
        }

        // Read size and verify
        let size = u32::decode(decoder)?;
        if size != mem::size_of::<T>() as u32 {
            return Err(Error::DecodingError);
        }

        // Read the actual data
        let value_bytes = decoder.read_bytes(size as usize)?;
        let value = unsafe { std::ptr::read(value_bytes.as_ptr() as *const T) };

        Ok(unsafe { reinterpret(value) })
    }
}

// Blanket implementation for all Copy types
impl<T: Copy + 'static> Encode for T {
    default fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        let opcode = SerializeCopy::new(*self);
        opcode.encode(encoder)
    }
}

impl<T: Copy + 'static> Decode for T {
    default fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> {
        SerializeCopy::<T>::decode(decoder).map(|x| unsafe { reinterpret(x) })
    }
}

impl<T: Copy> Owner for T {
    default type Owned = T;
    default fn to_owned(self) -> Self::Owned {
        unsafe { reinterpret(self) }
    }
}