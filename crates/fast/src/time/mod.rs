use num_traits::{AsPrimitive, Num};
use std::iter;
use std::marker::PhantomData;
use std::ops::{Add, AddAssign, Div, DivAssign, Mul, MulAssign, Sub, SubAssign};
use std::time::SystemTime;

use crate::collections::skip::List;
use crate::sync::backoff::Backoff;

// Base trait for all time units
pub trait TimeUnit: Copy + Sized + std::fmt::Debug {
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

pub struct TimerWheel<T> {
    // Hierarchical wheels for different time scales
    wheels: [List<Timer<T>>; 4], // ms, sec, min, hour
    current_tick: Instant,
    backoff: Backoff,
}

struct Timer<T> {
    expires_at: Instant,
    data: T,
}

impl<T> TimerWheel<T> {
    const WHEEL_BITS: [u8; 4] = [8, 6, 6, 6]; // 256ms, 64sec, 64min, 64hour

    pub fn new() -> Self {
        Self {
            wheels: iter::repeat_with(|| List::<Timer<T>>::new())
                .take(4)
                .collect::<Vec<_>>()
                .try_into()
                .or(Err(()))
                .unwrap(),
            current_tick: Instant::now(),
            backoff: Backoff::with_step(Duration::from(1)),
        }
    }

    pub async fn add(&self, expires_in: Duration<Millis>, data: T) {
        let expires_at = Instant::now() + expires_in;
        let wheel_idx = self.calculate_wheel_index(expires_in);
        let slot_idx = self.calculate_slot_index(expires_at, wheel_idx);

        self.wheels[wheel_idx]
            .insert(Timer { expires_at, data })
            .await;
    }

    pub async fn tick(&self) -> Vec<T> {
        let mut expired = Vec::new();
        let now = Instant::now();

        // Process current level
        self.process_expired(now, &mut expired).await;

        // Cascade if necessary
        if self.should_cascade(0) {
            self.cascade(1).await;
        }

        expired
    }

    async fn cascade(&self, level: usize) {
        // Move timers down to lower levels as appropriate
        let mut to_move = Vec::new();

        // Collect timers that should move down
        while let Some(timer) = self.wheels[level].remove_first() {
            let new_level =
                self.calculate_wheel_index((timer.expires_at - Instant::now()).into::<Millis>());
            if new_level < level {
                to_move.push(timer);
            }
        }

        // Reinsert at appropriate levels
        for timer in to_move {
            let new_level =
                self.calculate_wheel_index((timer.expires_at - Instant::now()).into::<Millis>());
            self.wheels[new_level].insert(timer).await;
        }
    }
    fn calculate_wheel_index(&self, duration: Duration<Millis>) -> usize {
        let nanos = duration.get().into_nanos();
        let ms = nanos / NANOS_PER_MILLI;

        match ms {
            0..=255 => 0,         // First wheel (8 bits)
            256..=16383 => 1,     // Second wheel (6 bits)
            16384..=1048575 => 2, // Third wheel (6 bits)
            _ => 3,               // Fourth wheel (6 bits)
        }
    }

    fn calculate_slot_index(&self, expires_at: Instant, wheel: usize) -> u64 {
        let time_diff = expires_at.as_u128() - self.current_tick.as_u128();
        let shift = Self::WHEEL_BITS[..wheel].iter().sum::<u8>();
        let mask = (1 << Self::WHEEL_BITS[wheel]) - 1;

        ((time_diff >> shift) & (mask as u128)) as u64
    }

    async fn process_expired(&self, now: Instant, expired: &mut Vec<T>) {
        while let Some(timer) = self.wheels[0].remove_first() {
            if timer.expires_at > now {
                // Not expired yet, reinsert
                self.wheels[0].insert(timer).await;
                break;
            }
            expired.push(timer.data);
        }
    }

    fn should_cascade(&self, level: usize) -> bool {
        if level >= Self::WHEEL_BITS.len() {
            return false;
        }

        let mask = (1 << Self::WHEEL_BITS[level]) - 1;
        let ticks = (self.current_tick.as_u128() >> Self::WHEEL_BITS[..level].iter().sum::<u8>())
            & (mask as u128);

        ticks == 0
    }

    // Helper method to check if a timer is expired
    fn is_expired(&self, timer: &Timer<T>) -> bool {
        timer.expires_at <= self.current_tick
    }

    // Get the number of active timers
    pub fn len(&self) -> usize {
        self.wheels.iter().map(|wheel| wheel.len()).sum()
    }

    // Check if there are any active timers
    pub fn is_empty(&self) -> bool {
        self.len() == 0
    }

    // Clear all timers
    pub async fn clear(&self) {
        for wheel in &self.wheels {
            while wheel.remove_first().is_some() {}
        }
    }

    // Remove and return all expired timers
    pub async fn drain_expired(&self) -> Vec<T> {
        let mut expired = Vec::new();
        let now = Instant::now();

        for wheel in &self.wheels {
            while let Some(timer) = wheel.remove_first() {
                if timer.expires_at <= now {
                    expired.push(timer.data);
                } else {
                    // Reinsert non-expired timer
                    wheel.insert(timer).await;
                    break;
                }
            }
        }

        expired
    }

    // Update the current tick and handle cascading
    pub async fn advance(&mut self, duration: Duration<Millis>) {
        self.current_tick = self.current_tick + duration;

        // Check if we need to cascade at each level
        for level in 0..self.wheels.len() {
            if self.should_cascade(level) {
                self.cascade(level).await;
            }
        }
    }

    // Get the next expiration time
    pub async fn next_expiration(&self) -> Option<Instant> {
        for wheel in &self.wheels {
            if let Some(timer) = wheel
                .get(&Timer {
                    expires_at: Instant::epoch(),
                    data: unsafe { std::mem::zeroed() },
                })
                .await
            {
                return Some(timer.expires_at);
            }
        }
        None
    }

