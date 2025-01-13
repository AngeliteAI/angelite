use std::{intrinsics::type_id, ops::Bound};

pub trait Rng = Iterator<Item = u128>;

use pcg::Pcg;
pub use standard::Standard;
mod standard {
    use super::{Distribution, Rng};

    pub trait StandardSample: Copy {
        fn sample(random: u128) -> Self;
    }

    impl StandardSample for u128 {
        fn sample(random: u128) -> Self {
            random
        }
    }

    impl StandardSample for f64 {
        fn sample(bits: u128) -> Self {
            let high = (bits >> 64) as u64;
            let low = bits as u64;
            let mixed = high ^ low;

            // Generate float in [0, 1) with full 53 bits of precision
            // Use 53 most significant bits after mixing
            ((mixed >> 11) as f64) * 2f64.powi(-53)
        }
    }

    impl StandardSample for f32 {
        fn sample(bits: u128) -> Self {
            let high = (bits >> 64) as u32;
            let low = bits as u32;
            let mixed = high ^ low;

            ((mixed >> 8) as f32) * 2f32.powi(-23)
        }
    }

    impl StandardSample for bool {
        fn sample(bits: u128) -> Self {
            (bits & 1) == 1
        }
    }

    impl StandardSample for u8 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFF) as u8
        }
    }

    impl StandardSample for u16 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFF) as u16
        }
    }

    impl StandardSample for u32 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFFFFFF) as u32
        }
    }

    impl StandardSample for u64 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFFFFFFFFFFFFFF) as u64
        }
    }
    impl StandardSample for i8 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFF) as i8 as i128 as i8
        }
    }

    impl StandardSample for i16 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFF) as i16 as i128 as i16
        }
    }

    impl StandardSample for i32 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFFFFFF) as i32 as i128 as i32
        }
    }

    impl StandardSample for i64 {
        fn sample(bits: u128) -> Self {
            (bits & 0xFFFFFFFFFFFFFFFF) as i64 as i128 as i64
        }
    }

    impl StandardSample for i128 {
        fn sample(bits: u128) -> Self {
            bits as i128
        }
    }

    #[derive(Clone, Copy)]
    pub struct Standard;

    impl<T: StandardSample> Distribution<T> for Standard {
        #[inline(always)]
        fn sample(&self, rng: &mut impl Rng) -> T {
            T::sample(rng.next().unwrap())
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq, Hash)]
pub struct Id(u128);

impl Id {
    pub const fn of<T: 'static>() -> Self {
        Id(unsafe { type_id::<T>() })
    }
}

pub use range::Range;
mod range {
    use core::fmt;
    use num_traits::{
        Bounded, Float, Num, NumCast, PrimInt, WrappingAdd, clamp_max, clamp_min, real::Real,
    };
    use std::{
        any::TypeId,
        marker::PhantomData,
        ops::{Bound, Neg, RangeBounds},
    };

    use crate::rng::Id;

    use super::{Distribution, Rng, Standard};
    #[derive(Clone, Copy)]
    pub struct Range<T, R: RangeBounds<T>>(R, PhantomData<T>);
    impl<
        T: fmt::Debug
            + 'static
            + Num
            + Copy
            + NumCast
            + PartialOrd
            + Neg<Output = T>
            + Bounded
            + Copy
            + NumCast,
        U: RangeBounds<T>,
    > Distribution<T> for Range<T, U>
    where
        Standard: Distribution<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            const U8: Id = Id::of::<u8>();
            const I8: Id = Id::of::<i8>();
            const U16: Id = Id::of::<u16>();
            const I16: Id = Id::of::<i16>();
            const U32: Id = Id::of::<u32>();
            const I32: Id = Id::of::<i32>();
            const U64: Id = Id::of::<u64>();
            const I64: Id = Id::of::<i64>();
            const U128: Id = Id::of::<u128>();
            const I128: Id = Id::of::<i128>();
            const F32: Id = Id::of::<f32>();
            const F64: Id = Id::of::<f64>();

