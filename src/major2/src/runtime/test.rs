//! Tests for the custom runtime

#[cfg(test)]
mod tests {
    use super::super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::sync::Arc;
    use std::time::Duration;
    
    #[test]
    fn test_basic_spawn() {
        let executor = runtime(2);
        let counter = Arc::new(AtomicUsize::new(0));
        
        let counter_clone = counter.clone();
        let handle = executor.spawn(async move {
            counter_clone.fetch_add(1, Ordering::Relaxed);
            42
        });
        
        let result = handle.block_on();
        assert_eq!(result, 42);
        assert_eq!(counter.load(Ordering::Relaxed), 1);
    }
    
    #[test]
    fn test_multiple_tasks() {
        let executor = runtime(4);
        let counter = Arc::new(AtomicUsize::new(0));
        
        let mut handles = vec![];
        for i in 0..10 {
            let counter_clone = counter.clone();
            let handle = executor.spawn(async move {
                counter_clone.fetch_add(1, Ordering::Relaxed);
                i
            });
            handles.push(handle);
        }
        
        let mut results = vec![];
        for handle in handles {
            results.push(handle.block_on());
        }
        
        assert_eq!(counter.load(Ordering::Relaxed), 10);
        assert_eq!(results, vec![0, 1, 2, 3, 4, 5, 6, 7, 8, 9]);
    }
    
    #[test]
    fn test_block_on() {
        let result = block_on(async {
            1 + 2
        });
        assert_eq!(result, 3);
    }
    
    #[test]
    fn test_async_await() {
        let executor = runtime(2);
        
        let handle = executor.spawn(async {
            let a = async { 10 }.await;
            let b = async { 20 }.await;
            a + b
        });
        
        let result = handle.block_on();
        assert_eq!(result, 30);
    }
}