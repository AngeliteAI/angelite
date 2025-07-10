use super::OpCode;
use crate::registry::OpName;
use crate::*;
use crate::{Decode, Decoder, Encode, Encoder, Error, Serialize};
use core::mem;

/// Trait to mark primitive types that can be serialized with SerializePrimitive
pub trait Primitive: Copy + 'static {}

/// Trait to mark non-primitive Copy types that can be serialized with SerializeCopy
pub trait NotPrimitive: Copy + 'static {}

/// Opcode for encoding primitive types by transmuting to bytes
#[derive(Debug, Clone)]
#[op]
pub struct SerializePrimitive<T: Primitive> {
    pub value: T,
}

impl<T: Primitive> SerializePrimitive<T> {
    pub fn new(value: T) -> Self {
        Self { value }
    }
    pub fn into_inner(self) -> T {
        self.value
    }
}

impl<T: Primitive> Encode for SerializePrimitive<T> {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        let bytes =
            unsafe { core::slice::from_raw_parts(&self.value as *const T as *const u8, mem::size_of::<T>()) };

        encoder.write_bytes(bytes)
    }
}

impl<T: Primitive> Decode for SerializePrimitive<T> {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error>
    where
        Self: Sized,
    {
        // Read the actual data
        let value_bytes = decoder.read_bytes(mem::size_of::<T>() as usize)?;
        let value = unsafe { std::ptr::read(value_bytes.as_ptr() as *const T) };

        Ok(unsafe { reinterpret(value) })
    }
}
macro_rules! impl_serialize_primitive {
    ($($ty:ty),* $(,)?) => {
        $(
            impl Encode for $ty {
                fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
                    let opcode = SerializePrimitive::new(*self);
                    opcode.encode(encoder)
                }
            }

            impl Decode for $ty {
                fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> {
                    SerializePrimitive::<$ty>::decode(decoder).map(|x| unsafe { reinterpret(x) })
                }
            }
            
            impl Owner for $ty {
                type Owned = $ty;
                fn to_owned(self) -> Self::Owned {
                    self
                }
            }
        )*
    };
}

// Apply the macro to all primitive types
impl_serialize_primitive! {
    f32, f64,
    bool,
    char,
}

// Implement Primitive trait for all primitive types
impl Primitive for u8 {}
impl Primitive for u16 {}
impl Primitive for u32 {}
impl Primitive for u64 {}
impl Primitive for u128 {}
impl Primitive for usize {}
impl Primitive for i8 {}
impl Primitive for i16 {}
impl Primitive for i32 {}
impl Primitive for i64 {}
impl Primitive for i128 {}
impl Primitive for isize {}
impl Primitive for f32 {}
impl Primitive for f64 {}
impl Primitive for bool {}
impl Primitive for char {}