            let Self(range, _) = self;
            let this = Id::of::<T>();
            match this {
                // Unsigned integers
                U8 | U16 | U32 | U64 | U128 => {
                    let low = match range.start_bound() {
                        Bound::Included(&x) => x,
                        Bound::Excluded(&x) => x + T::one(),
                        Bound::Unbounded => T::min_value() + T::one(),
                    };
                    let high = match range.end_bound() {
                        Bound::Included(&x) => x + T::one(),
                        Bound::Excluded(&x) => x,
                        Bound::Unbounded => T::max_value(),
                    };
                    let range = high - low;
                    low + (rng.sample(&Standard) % range)
                }

                // Signed integers
                I8 | I16 | I32 | I64 | I128 => {
                    let high = match range.end_bound() {
                        Bound::Included(&x) => x + T::one(),
                        Bound::Excluded(&x) => x,
                        Bound::Unbounded => T::max_value(),
                    };

                    let mut low = match range.start_bound() {
                        Bound::Included(&x) => x,
                        Bound::Excluded(&x) => x + T::one(),
                        Bound::Unbounded => T::min_value() + T::one(),
                    };
                    if low <= T::min_value() + T::one() {
                        low = T::min_value() + high + T::one();
                    }

                    if low >= high {
                        return low;
                    }

                    let mut raw = rng.sample(&Standard);
                    // Ensure raw is not below minimum allowed value
                    if raw <= T::min_value() + T::one() {
                        raw = T::min_value() + T::one();
                    }

                    // If raw is already in range, use it
                    if raw >= low && raw < high {
                        return raw;
                    }

                    dbg!(raw, low, high);
                    let mut add = (raw % (high - low));

                    if add < T::one() {
                        add = -add;
                    }

                    // Otherwise map it into range
                    low + add
                }

                // Floating point
                F32 | F64 => {
                    let mut low = match range.start_bound() {
                        Bound::Included(&x) | Bound::Excluded(&x) => x,
                        Bound::Unbounded => -T::max_value(),
                    };
                    let mut high = match range.end_bound() {
                        Bound::Included(&x) | Bound::Excluded(&x) => x,
                        Bound::Unbounded => T::max_value(),
                    };
                    let bound = T::from(1e+107 as u128).unwrap();
                    if low < -bound {
                        low = -bound;
                    }
                    if high > bound {
                        high = bound;
                    }
                    let range = high - low;
                    low + rng.sample(&Standard) * range
                }

                _ => unreachable!("Unsupported numeric type"),
            }
        }
    }

    impl<R: RangeBounds<T>, T> Range<T, R> {
        pub fn new(val: R) -> Self {
            Self(val, PhantomData)
        }
    }
}

pub use normal::Normal;
mod normal {
    use super::Random;
    use std::f64::consts::{PI, TAU};

    use num_traits::Float;

    use crate::rng::{Distribution, Rng, Standard};

    // Normal (Gaussian) Distribution using Box-Muller transform
    #[derive(Clone, Copy)]
    pub struct Normal {
        mean: f64,
        std_dev: f64,
    }

    impl Normal {
        pub fn new(mean: f64, std_dev: f64) -> Self {
            assert!(std_dev > 0.0, "Standard deviation must be positive");
            Self { mean, std_dev }
        }
    }

    impl<T: Float> Distribution<T> for Normal
    where
        Standard: Distribution<T>,
        f64: From<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            let u1 = rng.sample(&Standard);
            let u2 = rng.sample(&Standard);

            let r = (T::from(-2.0).unwrap() * u1.ln()).sqrt();
            let theta = T::from(TAU).unwrap() * u2;

            let (_, cos) = theta.sin_cos();

            T::from(self.mean + self.std_dev).unwrap() * r * cos
        }
    }
}

pub use exponential::Exponential;
mod exponential {
    use super::Random;
    use crate::rng::{Distribution, Rng, Standard};
    use num_traits::Float;

    #[derive(Clone, Copy)]
    pub struct Exponential {
        lambda: f64,
    }

    impl Exponential {
        pub fn new(lambda: f64) -> Self {
            assert!(lambda > 0.0, "Rate parameter must be positive");
            Self { lambda }
        }
    }

