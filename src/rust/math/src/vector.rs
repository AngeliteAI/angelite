#![feature(core_intrinsics)]
use derive_more::derive::{Deref, DerefMut};
use num_traits::{Num, WrappingAdd};
use paste::paste;
use shuffle::Pattern;
use std::{intrinsics::simd::*, ops::*};

use crate::Simd;
macro_rules! vector {
        ($tokens:ty; $impl:tt) => {
            impl<const N: usize, T: Num + Copy> $tokens for Vector<N, T>
            $impl
        }
    }

macro_rules! vector_op {
    ($impl:ty; $fn:ident; $simd:ident) => {
        impl<const N: usize, T: Num + Copy> $impl for Vector<N, T> {
            type Output = Self;
            fn $fn(self, rhs: Self) -> Self::Output {
                let (Self(a), Self(b)) = (self, rhs);
                let c = unsafe { $simd(a, b) };
                Self(c)
            }
        }

        paste! {
            impl<const N: usize, T: Num + Copy> [<$impl Assign>] for Vector<N, T> {
                fn [<$fn _assign>](&mut self, rhs: Self) {
                    let (Self(a), Self(b)) = (*self, rhs);
                    let c = unsafe { $simd(a, b) };
                    *self = Self(c);
                }
            }
        }
    };
}

macro_rules! vector_op_splat {
    ($impl:ty; $fn:ident; $simd:ident) => {
        paste! {
            impl<const N: usize, T: Num + Copy> $impl<T> for Vector<N, T> {
                type Output = Self;
                fn $fn(self, rhs: T) -> Self::Output {
                    self.$fn(Self::splat(rhs))
                }
            }

            impl<const N: usize, T: Num + Copy> [<$impl Assign>]<T> for Vector<N, T> {
                fn [<$fn _assign>](&mut self, rhs: T) {
                    self.[<$fn _assign>](Self::splat(rhs))
                }
            }
        }
    };
}

macro_rules! vector_ops {
    ($impl:ty; $fn:ident; $simd:ident) => {
        vector_op!($impl; $fn; $simd);
        vector_op_splat!($impl; $fn; $simd);
    };
}

#[repr(transparent)]
#[derive(Debug, Deref, DerefMut, PartialEq, Eq, Clone, Copy)]
pub struct Vector<const N: usize, T: Num + Copy = f32>(pub Simd<N, T>);

math_macro::vector_constants!(Vector, f32, 0.0f32, 1.0f32);
math_macro::vector_constants!(Vector, u32, 0u32, 1u32);
math_macro::vector_constants!(Vector, usize, 0usize, 1usize);

impl<const N: usize, T: Num + Copy> Vector<N, T> {
    pub const fn from_array(data: [T; N]) -> Self {
        Self(Simd::from_array(data))
    }
}

impl<const N: usize, T: Num + Copy> Vector<N, T> {
    pub fn new(data: impl IntoIterator<Item = T, IntoIter = impl ExactSizeIterator>) -> Self {
        Self::from_iter(data)
    }

    pub fn as_ptr(&self) -> *const T {
        self.0.as_ptr()
    }

    #[inline(always)]
    pub const fn splat(value: T) -> Self {
        Self(Simd::from_array([value; N]))
    }

    #[inline(always)]
    pub fn zeros() -> Self {
        Self::splat(T::zero())
    }

    #[inline(always)]
    pub fn ones() -> Self {
        Self::splat(T::one())
    }
}

vector!(Index<usize>; {
    type Output = T;

    #[inline(always)]
    fn index(&self, index: usize) -> &Self::Output {
        &self.0[index]
    }
});

vector!(IndexMut<usize>; {
    #[inline(always)]
    fn index_mut(&mut self, index: usize) -> &mut Self::Output {
        &mut self.0[index]
    }
});

vector!(FromIterator<T>; {
    fn from_iter<I: IntoIterator<Item = T>>(iter: I) -> Self {
        Self(iter.into_iter().collect())
    }
});

