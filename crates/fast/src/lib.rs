#![allow(internal_features)]
#![feature(
    repr_simd,
    try_blocks,
    core_intrinsics,
    generic_const_exprs,
    trait_alias,
    impl_trait_in_assoc_type,
    const_type_id,
    async_fn_traits,
    unboxed_closures,
    thread_id_value,
    negative_impls
)]

use derive_more::derive::{Deref, DerefMut};
use num_traits::{Num, WrappingAdd};
use paste::paste;
use prelude::Vector;
use rt::{
    Act, Local, Task, block_on,
    worker::{Worker, next_local_key},
};
use std::{intrinsics::simd::*, ops::*};

#[repr(simd)]
#[derive(Deref, DerefMut, Clone, Copy, Debug, PartialEq, Eq)]
pub struct Array<const N: usize, T: Num>(pub [T; N]);

impl<const N: usize, T: Num + Copy> FromIterator<T> for Array<N, T> {
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

impl<const N: usize, T: Num + Copy> Array<N, T> {
    const fn from_array(data: [T; N]) -> Self {
        Self(data)
    }
}

pub mod prelude {
    pub use crate::Array;
    pub use crate::math::vector::Vector;
    pub use crate::math::vector::shuffle::Pattern;
    pub use crate::math::vector::swizzle::*;
    pub use crate::rng::{
        Beta, Distribution, Exponential, Gamma, Normal, Poisson, Range, Rng, Standard,
    };
}

pub mod collections;
pub mod math;
pub mod rng;
pub mod rt;
pub mod sync;
pub mod time;

pub use fast_macro::main;

pub fn run(main_fn: impl Future<Output = ()> + 'static) {
    block_on(async {
        dbg!("yo1");
        let start = rt::worker::start(Vector::splat(0), 10).await;
        dbg!("yo2");
        rt::worker::current_worker()
            .await
            .unwrap()
            .local
            .enqueue(Task::<Local> {
                key: next_local_key().await,
                act: Some(Act::Fut(Box::pin(main_fn) as _)),
            });
        block_on(start.wait());
        loop {
            dbg!("yo3");
            block_on(Worker::work());
        }
    })
}