    impl<T: Float> Distribution<T> for Exponential
    where
        Standard: Distribution<T>,
        f64: From<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            let u: T = rng.sample(&Standard);
            -u.ln() / T::from(self.lambda).unwrap()
        }
    }
}

pub use gamma::Gamma;
mod gamma {
    use super::Random;
    use crate::rng::{Distribution, Rng, Standard};
    use num_traits::Float;

    #[derive(Clone, Copy)]
    pub struct Gamma {
        alpha: f64,
        beta: f64,
    }

    impl Gamma {
        pub fn new(alpha: f64, beta: f64) -> Self {
            assert!(alpha > 0.0 && beta > 0.0, "Parameters must be positive");
            Self { alpha, beta }
        }
    }

    impl<T: Float> Distribution<T> for Gamma
    where
        Standard: Distribution<T>,
        f64: From<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            let alpha = if self.alpha < 1.0 {
                self.alpha + 1.0
            } else {
                self.alpha
            };

            let d = T::from(alpha - 1.0 / 3.0).unwrap();
            let c = T::from(1.0 / ((9.0 * alpha - 3.0).sqrt())).unwrap();

            let mut v;
            let mut x;
            loop {
                let xi: T = rng.sample(&Standard);
                v = T::one() + c * xi;
                v = v * v * v;

                let u: T = rng.sample(&Standard);

                if u < T::one() - T::from(0.0331).unwrap() * xi * xi * xi * xi {
                    x = d * v;
                    break;
                }

                if u.ln() < T::from(0.5).unwrap() * xi * xi + d * (T::one() - v + v.ln()) {
                    x = d * v;
                    break;
                }
            }

            // If original alpha was < 1, apply transformation
            if self.alpha < 1.0 {
                let u: T = rng.sample(&Standard);
                x = x * u.powf(T::from(1.0 / self.alpha).unwrap());
            }

            x / T::from(self.beta).unwrap()
        }
    }
}

pub use poisson::Poisson;
mod poisson {
    use super::Random;
    use crate::rng::{Distribution, Rng, Standard};
    use num_traits::{Float, PrimInt};

    #[derive(Clone, Copy)]
    pub struct Poisson {
        lambda: f64,
    }

    impl Poisson {
        pub fn new(lambda: f64) -> Self {
            assert!(lambda > 0.0, "Rate parameter must be positive");
            Self { lambda }
        }
    }

    impl<T: PrimInt> Distribution<T> for Poisson
    where
        Standard: Distribution<f64>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            let l = (-self.lambda).exp();
            let mut k = 0u64;
            let mut p = 1.0;

            loop {
                k += 1;
                p *= rng.sample::<f64>(&Standard);
                if p <= l {
                    break T::from(k - 1).unwrap();
                }
            }
        }
    }
}

pub use beta::Beta;

use crate::math::vector::Vector;
mod beta {
    use super::Random;
    use crate::rng::{Distribution, Gamma, Rng, Standard};
    use num_traits::Float;

    #[derive(Clone, Copy)]
    pub struct Beta {
        alpha: f64,
        beta: f64,
    }

    impl Beta {
        pub fn new(alpha: f64, beta: f64) -> Self {
            assert!(alpha > 0.0 && beta > 0.0, "Parameters must be positive");
            Self { alpha, beta }
        }
    }

    impl<T: Float> Distribution<T> for Beta
    where
        Standard: Distribution<T>,
        f64: From<T>,
        Gamma: Distribution<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            let x = rng.sample(&Gamma::new(self.alpha, 1.0));
            let y = rng.sample(&Gamma::new(self.beta, 1.0));
            x / (x + y)
        }
    }
}

pub mod transform {
    use super::Random;
    use crate::rng::{Distribution, Rng, Standard};
    use num_traits::Float;
    use std::marker::PhantomData;

    // Allow both functions and structs to be transforms
    pub trait Transform<T, U = T> {
        fn transform(&self, value: T) -> U;
    }

    // Implement Transform for function types
    impl<T, U, F: Fn(T) -> U> Transform<T, U> for F {
        fn transform(&self, value: T) -> U {
            self(value)
        }
    }

