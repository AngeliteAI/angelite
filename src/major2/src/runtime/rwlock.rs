use std::cell::UnsafeCell;
use std::sync::atomic::{AtomicUsize, Ordering};
use std::ops::{Deref, DerefMut};

/// A simple reader-writer lock implementation that doesn't depend on any async runtime
pub struct RwLock<T: ?Sized> {
    state: AtomicUsize,
    data: UnsafeCell<T>,
}

// Constants for the lock state
const WRITER: usize = 1;
const READER_INCREMENT: usize = 2;

unsafe impl<T: ?Sized + Send> Send for RwLock<T> {}
unsafe impl<T: ?Sized + Send + Sync> Sync for RwLock<T> {}

impl<T> RwLock<T> {
    pub fn new(data: T) -> Self {
        Self {
            state: AtomicUsize::new(0),
            data: UnsafeCell::new(data),
        }
    }
}

impl<T: ?Sized> RwLock<T> {

    pub fn read(&self) -> RwLockReadGuard<'_, T> {
        loop {
            let state = self.state.load(Ordering::Acquire);
            
            // If there's no writer, try to add a reader
            if state & WRITER == 0 {
                if self.state.compare_exchange_weak(
                    state,
                    state + READER_INCREMENT,
                    Ordering::AcqRel,
                    Ordering::Acquire,
                ).is_ok() {
                    return RwLockReadGuard { lock: self };
                }
            }
            
            // Yield to avoid busy-waiting
            std::hint::spin_loop();
        }
    }

    pub fn write(&self) -> RwLockWriteGuard<'_, T> {
        loop {
            // Try to acquire the write lock when state is 0
            if self.state.compare_exchange_weak(
                0,
                WRITER,
                Ordering::AcqRel,
                Ordering::Acquire,
            ).is_ok() {
                return RwLockWriteGuard { lock: self };
            }
            
            // Yield to avoid busy-waiting
            std::hint::spin_loop();
        }
    }

    pub fn try_read(&self) -> Option<RwLockReadGuard<'_, T>> {
        let state = self.state.load(Ordering::Acquire);
        
        // If there's no writer, try to add a reader
        if state & WRITER == 0 {
            if self.state.compare_exchange(
                state,
                state + READER_INCREMENT,
                Ordering::AcqRel,
                Ordering::Acquire,
            ).is_ok() {
                return Some(RwLockReadGuard { lock: self });
            }
        }
        
        None
    }

    pub fn try_write(&self) -> Option<RwLockWriteGuard<'_, T>> {
        if self.state.compare_exchange(
            0,
            WRITER,
            Ordering::AcqRel,
            Ordering::Acquire,
        ).is_ok() {
            Some(RwLockWriteGuard { lock: self })
        } else {
            None
        }
    }
}

pub struct RwLockReadGuard<'a, T: ?Sized> {
    lock: &'a RwLock<T>,
}

impl<'a, T: ?Sized> Drop for RwLockReadGuard<'a, T> {
    fn drop(&mut self) {
        self.lock.state.fetch_sub(READER_INCREMENT, Ordering::Release);
    }
}

impl<'a, T: ?Sized> Deref for RwLockReadGuard<'a, T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.lock.data.get() }
    }
}

pub struct RwLockWriteGuard<'a, T: ?Sized> {
    lock: &'a RwLock<T>,
}

impl<'a, T: ?Sized> Drop for RwLockWriteGuard<'a, T> {
    fn drop(&mut self) {
        self.lock.state.store(0, Ordering::Release);
    }
}

impl<'a, T: ?Sized> Deref for RwLockWriteGuard<'a, T> {
    type Target = T;

    fn deref(&self) -> &Self::Target {
        unsafe { &*self.lock.data.get() }
    }
}

impl<'a, T: ?Sized> DerefMut for RwLockWriteGuard<'a, T> {
    fn deref_mut(&mut self) -> &mut Self::Target {
        unsafe { &mut *self.lock.data.get() }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::Arc;
    use std::thread;

    #[test]
    fn test_multiple_readers() {
        let lock = Arc::new(RwLock::new(42));
        let lock1 = lock.clone();
        let lock2 = lock.clone();

        let handle1 = thread::spawn(move || {
            let guard = lock1.read();
            assert_eq!(*guard, 42);
        });

        let handle2 = thread::spawn(move || {
            let guard = lock2.read();
            assert_eq!(*guard, 42);
        });

        handle1.join().unwrap();
        handle2.join().unwrap();
    }

    #[test]
    fn test_writer_blocks_readers() {
        let lock = Arc::new(RwLock::new(0));
        
        {
            let mut guard = lock.write();
            *guard = 42;
            
            // Try to read while holding write lock
            assert!(lock.try_read().is_none());
        }
        
        // Can read after write lock is dropped
        let guard = lock.read();
        assert_eq!(*guard, 42);
    }
}