    // Remove a specific timer (if it exists)
    pub async fn remove(&self, expires_at: Instant) -> Option<T> {
        let wheel_idx =
            self.calculate_wheel_index((expires_at - self.current_tick).into::<Millis>());

        let dummy = Timer {
            expires_at,
            data: unsafe { std::mem::zeroed() },
        };

        self.wheels[wheel_idx].remove(&dummy).await.map(|t| t.data)
    }
}

// Implement PartialEq for Timer to enable removal
impl<T> PartialEq for Timer<T> {
    fn eq(&self, other: &Self) -> bool {
        self.expires_at == other.expires_at
    }
}

// Implement PartialOrd for Timer to enable proper ordering in the skip list
impl<T> PartialOrd for Timer<T> {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> {
        Some(self.expires_at.cmp(&other.expires_at))
    }
}

impl<T> Ord for Timer<T> {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering {
        self.expires_at.cmp(&other.expires_at)
    }
}

impl<T> Eq for Timer<T> {}

#[cfg(test)]
mod tests {
    use crate::rt::block_on;

    use super::*;
    use std::{thread, time::Duration as StdDuration};

    #[test]
    fn test_duration_conversions() {
        // Test basic conversions between units
        let nanos = Duration::new(Nanos(1_000_000_000));
        let millis = nanos.into::<Millis>();
        let seconds = nanos.into::<Seconds>();

        assert_eq!(millis.get().into_inner(), 1_000);
        assert_eq!(seconds.get().into_inner(), 1);

        // Test bidirectional conversions
        let original_millis = Duration::new(Millis(500));
        let as_nanos: Duration<Nanos> = original_millis.into();
        let back_to_millis: Duration<Millis> = as_nanos.into();

        assert_eq!(original_millis, back_to_millis);
    }

    #[test]
    fn test_duration_arithmetic() {
        // Test addition
        let d1 = Duration::new(Millis(100));
        let d2 = Duration::new(Millis(200));
        let sum = d1 + d2;
        assert_eq!(sum.get().into_inner(), 300);

        // Test multiplication with scalar
        let duration = Duration::new(Seconds(2));
        let doubled = duration * 2;
        assert_eq!(doubled.get().into_inner(), 4);

        // Test division
        let halved = doubled / 2;
        assert_eq!(halved.get().into_inner(), 2);
    }

    #[test]
    fn test_duration_comparison() {
        let shorter = Duration::new(Millis(100));
        let longer = Duration::new(Millis(200));

        assert!(shorter < longer);
        assert!(longer > shorter);
        assert!(shorter <= longer);
        assert!(longer >= shorter);
        assert!(shorter != longer);

        // Compare different units
        let seconds = Duration::new(Seconds(1));
        let millis = Duration::new(Millis(1000));
        assert_eq!(seconds, millis);
    }

    #[test]
    fn test_duration_from_std() {
        let std_duration = StdDuration::from_secs(1);
        let duration: Duration<Nanos> = Duration::from(std_duration.as_nanos());

        assert_eq!(duration.get().into_nanos(), 1_000_000_000);
    }

    #[test]
    fn test_instant_with_duration() {
        let now = Instant::now();
        let delay = Duration::new(Millis(100));
        let future = now + delay;

        assert!(future > now);
        assert_eq!(future - now, delay);
    }

    #[test]
    fn test_duration_zero() {
        let zero = Duration::<Millis>::from(0);
        assert_eq!(zero.get().into_inner(), 0);
        assert!(zero == Duration::<Millis>::from(0));
    }

    #[test]
    fn test_duration_max() {
        let max = Duration::<Millis>::from(u128::MAX);
        assert_eq!(max.get().into_inner(), u128::MAX);
    }

    #[test]
    fn test_duration_compound_arithmetic() {
        let mut duration = Duration::new(Seconds(1));
        duration *= 2;
        duration += Duration::new(Seconds(1));
        duration /= 2;

        assert_eq!(duration.get().into_inner(), 1);
    }

    #[test]
    fn test_duration_different_units_arithmetic() {
        let seconds = Duration::new(Seconds(1));
        let millis = Duration::new(Millis(500));

        // Convert to same unit for comparison
        let total: Duration<Millis> = (seconds + millis.into::<Seconds>()).into();
        assert_eq!(total.get().into_inner(), 1500);
    }

    #[test]
    fn test_duration_ordering() {
        let durations = vec![
            Duration::new(Millis(300)),
            Duration::new(Millis(100)),
            Duration::new(Millis(200)),
        ];

        let mut sorted = durations.clone();
        sorted.sort();

        assert_eq!(sorted[0].get().into_inner(), 100);
        assert_eq!(sorted[1].get().into_inner(), 200);
        assert_eq!(sorted[2].get().into_inner(), 300);
    }

    #[test]
    fn test_duration_display() {
        let duration = Duration::new(Seconds(1));
        assert_eq!(format!("{:?}", duration), "Duration(Seconds(1))");
    }

    #[test]
    #[should_panic]
    fn test_duration_overflow() {
        let large = Duration::new(Seconds(u128::MAX));
        let _ = large * 2;
    }

    #[test]
    fn test_duration_with_timer_wheel() {
        block_on(async {
            let wheel = TimerWheel::new();

            // Test with different duration units
            wheel.add(Duration::new(Millis(100)), "millis").await;
            wheel.add(Duration::new(Seconds(1)).into(), "seconds").await;

            thread::sleep(StdDuration::from_millis(1100));

            let expired = wheel.drain_expired().await;
            assert_eq!(expired.len(), 2);
        });
    }
}