    // Composition types
    pub enum Composed<T, D1, D2> {
        Add(D1, D2, PhantomData<T>),
        Mul(D1, D2, PhantomData<T>),
        Mix(D1, D2, f64, PhantomData<T>),
        Map(D1, Box<dyn Transform<T> + Send + Sync>),
    }

    // Extension trait for ergonomic composition
    pub trait DistributionTransform<T>: Distribution<T> {
        fn add<D: Distribution<T>>(self, other: D) -> Composed<T, Self, D>
        where
            Self: Sized,
        {
            Composed::Add(self, other, PhantomData)
        }

        fn multiply<D: Distribution<T>>(self, other: D) -> Composed<T, Self, D>
        where
            Self: Sized,
        {
            Composed::Mul(self, other, PhantomData)
        }

        fn mix<D: Distribution<T>>(self, other: D, weight: f64) -> Composed<T, Self, D>
        where
            Self: Sized,
        {
            Composed::Mix(self, other, weight.clamp(0.0, 1.0), PhantomData)
        }

        // Allow both function types and Transform types
        fn map<F>(self, f: F) -> Composed<T, Self, Self>
        where
            Self: Sized,
            F: Transform<T> + Send + Sync + 'static,
        {
            Composed::Map(self, Box::new(f))
        }
    }

    impl<T, D1, D2> Distribution<T> for Composed<T, D1, D2>
    where
        T: Float + Send + Sync,
        D1: Distribution<T>,
        D2: Distribution<T>,
        Standard: Distribution<T>,
    {
        fn sample(&self, rng: &mut impl Rng) -> T {
            match self {
                Self::Add(d1, d2, _) => d1.sample(rng) + d2.sample(rng),
                Self::Mul(d1, d2, _) => d1.sample(rng) * d2.sample(rng),
                Self::Mix(d1, d2, w, _) => {
                    if rng.sample(&Standard) < T::from(*w).unwrap() {
                        d1.sample(rng)
                    } else {
                        d2.sample(rng)
                    }
                }
                Self::Map(d1, t) => t.transform(d1.sample(rng)),
            }
        }
    }

    // Implement for all distributions
    impl<T, D: Distribution<T>> DistributionTransform<T> for D {}
}

pub trait Distribution<T> {
    fn sample(&self, rng: &mut impl Rng) -> T;
}

pub trait Random: Rng {
    fn sample<T>(&mut self, dist: &impl Distribution<T>) -> T
    where
        Self: Sized,
    {
        dist.sample(self)
    }
}

impl<R: Rng> Random for R {}

mod pcg {
    use crate::{
        Array,
        math::vector::{Vector, shuffle::Perfect},
    };

    const MULTIPLIER: u128 = 0x2360ED051FC65DA44385DF649FCCF645;
    const PHI: u128 = 0x9E3779B97F4A7C15F39CC0605CEDC834;
    const WEYL: u128 = 0xB4E902A1B37E9E9D7A35C7B5D8B9C071;

    const ROT: u32 = 123;

    pub struct Gen<const LANES: usize> {
        state: Vector<LANES, u128>,
        increment: Vector<LANES, u128>,
        weyl: Vector<LANES, u128>, // Add Weyl sequence for better mixing
    }

    const fn pcg_init_state(index: usize) -> u128 {
        let base = match index % 4 {
            0 => 0xcafef00dd15ea5e5,
            1 => 0xdeadbeefcafebeef,
            2 => 0xf00dbeefdeadcafe,
            3 => 0xbeeff00dcafed15e,
            _ => unreachable!(),
        };
        base ^ (PHI.wrapping_mul(index as u128 + 1)) // Better initialization mixing
    }

    const fn pcg_init_increment(index: usize) -> u128 {
        let base = match index % 4 {
            0 => 0xa02891feed15ea5e,
            1 => 0xc0ffeed15ebabe5c,
            2 => 0xfeedbabedeadc0de,
            3 => 0xd15ebabefeedd06f,
            _ => unreachable!(),
        };
        (base | 1) ^ (WEYL.wrapping_mul(index as u128 + 1)) // Ensure odd & mix
    }