vector_ops!(Add; add; simd_add);
vector_ops!(Sub; sub; simd_sub);
vector_ops!(Mul; mul; simd_mul);
vector_ops!(Div; div; simd_div);
vector_ops!(BitXor; bitxor; simd_xor);
vector_ops!(BitOr; bitor; simd_or);
vector_ops!(BitAnd; bitand; simd_and);
vector_ops!(Shl; shl; simd_shl);
vector_ops!(Shr; shr; simd_shr);

impl<const N: usize, T: Num + Copy> Neg for Vector<N, T> {
    type Output = Self;
    fn neg(self) -> Self::Output {
        let Self(a) = self;
        let b = unsafe { simd_neg(a) };
        Self(b)
    }
}

impl<const N: usize, T: Num + Copy> Vector<N, T> {
    /// Shuffle elements using a compile-time mask
    #[inline(always)]
    pub fn shuffle<P, const M: usize>(self) -> Vector<M, T>
    where
        P: Pattern<Indices = [u32; M]>,
    {
        let Self(input) = self;
        const fn validate_mask<const N: usize, const M: usize>(mask: [u32; M]) {
            let mut i = 0;
            while i < M {
                assert!(mask[i] < N as u32, "Shuffle index out of bounds");
                i += 1;
            }
        }
        const { validate_mask::<N, M>(P::MASK) };
        // Safe because we validated bounds at compile time
        let output = unsafe {
            simd_shuffle::<_, _, _>(
                input,
                input,
                const { Simd::<M, u32>::from_array(<P as Pattern>::MASK) },
            )
        };
        Vector(output)
    }

    pub fn same_shuffle<P>(self) -> Vector<N, T>
    where
        P: Pattern<Indices = [u32; N]>,
    {
        self.shuffle::<P, N>()
    }
}

impl<const N: usize, T: Num + Copy + WrappingAdd> Vector<N, T> {
    pub fn reduce(self) -> T {
        self.0
            .iter()
            .copied()
            .fold(T::zero(), |acc, x| acc.wrapping_add(&x))
    }
}

pub mod swizzle {
    use crate::math::vector::Pattern;
    base_macro::swizzle!();
}

pub mod shuffle {
    use crate::Simd;

    pub trait Pattern {
        type Indices;
        const MASK: Self::Indices;
    }

    pub struct Reverse<const N: usize>;
    pub struct Rotate<const N: usize, const K: isize>;
    pub struct SwapPairs<const N: usize>;
    pub struct Broadcast<const N: usize, const IDX: usize>;
    pub struct Interleave<const N: usize>;
    pub struct Butterfly<const N: usize>;
    pub struct Perfect<const N: usize>;
    pub struct BitReverse<const N: usize>;
    pub struct CrossLane<const N: usize, const STRIDE: usize>;
    pub struct Transpose<const DIM: usize>;
    pub struct Zigzag<const N: usize>;
    pub struct Snake<const N: usize, const WIDTH: usize>;
    pub struct Radix2<const N: usize>;
    pub struct BlockShuffle<const N: usize, const BLOCK: usize>;
    pub struct Morton<const N: usize, const DIM: usize>;

