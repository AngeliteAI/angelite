use num_traits::{AsPrimitive, Num};
use std::marker::PhantomData;
use std::ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Sub, SubAssign};
use std::time::SystemTime;

// Base trait for all time units
pub trait TimeUnit: Copy + Sized {
    fn from_nanos(nanos: u128) -> Self;
    fn from_inner(inner: u128) -> Self;
    fn into_nanos(self) -> u128;
}

// Individual unit structs
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Nanos(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Micros(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Millis(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Seconds(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Minutes(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Hours(u128);
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct Days(u128);
// Constants for conversion
pub const NANOS_PER_MICRO: u128 = 1_000;
pub const NANOS_PER_MILLI: u128 = 1_000_000;
pub const NANOS_PER_SECOND: u128 = 1_000_000_000;
pub const SECONDS_PER_MINUTE: u128 = 60;
pub const SECONDS_PER_HOUR: u128 = 3_600;
pub const SECONDS_PER_DAY: u128 = 86_400;

// Implementation for each unit
macro_rules! impl_time_unit {
    ($type:ty, $multiplier:expr) => {
        impl $type {
            pub fn into_inner(self) -> u128 {
                self.0
            }
        }
        impl TimeUnit for $type {
            fn from_nanos(nanos: u128) -> Self {
                Self(nanos / $multiplier)
            }

            fn from_inner(inner: u128) -> Self {
                Self(inner)
            }

            fn into_nanos(self) -> u128 {
                self.0 * $multiplier
            }
        }
    };
}

impl_time_unit!(Nanos, 1);
impl_time_unit!(Micros, NANOS_PER_MICRO);
impl_time_unit!(Millis, NANOS_PER_MILLI);
impl_time_unit!(Seconds, NANOS_PER_SECOND);
impl_time_unit!(Minutes, NANOS_PER_SECOND * SECONDS_PER_MINUTE);
impl_time_unit!(Hours, NANOS_PER_SECOND * SECONDS_PER_HOUR);
impl_time_unit!(Days, NANOS_PER_SECOND * SECONDS_PER_DAY);

impl<T: TimeUnit, U: TimeUnit> PartialEq<Duration<U>> for Duration<T> {
    fn eq(&self, other: &Duration<U>) -> bool {
        self.0.into_nanos() == other.0.into_nanos()
    }
}

impl<T: TimeUnit, U: TimeUnit> PartialOrd<Duration<U>> for Duration<T> {
    fn partial_cmp(&self, other: &Duration<U>) -> Option<std::cmp::Ordering> {
        let self_nanos = self.0.into_nanos();
        let other_nanos = other.0.into_nanos();
        self_nanos.partial_cmp(&other_nanos)
    }
}

// Implement Eq and Ord for same-unit comparisons
impl<T: TimeUnit> Eq for Duration<T> {}

impl<T: TimeUnit> Ord for Duration<T> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.0.into_nanos().cmp(&other.0.into_nanos())
    }
}

// Conversion trait
pub trait Convert<T: TimeUnit> {
    fn convert(self) -> T;
}

// Implement conversion between all units
impl<From: TimeUnit, To: TimeUnit> Convert<To> for From {
    fn convert(self) -> To {
        To::from_nanos(self.into_nanos())
    }
}

// Optional wrapper type for fluent API
#[derive(Clone, Copy, Debug)]
pub struct Duration<T: TimeUnit>(T);

impl<T: TimeUnit> Duration<T> {
    pub fn new(value: T) -> Self {
        Self(value)
    }

    pub fn into<U: TimeUnit>(self) -> Duration<U> {
        Duration(self.0.convert())
    }

    pub fn from(inner: u128) -> Self {
        Self(T::from_inner(inner))
    }

    pub fn get(self) -> T {
        self.0
    }
}

impl Duration<Nanos> {
    pub const INSTANT: Duration<Nanos> = Duration::<Nanos>(Nanos(0));
}

#[derive(PartialEq, Eq, PartialOrd, Ord, Clone, Copy)]
pub struct Instant(u128);

impl Instant {
    pub const fn epoch() -> Self {
        Self(0)
    }
    pub fn now() -> Self {
        match SystemTime::now().duration_since(SystemTime::UNIX_EPOCH) {
            Ok(duration) => Self(duration.as_nanos()),
            Err(_) => panic!("System time is before UNIX epoch, not good"),
        }
    }
    pub fn as_u128(&self) -> u128 {
        self.0
    }

    pub(crate) fn elapsed(&self) -> Duration<Nanos> {
        Self::now() - *self
    }
}

// Duration arithmetic
impl<T: TimeUnit> Add for Duration<T> {
    type Output = Self;
    fn add(self, other: Self) -> Self {
        Duration(T::from_nanos(self.0.into_nanos() + other.0.into_nanos()))
    }
}
impl<T: TimeUnit> Sub for Duration<T> {
    type Output = Self;
    fn sub(self, other: Self) -> Self {
        Duration(T::from_nanos(self.0.into_nanos() - other.0.into_nanos()))
    }
}

impl<T: TimeUnit, U> Mul<U> for Duration<T>
where
    U: Num + Copy + AsPrimitive<f64>,
{
    type Output = Self;
    fn mul(self, scalar: U) -> Self {
        let nanos = self.0.into_nanos();
        let scalar_f64: f64 = scalar.as_();
        Duration(T::from_nanos((nanos as f64 * scalar_f64) as u128))
    }
}

impl<T: TimeUnit, U> Div<U> for Duration<T>
where
    U: Num + Copy + AsPrimitive<f64>,
{
    type Output = Self;
    fn div(self, scalar: U) -> Self {
        let nanos = self.0.into_nanos();
        let scalar_f64: f64 = scalar.as_();
        Duration(T::from_nanos((nanos as f64 / scalar_f64) as u128))
    }
}

impl<T: TimeUnit> AddAssign for Duration<T> {
    fn add_assign(&mut self, other: Self) {
        *self = Duration(T::from_nanos(self.0.into_nanos() + other.0.into_nanos()));
    }
}

impl<T: TimeUnit> SubAssign for Duration<T> {
    fn sub_assign(&mut self, other: Self) {
        *self = Duration(T::from_nanos(self.0.into_nanos() - other.0.into_nanos()));
    }
}

impl<T: TimeUnit, U> MulAssign<U> for Duration<T>
where
    U: Num + Copy + AsPrimitive<f64>,
{
    fn mul_assign(&mut self, scalar: U) {
        let nanos = self.0.into_nanos();
        let scalar_f64: f64 = scalar.as_();
        *self = Duration(T::from_nanos((nanos as f64 * scalar_f64) as u128));
    }
}

impl<T: TimeUnit, U> DivAssign<U> for Duration<T>
where
    U: Num + Copy + AsPrimitive<f64>,
{
    fn div_assign(&mut self, scalar: U) {
        let nanos = self.0.into_nanos();
        let scalar_f64: f64 = scalar.as_();
        *self = Duration(T::from_nanos((nanos as f64 / scalar_f64) as u128));
    }
}

// Instant arithmetic
impl Sub for Instant {
    type Output = Duration<Nanos>;
    fn sub(self, other: Self) -> Duration<Nanos> {
        Duration(Nanos(self.0 - other.0))
    }
}

impl<T: TimeUnit> Add<Duration<T>> for Instant {
    type Output = Self;
    fn add(self, duration: Duration<T>) -> Self {
        Instant(self.0 + duration.0.into_nanos())
    }
}

impl<T: TimeUnit> Sub<Duration<T>> for Instant {
    type Output = Self;
    fn sub(self, duration: Duration<T>) -> Self {
        Instant(self.0 - duration.0.into_nanos())
    }
}

impl Mul<Instant> for Instant {
    type Output = Duration<Nanos>;
    fn mul(self, other: Instant) -> Duration<Nanos> {
        Duration(Nanos(self.0 * other.0))
    }
}

impl Div<Instant> for Instant {
    type Output = Duration<Nanos>;
    fn div(self, other: Instant) -> Duration<Nanos> {
        Duration(Nanos(self.0 / other.0))
    }
}

impl Add<Instant> for Instant {
    type Output = Instant;
    fn add(self, other: Instant) -> Self::Output {
        Instant(self.0 + other.0)
    }
}

impl SubAssign<Instant> for Instant {
    fn sub_assign(&mut self, other: Instant) {
        self.0 -= other.0;
    }
}

impl AddAssign<Instant> for Instant {
    fn add_assign(&mut self, other: Instant) {
        self.0 += other.0;
    }
}

impl MulAssign<Instant> for Instant {
    fn mul_assign(&mut self, other: Instant) {
        self.0 *= other.0;
    }
}

impl DivAssign<Instant> for Instant {
    fn div_assign(&mut self, other: Instant) {
        self.0 /= other.0;
    }
}
