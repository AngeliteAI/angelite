//! Task implementation for the runtime

use super::executor::Handle;
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex};
use std::sync::atomic::{AtomicBool, Ordering};
use std::task::{Context, Poll, Wake, Waker};
use std::any::Any;

/// Task ID
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub struct TaskId(pub(crate) usize);

/// A task that can be executed by the runtime
pub struct Task {
    id: TaskId,
    future: Mutex<Option<Pin<Box<dyn Future<Output = Box<dyn Any + Send>> + Send>>>>,
    executor: Handle,
    completed: AtomicBool,
    result: Mutex<Option<Box<dyn Any + Send>>>,
    waker: Mutex<Option<Waker>>,
}

/// Handle for joining a spawned task
pub struct JoinHandle<T> {
    task: Arc<Task>,
    _phantom: std::marker::PhantomData<T>,
}

impl Task {
    /// Create a new task
    pub fn new<F>(id: TaskId, future: F, executor: Handle) -> Self
    where
        F: Future + Send + 'static,
        F::Output: Send + 'static,
    {
        let future = Box::pin(async move {
            Box::new(future.await) as Box<dyn Any + Send>
        });
        
        Task {
            id,
            future: Mutex::new(Some(future)),
            executor,
            completed: AtomicBool::new(false),
            result: Mutex::new(None),
            waker: Mutex::new(None),
        }
    }
    
    /// Poll the task
    pub fn poll(self: Arc<Self>) {
        // Create waker
        let waker = Arc::clone(&self).into();
        let mut cx = Context::from_waker(&waker);
        
        // Poll the future
        let mut future_guard = self.future.lock().unwrap();
        if let Some(mut future) = future_guard.as_mut() {
            match future.as_mut().poll(&mut cx) {
                Poll::Ready(result) => {
                    // Take the future out to prevent double polling
                    let _ = future_guard.take();
                    drop(future_guard); // Release lock before storing result
                    
                    *self.result.lock().unwrap() = Some(result);
                    self.completed.store(true, Ordering::Relaxed);
                    
                    // Wake any waiting JoinHandle
                    if let Some(waker) = self.waker.lock().unwrap().take() {
                        waker.wake();
                    }
                    
                    self.executor.remove_task(self.id);
                }
                Poll::Pending => {
                    // Task will be rescheduled when woken
                }
            }
        }
    }
    
    /// Check if the task is completed
    pub fn is_completed(&self) -> bool {
        self.completed.load(Ordering::Relaxed)
    }
}

impl Wake for Task {
    fn wake(self: Arc<Self>) {
        if !self.completed.load(Ordering::Relaxed) {
            let task = Arc::clone(&self);
            self.executor.schedule(task);
        }
    }
    
    fn wake_by_ref(self: &Arc<Self>) {
        if !self.completed.load(Ordering::Relaxed) {
            self.executor.schedule(Arc::clone(self));
        }
    }
}

impl<T> JoinHandle<T> {
    pub(crate) fn new(task: Arc<Task>) -> Self {
        JoinHandle {
            task,
            _phantom: std::marker::PhantomData,
        }
    }
    
    /// Check if the task is finished
    pub fn is_finished(&self) -> bool {
        self.task.is_completed()
    }
}

impl<T> Future for JoinHandle<T>
where
    T: 'static,
{
    type Output = T;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        if self.task.is_completed() {
            // Task is done, extract result
            let mut result_guard = self.task.result.lock().unwrap();
            let result = result_guard.take()
                .expect("Task completed but no result stored");
            
            // Downcast and extract the value
            let value = *result.downcast::<T>()
                .expect("Type mismatch in JoinHandle");
            
            Poll::Ready(value)
        } else {
            // Store waker for when task completes
            *self.task.waker.lock().unwrap() = Some(cx.waker().clone());
            Poll::Pending
        }
    }
}

/// Create a no-op waker for extracting results
fn noop_waker() -> Waker {
    use std::task::{RawWaker, RawWakerVTable};
    
    fn no_op(_: *const ()) {}
    fn clone(data: *const ()) -> RawWaker {
        RawWaker::new(data, &VTABLE)
    }
    
    static VTABLE: RawWakerVTable = RawWakerVTable::new(
        clone,
        no_op,
        no_op,
        no_op,
    );
    
    static DATA: () = ();
    unsafe {
        Waker::from_raw(RawWaker::new(&DATA as *const (), &VTABLE))
    }
}

/// Yield control back to the executor
pub async fn yield_now() {
    struct YieldNow {
        yielded: bool,
    }
    
    impl Future for YieldNow {
        type Output = ();
        
        fn poll(mut self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<()> {
            if self.yielded {
                Poll::Ready(())
            } else {
                self.yielded = true;
                cx.waker().wake_by_ref();
                Poll::Pending
            }
        }
    }
    
    YieldNow { yielded: false }.await
}