    impl<const N: usize> Pattern for Reverse<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = (N - 1 - i) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const K: isize> Pattern for Rotate<N, K> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let k = ((K % N as isize) + N as isize) % N as isize;
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = ((i as isize + k) % N as isize) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for SwapPairs<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = if i % 2 == 0 { i + 1 } else { i - 1 } as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const IDX: usize> Pattern for Broadcast<N, IDX> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = IDX as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for Interleave<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = if i % 2 == 0 { i / 2 } else { N / 2 + i / 2 } as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for Butterfly<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                mask[i] = if i % 2 == 0 { i / 2 } else { N - 1 - i / 2 } as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for Perfect<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let half = N / 2;
            let mut i = 0;
            while i < half {
                // Even indices get first half
                mask[i * 2] = i as u32;
                // Odd indices get second half
                mask[i * 2 + 1] = (i + half) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for BitReverse<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let bits = const_log2(N) as u32;
            let mut i = 0;
            while i < N {
                let mut rev = 0;
                let mut j = 0;
                while j < bits {
                    rev = (rev << 1) | ((i >> j) & 1);
                    j += 1;
                }
                mask[i] = rev as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const STRIDE: usize> Pattern for CrossLane<N, STRIDE> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                let row = i / STRIDE;
                let col = i % STRIDE;
                mask[i] = (col * (N / STRIDE) + row) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const DIM: usize> Pattern for Transpose<DIM>
    where
        [(); { DIM * DIM }]: Sized,
    {
        type Indices = [u32; { DIM * DIM }];
        const MASK: Self::Indices = {
            let mut mask = [0; { DIM * DIM }];
            let mut i = 0;
            while i < DIM * DIM {
                let row = i / DIM;
                let col = i % DIM;
                mask[i] = (col * DIM + row) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for Zigzag<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let dim = const_sqrt(N);
            let mut x = 0;
            let mut y = 0;
            let mut i = 0;

            while i < N {
                // Write the current position to our output array
                let pos = y * dim + x;
                mask[pos] = i as u32;

                if (x + y) % 2 == 0 {
                    // Moving up and right
                    if x == dim - 1 {
                        y += 1; // Move down
                    } else if y == 0 {
                        x += 1; // Move right
                    } else {
                        x += 1; // Move diagonally
                        y -= 1;
                    }
                } else {
                    // Moving down and left
                    if y == dim - 1 {
                        x += 1; // Move right
                    } else if x == 0 {
                        y += 1; // Move down
                    } else {
                        x -= 1; // Move diagonally
                        y += 1;
                    }
                }
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const WIDTH: usize> Pattern for Snake<N, WIDTH> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                let row = i / WIDTH;
                let col = if row % 2 == 0 {
                    i % WIDTH
                } else {
                    WIDTH - 1 - (i % WIDTH)
                };
                mask[i] = (row * WIDTH + col) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize> Pattern for Radix2<N> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let bits = const_log2(N) as u32;
            let mut i = 0;
            while i < N {
                let mut val = i;
                let mut rev = 0;
                let mut j = 0;
                while j < bits {
                    rev = (rev << 1) | (val & 1);
                    val >>= 1;
                    j += 1;
                }
                mask[i] = ((rev * 2) % (N + 1)) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const BLOCK: usize> Pattern for BlockShuffle<N, BLOCK> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let mut i = 0;
            while i < N {
                let block = i / BLOCK;
                let pos = i % BLOCK;
                let row = pos / const_sqrt(BLOCK) as usize;
                let col = pos % const_sqrt(BLOCK) as usize;
                mask[i] = (block * BLOCK + col * const_sqrt(BLOCK) as usize + row) as u32;
                i += 1;
            }
            mask
        };
    }

    impl<const N: usize, const DIM: usize> Pattern for Morton<N, DIM> {
        type Indices = [u32; N];
        const MASK: Self::Indices = {
            let mut mask = [0; N];
            let bits = const_log2(N) / DIM; // bits per dimension
            let mut i = 0;
            while i < N {
                let mut morton = 0;
                let mut j = 0;
                while j < bits {
                    let mut d = 0;
                    while d < DIM {
                        let bit = (i >> (j * DIM + d)) & 1;
                        morton |= bit << (j + bits * d);
                        d += 1;
                    }
                    j += 1;
                }
                mask[i] = morton as u32;
                i += 1;
            }
            mask
        };
    }

    const fn const_sqrt(n: usize) -> usize {
        if n < 2 {
            return n;
        }
        let mut x = n;
        let mut y = (x + 1) / 2;
        while y < x {
            x = y;
            y = (x + n / x) / 2;
        }
        x
    }

    const fn const_log2(n: usize) -> usize {
        let mut val = n;
        let mut log = 0;
        while val > 1 {
            val >>= 1;
            log += 1;
        }
        log
    }
}