    impl<const LANES: usize> Gen<LANES> {
        const STATE: Vector<LANES, u128> = const {
            let mut state = [0u128; LANES];
            let mut i = 0;
            while i < LANES {
                state[i] = pcg_init_state(i);
                i += 1;
            }
            Vector(Array(state))
        };

        const INCREMENT: Vector<LANES, u128> = const {
            let mut state = [0u128; LANES];
            let mut i = 0;
            while i < LANES {
                state[i] = pcg_init_increment(i);
                i += 1;
            }
            Vector(Array(state))
        };

        pub fn new(seed: Vector<LANES, u128>) -> Self {
            let mut this = Self {
                state: Self::STATE ^ seed, // Mix in the seed
                increment: Self::INCREMENT,
                weyl: Vector::splat(WEYL),
            };

            // Enhanced initialization
            this.avalanche();
            this
        }

        #[inline(always)]
        fn avalanche(&mut self) {
            const ROUNDS: u128 = 3;
            for _ in 0..self.state.reduce() % ROUNDS {
                self.shuffle();
                let raw = self.next_raw();
                self.state ^= raw;
                self.increment = (self.increment << 1) | 1; // Keep increment odd
            }
        }

        #[inline(always)]
        pub fn next_u128(&mut self) -> Vector<LANES, u128> {
            self.avalanche();

            let result = self.next_raw();

            // Add extra mixing steps
            self.weyl += Vector::splat(WEYL);
            self.state ^= self.weyl;

            result
        }

        #[inline(always)]
        fn next_raw(&mut self) -> Vector<LANES, u128> {
            let old_state = self.state;
            self.state = old_state * MULTIPLIER + self.increment;
            // Enhanced mixing function for 128-bit
            let xored = (old_state >> 64) ^ old_state;
            let word = (xored >> 63) ^ (xored >> 31) ^ (xored >> 15);
            let rot = (old_state >> 122) & 127; // Using higher bits for rotation

            self.rotate_right(word, rot)
        }

        #[inline(always)]
        fn rotate_right(
            &self,
            value: Vector<LANES, u128>,
            rot: Vector<LANES, u128>,
        ) -> Vector<LANES, u128> {
            (value >> rot) | (value << (Vector::<LANES, u128>::splat(128) - rot))
        }

        pub fn shuffle(&mut self) {
            self.state = self.state.same_shuffle::<Perfect<LANES>>();
            self.increment = self.increment.same_shuffle::<Perfect<LANES>>();
        }
    }

    pub struct Pcg<const LANES: usize> {
        buf: Option<Vector<LANES, u128>>,
        index: usize,
        state: Gen<LANES>,
    }

    impl<const LANES: usize> Pcg<LANES> {
        pub fn new(seed: Vector<LANES, u128>) -> Self {
            Self {
                buf: None,
                index: 0,
                state: Gen::new(seed),
            }
        }
    }

    impl<const LANES: usize> Iterator for Pcg<LANES> {
        type Item = u128;

        fn next(&mut self) -> Option<Self::Item> {
            loop {
                if let Some(buf) = &self.buf {
                    if self.index < LANES {
                        let value = buf[self.index];
                        self.index += 1;
                        return Some(value);
                    } else {
                        self.buf = None;
                        continue;
                    }
                }
                self.buf = Some(self.state.next_u128());
                self.index = 0;
            }
        }
    }
}
#[test]
fn test_pcg() {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut pcg = Pcg::<32>::new(Vector::splat(nanos));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
    dbg!(pcg.sample::<f64>(&Standard));
}
fn chi_square_test(observed: &[u64]) -> f64 {
    let total: u64 = observed.iter().sum();
    let expected = (total as f64) / (observed.len() as f64);

    observed
        .iter()
        .map(|&count| {
            let diff = count as f64 - expected;
            (diff * diff) / expected
        })
        .sum()
}
#[test]
fn test_statistical_properties() {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut rng = Pcg::<32>::new(Vector::splat(nanos));
    const BUCKETS: usize = 1000;
    const SAMPLES: usize = 10_000_000;

    // Chi-square test with floating point samples
    let mut buckets = [0u64; BUCKETS];
    for _ in 0..SAMPLES {
        let v: f64 = rng.sample(&Standard);
        let bucket = (v * BUCKETS as f64) as usize;
        buckets[bucket.min(BUCKETS - 1)] += 1;
    }

    // Test uniformity
    let chi_square = chi_square_test(&buckets);

    // Critical values for 999 degrees of freedom (1000 buckets - 1):
    // 99%: 1143.92
    // 95%: 1073.64
    // 90%: 1038.83
    println!("Chi-square statistic: {}", chi_square);
    assert!(
        chi_square < 1073.64,
        "Chi-square test failed: {}",
        chi_square
    );
}

