use std::sync::{Arc, atomic::AtomicUsize, atomic::Ordering::*};

use crate::time::{Duration, Instant, Millis};

use super::backoff::Backoff;

/// A synchronization primitive that enables multiple tasks to wait for each other.
///
/// The barrier ensures all tasks arrive before any are allowed to proceed.
/// It supports both single-use and reusable modes with optional timeout.
pub struct Barrier {
    /// Number of tasks that must arrive
    count: usize,
    /// Current generation to prevent ABA problems
    generation: Arc<AtomicUsize>,
    /// Number of tasks currently waiting
    waiting: Arc<AtomicUsize>,
    /// Backoff strategy for efficient spinning
    backoff: Backoff,
    /// Optional timeout duration
    timeout: Option<Duration<Millis>>,
}

impl Barrier {
    /// Create a new barrier for the specified number of tasks
    pub fn new(count: usize) -> Self {
        assert!(count > 0, "Barrier count must be positive");
        Self {
            count,
            generation: Arc::new(AtomicUsize::new(0)),
            waiting: Arc::new(AtomicUsize::new(0)),
            backoff: Backoff::with_step(Duration::from(1)),
            timeout: None,
        }
    }

    /// Set timeout duration after which waiting tasks will error
    pub fn with_timeout(mut self, timeout: Duration<Millis>) -> Self {
        self.timeout = Some(timeout);
        self
    }

    /// Wait for all tasks to arrive at the barrier
    pub async fn wait(&self) -> Result<usize, TimeoutError> {
        dbg!("WAIT");
        let generation = self.generation.load(Acquire);
        let start = Instant::now();

        // Register arrival
        let prev = self.waiting.fetch_add(1, AcqRel);

        if prev + 1 == self.count {
            // Last task to arrive
            self.waiting.store(0, Release);
            self.generation.fetch_add(1, Release);
            dbg!("RELEASE");
            Ok(generation)
        } else {
            // Wait for others with backoff
            loop {
                dbg!("TESTING");
                if let Some(timeout) = self.timeout {
                    if start.elapsed() > timeout {
                        return Err(TimeoutError(timeout));
                    }
                }

                if dbg!(self.generation.load(Acquire)) != dbg!(generation) {
                    dbg!("RELEASE");
                    // Barrier was released
                    return Ok(generation);
                }

                self.backoff.wait().await;
            }
        }
    }

    /// Reset the barrier to initial state
    pub fn reset(&self) {
        self.waiting.store(0, Release);
        self.generation.fetch_add(1, Release);
    }

    /// Get number of tasks currently waiting
    pub fn waiting(&self) -> usize {
        self.waiting.load(Acquire)
    }
}

#[derive(Debug)]
pub struct TimeoutError(Duration<Millis>);

impl std::fmt::Display for TimeoutError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Barrier wait timed out after {:?}", self.0)
    }
}

impl std::error::Error for TimeoutError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::rt::block_on;
    use std::sync::Arc;

    #[test]
    fn test_barrier() {
        let barrier = Arc::new(Barrier::new(4));
        let b1 = barrier.clone();
        let b2 = barrier.clone();
        let b3 = barrier.clone();

        let h1 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b1.wait().await.is_ok());
            });
        });

        let h2 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b2.wait().await.is_ok());
            });
        });

        let h3 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b3.wait().await.is_ok());
            });
        });

        block_on(barrier.wait());

        h1.join().unwrap();
        h2.join().unwrap();
        h3.join().unwrap();
    }

    #[test]
    fn test_barrier_timeout() {
        let barrier = Arc::new(Barrier::new(2).with_timeout(Duration::from(100)));
        let b1 = barrier.clone();

        let h1 = std::thread::spawn(move || {
            block_on(async move {
                assert!(matches!(b1.wait().await, Err(TimeoutError(_))));
            });
        });

        h1.join().unwrap();
    }

    #[test]
    fn test_barrier_reset() {
        let barrier = Arc::new(Barrier::new(2));

        // First generation
        let b1 = barrier.clone();
        let b2 = barrier.clone();

        let h1 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b1.wait().await.is_ok());
            });
        });

        let h2 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b2.wait().await.is_ok());
            });
        });

        h1.join().unwrap();
        h2.join().unwrap();

        // Reset and second generation
        barrier.reset();

        let b1 = barrier.clone();
        let b2 = barrier;

        let h1 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b1.wait().await.is_ok());
            });
        });

        let h2 = std::thread::spawn(move || {
            block_on(async move {
                assert!(b2.wait().await.is_ok());
            });
        });

        h1.join().unwrap();
        h2.join().unwrap();
    }
}
