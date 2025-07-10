use super::OpCode;
use crate::registry::OpName;
use crate::*;
use crate::{Decode, Decoder, Encode, Encoder, Error, Serialize};
use core::mem;

/// A variable-length integer that encodes to the minimum number of bytes needed
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct Int(pub u64);

impl Int {
    pub fn new(value: u64) -> Self {
        Self(value)
    }

    pub fn into_inner(self) -> u64 {
        self.0
    }

    /// Calculate the minimum number of bytes needed to represent this value
    fn byte_length(&self) -> u8 {
        if self.0 == 0 {
            1
        } else {
            ((64 - self.0.leading_zeros() + 7) / 8) as u8
        }
    }

    /// Get the bytes representation with minimum length
    fn to_bytes(&self) -> (u8, Vec<u8>) {
        let length = self.byte_length();
        let mut bytes = Vec::with_capacity(length as usize);
        
        // Convert to little-endian bytes and take only the needed bytes
        let full_bytes = self.0.to_le_bytes();
        bytes.extend_from_slice(&full_bytes[..length as usize]);
        
        (length, bytes)
    }

    /// Reconstruct from length and bytes
    fn from_bytes(length: u8, bytes: &[u8]) -> Result<Self, Error> {
        if bytes.len() != length as usize || length == 0 || length > 8 {
            return Err(Error::DecodingError);
        }

        let mut padded = [0u8; 8];
        padded[..length as usize].copy_from_slice(bytes);
        
        Ok(Int(u64::from_le_bytes(padded)))
    }
}

impl From<u64> for Int {
    fn from(value: u64) -> Self {
        Self::new(value)
    }
}

impl From<Int> for u64 {
    fn from(varint: Int) -> Self {
        varint.0
    }
}

impl From<usize> for Int {
    fn from(value: usize) -> Self {
        Self::new(value as u64)
    }
}

impl From<Int> for usize {
    fn from(varint: Int) -> Self {
        varint.0 as usize
    }
}

/// Opcode for encoding variable-length integers
#[derive(Debug, Clone)]
#[op]
pub struct SerializeInt {
    pub value: Int,
}

impl SerializeInt {
    pub fn new(value: Int) -> Self {
        Self { value }
    }

    pub fn into_inner(self) -> Int {
        self.value
    }
}

impl Encode for SerializeInt {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        let (length, bytes) = self.value.to_bytes();
        
        // First byte is the length
        encoder.write_bytes(&[length])?;
        
        // Then the actual bytes
        encoder.write_bytes(&bytes)
    }
}

impl Decode for SerializeInt {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error>
    where
        Self: Sized,
    {
        // Read the length byte
        let length_bytes = decoder.read_bytes(1)?;
        let length = length_bytes[0];

        // Read the actual value bytes
        let value_bytes = decoder.read_bytes(length as usize)?;
        
        let varint = Int::from_bytes(length, value_bytes)?;
        Ok(unsafe { reinterpret(SerializeInt::new(varint)) })
    }
}

impl Encode for Int {
    fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
        let opcode = SerializeInt::new(*self);
        opcode.encode(encoder)
    }
}

impl Decode for Int {
    fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> {
        SerializeInt::decode(decoder).map(|x| unsafe { reinterpret(x.into_inner()) })
    }
}

impl Owner for Int {
    type Owned = Int;
    fn to_owned(self) -> Self::Owned {
        unsafe { reinterpret(self) }
    }
}

impl Owner for SerializeInt {
    type Owned = SerializeInt;
    fn to_owned(self) -> Self::Owned {
        unsafe { reinterpret(self) }
    }
}
macro_rules! impl_serialize_varint {
    ($($ty:ty),* $(,)?) => {
        $(
            impl Encode for $ty {
                fn encode<E: Encoder + ?Sized>(&self, encoder: &mut E) -> Result<(), Error> {
                    let opcode = SerializeInt::new(Int(*self as u64));
                    opcode.encode(encoder)
                }
            }

            impl Decode for $ty {
                fn decode<D: Decoder>(decoder: &mut D) -> Result<<Self as Owner>::Owned, Error> {
                    SerializeInt::decode(decoder).map(|x| unsafe { reinterpret(x.value.0 as $ty) }) 
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

// Apply the macro to all varint types
impl_serialize_varint! {
    u8, u16, u32, u64, u128, usize,
    i8, i16, i32, i64, i128, isize,
}
   
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_varint_byte_length() {
        assert_eq!(Int::new(0).byte_length(), 1);
        assert_eq!(Int::new(255).byte_length(), 1);
        assert_eq!(Int::new(256).byte_length(), 2);
        assert_eq!(Int::new(65535).byte_length(), 2);
        assert_eq!(Int::new(65536).byte_length(), 3);
        assert_eq!(Int::new(u64::MAX).byte_length(), 8);
    }

}