#[test]
fn test_range_distribution() {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let mut rng = Pcg::<32>::new(Vector::splat(nanos));

    //int range
    let ranges_int = [
        (-1..1),              // Exclusive bounds
        (-10..10),            // Inclusive upper
        (0..i64::MAX),        // Only lower bound
        (i64::MIN..1),        // Only upper bound inclusive
        (i64::MIN..i64::MAX), // Unbounded
    ];
    // Test several range configurations
    let ranges_float = [
        (-1.0..1.0),          // Exclusive bounds
        (-10.0..10.0),        // Inclusive upper
        (0.0..f64::MAX),      // Only lower bound
        (f64::MIN..1.0),      // Only upper bound inclusive
        (f64::MIN..f64::MAX), // Unbounded
    ];

    const ITERATIONS: usize = 100_000;

    for (range_a, range_b) in ranges_int.into_iter().zip(ranges_float) {
        let dist_a = Range::new(range_a.clone());
        let dist_b = Range::new(range_b.clone());

        for _ in 0..ITERATIONS {
            let value: i64 = rng.sample(&dist_a.clone());

            // Check bounds
            match range_a.start_bound() {
                Bound::Included(&start) | Bound::Excluded(&start) => assert!(
                    value >= start,
                    "Value {} below start bound {}",
                    value,
                    start
                ),
                Bound::Unbounded => {}
            }

            match range_a.end_bound() {
                Bound::Included(&end) => {
                    assert!(value <= end, "Value {} above end bound {}", value, end)
                }
                Bound::Excluded(&end) => {
                    assert!(value < end, "Value {} not below end bound {}", value, end)
                }
                Bound::Unbounded => {}
            }

            let value: f64 = rng.sample(&dist_b.clone());

            // Check bounds
            match range_b.start_bound() {
                Bound::Included(&start) | Bound::Excluded(&start) => assert!(
                    value >= start,
                    "Value {} below start bound {}",
                    value,
                    start
                ),
                Bound::Unbounded => {}
            }

            match range_b.end_bound() {
                Bound::Included(&end) => {
                    assert!(value <= end, "Value {} above end bound {}", value, end)
                }
                Bound::Excluded(&end) => {
                    assert!(value < end, "Value {} not below end bound {}", value, end)
                }
                Bound::Unbounded => {}
            }
        }
    }
}

