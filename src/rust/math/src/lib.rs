#![feature(core_intrinsics, try_blocks, repr_simd)]

use derive_more::derive::{Deref, DerefMut};
use num_traits::Num;
use vector::Vector;

pub mod vector;

#[repr(simd)]
#[derive(Deref, DerefMut, Clone, Copy, Debug, PartialEq, Eq)]
pub struct Simd<const N: usize, T: Num>(pub [T; N]);

impl<const N: usize, T: Num + Copy> Simd<N, T> {
    pub fn splat(value: T) -> Self {
        Self([value; N])
    }
}

impl<const N: usize, T: Num + Copy> Default for Vector<N, T> {
    fn default() -> Self {
        Self::splat(T::zero())
    }
}

impl<const N: usize, T: Num + Copy> FromIterator<T> for Simd<N, T> {
    fn from_iter<I: IntoIterator<Item = T>>(data: I) -> Self {
        let mut iter = data.into_iter();
        let mut data = [T::zero(); N];

        #[allow(clippy::needless_range_loop)]
        //Loop is not needless, writing it this way ensures the iterator is the exact size
        let right_sized: Option<()> = try {
            for i in 0..N {
                data[i] = iter.next()?;
            }
            iter.next().is_none().then_some(())?
        };
        assert!(right_sized.is_some());

        Self::from_array(data)
    }
}

impl<const N: usize, T: Num + Copy> Simd<N, T> {
    const fn from_array(data: [T; N]) -> Self {
        Self(data)
    }
}