#[test]
fn simulate_network_conditions() {
    use std::f64::consts::PI;
    use transform::*;

    let mut rng = Pcg::<32>::new(Vector::splat(0));

    // Network condition parameters
    const BASE_LATENCY: f64 = 50.0; // Base latency in ms
    const JITTER_MEAN: f64 = 15.0; // Mean jitter in ms
    const PACKET_LOSS: f64 = 0.02; // 2% packet loss
    const CONGESTION_PERIOD: f64 = 5000.0; // Congestion cycle in ms

    // Base distributions
    let base_jitter = Normal::new(0.0, JITTER_MEAN);
    let congestion = Normal::new(0.0, 30.0);
    let packet_drop = Exponential::new(1.0 / PACKET_LOSS);

    // Periodic congestion function
    let congestion_wave = |t: f64| (t * 2.0 * PI / CONGESTION_PERIOD).sin() * 20.0 + 20.0;

    // Network simulator that combines multiple effects
    let network = base_jitter
        .map(|x: f64| x.abs()) // Make jitter positive
        .add(
            congestion
                .map(|x: f64| x.abs())
                .map(move |x| congestion_wave(x)),
        )
        .map(|x| x + BASE_LATENCY)
        .map(|x: f64| x.max(1.0)); // Ensure minimum latency

    // Simulate network conditions over time
    const SIMULATION_TIME: usize = 10_000;
    let mut latencies = Vec::with_capacity(SIMULATION_TIME);
    let mut dropped_packets = 0;
    let mut timestamps = Vec::with_capacity(SIMULATION_TIME);

    for t in 0..SIMULATION_TIME {
        // Check for packet drop
        if rng.sample::<f64>(&packet_drop) < PACKET_LOSS {
            dropped_packets += 1;
            continue;
        }

        let latency = rng.sample(&network);
        latencies.push(latency);
        timestamps.push(t);
    }

    // Analysis
    let total_packets = SIMULATION_TIME;
    let delivered_packets = latencies.len();

    let mean_latency = latencies.iter().sum::<f64>() / delivered_packets as f64;
    let variance = latencies
        .iter()
        .map(|&x| (x - mean_latency).powi(2))
        .sum::<f64>()
        / delivered_packets as f64;
    let std_dev = variance.sqrt();

    // Calculate percentiles for jitter analysis
    let mut sorted_latencies = latencies.clone();
    sorted_latencies.sort_by(|a, b| a.partial_cmp(b).unwrap());

    let p50 = sorted_latencies[delivered_packets * 50 / 100];
    let p95 = sorted_latencies[delivered_packets * 95 / 100];
    let p99 = sorted_latencies[delivered_packets * 99 / 100];

    // Print network condition report
    println!("\nNetwork Simulation Report");
    println!("=========================");
    println!("Total Packets: {}", total_packets);
    println!("Delivered Packets: {}", delivered_packets);
    println!("Dropped Packets: {}", dropped_packets);
    println!(
        "Packet Loss Rate: {:.2}%",
        (dropped_packets as f64 / total_packets as f64) * 100.0
    );
    println!("\nLatency Statistics (ms)");
    println!("----------------------");
    println!("Mean Latency: {:.2}", mean_latency);
    println!("Std Deviation: {:.2}", std_dev);
    println!("Median (P50): {:.2}", p50);
    println!("P95: {:.2}", p95);
    println!("P99: {:.2}", p99);

    // Generate ASCII plot of latency over time
    println!("\nLatency Over Time");
    println!("----------------");
    const PLOT_HEIGHT: usize = 20;
    const PLOT_WIDTH: usize = 80;

    let min_latency = *latencies
        .iter()
        .min_by(|a, b| a.partial_cmp(b).unwrap())
        .unwrap();
    let max_latency = *latencies
        .iter()
        .max_by(|a, b| a.partial_cmp(b).unwrap())
        .unwrap();
    let latency_range = max_latency - min_latency;

    let mut plot = vec![vec![' '; PLOT_WIDTH]; PLOT_HEIGHT];

    for (i, &latency) in latencies.iter().enumerate() {
        let x = (i * PLOT_WIDTH) / delivered_packets;
        let y = ((latency - min_latency) / latency_range * (PLOT_HEIGHT - 1) as f64) as usize;
        plot[PLOT_HEIGHT - 1 - y][x] = '•';
    }

    // Draw plot
    println!("{:.0}ms", max_latency);
    for row in plot {
        print!("|");
        for cell in row {
            print!("{}", cell);
        }
        println!("|");
    }
    println!("{:.0}ms", min_latency);
    println!("Time →");

    // Verify network conditions meet requirements
    assert!(mean_latency < BASE_LATENCY * 2.0, "Mean latency too high");
    assert!(p95 < BASE_LATENCY * 3.0, "P95 latency too high");
    assert!(
        (dropped_packets as f64 / total_packets as f64) < PACKET_LOSS * 1.5,
        "Packet loss rate too high"
    );
    panic!("");
}
