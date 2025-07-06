//! Thread pool executor implementation

use super::task::{Task, TaskId, JoinHandle};
use std::future::Future;
use std::pin::Pin;
use std::sync::{Arc, Mutex, Condvar};
use std::sync::atomic::{AtomicUsize, AtomicBool, Ordering};
use std::task::{Context, Poll, Wake, Waker};
use std::thread;
use std::collections::{VecDeque, HashMap};
use std::time::Duration;
use std::cell::RefCell;

thread_local! {
    static CURRENT_HANDLE: RefCell<Option<Handle>> = RefCell::new(None);
}

/// A thread pool executor for running async tasks
pub struct Executor {
    inner: Arc<ExecutorInner>,
    handle: Handle,
}

/// Handle to interact with the executor
#[derive(Clone)]
pub struct Handle {
    inner: Arc<ExecutorInner>,
}

struct ExecutorInner {
    /// Queue of tasks ready to run
    ready_queue: Mutex<VecDeque<Arc<Task>>>,
    /// Condition variable to wake up worker threads
    queue_condvar: Condvar,
    /// Number of worker threads
    num_threads: usize,
    /// Shutdown flag
    shutdown: AtomicBool,
    /// Next task ID
    next_task_id: AtomicUsize,
    /// All tasks
    tasks: Mutex<HashMap<TaskId, Arc<Task>>>,
}

impl Executor {
    /// Create a new executor with the specified number of worker threads
    pub fn new(num_threads: usize) -> Self {
        let inner = Arc::new(ExecutorInner {
            ready_queue: Mutex::new(VecDeque::new()),
            queue_condvar: Condvar::new(),
            num_threads,
            shutdown: AtomicBool::new(false),
            next_task_id: AtomicUsize::new(0),
            tasks: Mutex::new(HashMap::new()),
        });
        
        let handle = Handle {
            inner: inner.clone(),
        };
        
        // Spawn worker threads
        for i in 0..num_threads {
            let inner = inner.clone();
            let worker_handle = handle.clone();
            thread::Builder::new()
                .name(format!("major-runtime-worker-{}", i))
                .spawn(move || {
                    // Set the runtime handle for this worker thread
                    worker_handle.set_current();
                    worker_thread(inner);
                })
                .expect("Failed to spawn worker thread");
        }
        
        Executor { inner, handle }
    }
    
    /// Get a handle to the executor
    pub fn handle(&self) -> Handle {
        self.handle.clone()
    }
    
    /// Spawn a future on the executor
    pub fn spawn<F>(&self, future: F) -> JoinHandle<F::Output>
    where
        F: Future + Send + 'static,
        F::Output: Send + 'static,
    {
        self.handle.spawn(future)
    }
    
    /// Spawn a blocking task on a dedicated thread
    pub fn spawn_blocking<F, R>(&self, f: F) -> JoinHandle<R>
    where
        F: FnOnce() -> R + Send + 'static,
        R: Send + 'static,
    {
        self.handle.spawn_blocking(f)
    }
    
    /// Block on a future
    pub fn block_on<F: Future>(&self, future: F) -> F::Output {
        block_on_with_executor(future, &self.handle)
    }
    
    /// Shutdown the executor
    pub fn shutdown(&self) {
        self.inner.shutdown.store(true, Ordering::Relaxed);
        self.inner.queue_condvar.notify_all();
    }
}

impl Drop for Executor {
    fn drop(&mut self) {
        self.shutdown();
    }
}

impl Handle {
    /// Get the current runtime handle
    pub fn current() -> Self {
        Self::try_current()
            .expect("No runtime handle set for current thread")
    }
    
    /// Try to get the current runtime handle
    pub fn try_current() -> Option<Self> {
        CURRENT_HANDLE.with(|h| h.borrow().clone())
    }
    
    /// Set the current runtime handle for this thread
    pub fn set_current(&self) {
        CURRENT_HANDLE.with(|h| {
            *h.borrow_mut() = Some(self.clone());
        });
    }
    
    /// Enter the runtime context for a closure
    pub fn enter<F, R>(&self, f: F) -> R
    where
        F: FnOnce() -> R,
    {
        let prev = Self::try_current();
        self.set_current();
        let result = f();
        CURRENT_HANDLE.with(|h| {
            *h.borrow_mut() = prev;
        });
        result
    }
    
    /// Spawn a future on the executor
    pub fn spawn<F>(&self, future: F) -> JoinHandle<F::Output>
    where
        F: Future + Send + 'static,
        F::Output: Send + 'static,
    {
        let task_id = TaskId(self.inner.next_task_id.fetch_add(1, Ordering::Relaxed));
        let task = Arc::new(Task::new(task_id, future, self.clone()));
        
        // Store the task
        {
            let mut tasks = self.inner.tasks.lock().unwrap();
            tasks.insert(task_id, task.clone());
        }
        
        // Schedule it
        self.schedule(task.clone());
        
        JoinHandle::new(task)
    }
    
    /// Spawn a blocking task on a dedicated thread
    pub fn spawn_blocking<F, R>(&self, f: F) -> JoinHandle<R>
    where
        F: FnOnce() -> R + Send + 'static,
        R: Send + 'static,
    {
        use std::sync::mpsc;
        
        // Create a oneshot channel for the result
        let (tx, rx) = mpsc::channel();
        
        // Clone handle for the blocking thread
        let handle = self.clone();
        
        // Spawn a dedicated thread for the blocking operation
        thread::spawn(move || {
            // Set the runtime handle for this blocking thread
            handle.set_current();
            
            let result = f();
            let _ = tx.send(result);
        });
        
        // Create a future that waits for the result
        self.spawn(async move {
            // Poll the receiver in a loop
            loop {
                match rx.try_recv() {
                    Ok(result) => return result,
                    Err(mpsc::TryRecvError::Empty) => {
                        // Yield to other tasks
                        super::task::yield_now().await;
                    }
                    Err(mpsc::TryRecvError::Disconnected) => {
                        panic!("Blocking task panicked");
                    }
                }
            }
        })
    }
    
    /// Schedule a task to run
    pub(crate) fn schedule(&self, task: Arc<Task>) {
        let mut queue = self.inner.ready_queue.lock().unwrap();
        queue.push_back(task);
        drop(queue);
        self.inner.queue_condvar.notify_one();
    }
    
    /// Remove a task from the executor
    pub(crate) fn remove_task(&self, id: TaskId) {
        let mut tasks = self.inner.tasks.lock().unwrap();
        tasks.remove(&id);
    }
}

/// Worker thread function
fn worker_thread(inner: Arc<ExecutorInner>) {
    while !inner.shutdown.load(Ordering::Relaxed) {
        let task = {
            let mut queue = inner.ready_queue.lock().unwrap();
            while queue.is_empty() && !inner.shutdown.load(Ordering::Relaxed) {
                queue = inner.queue_condvar.wait(queue).unwrap();
            }
            queue.pop_front()
        };
        
        if let Some(task) = task {
            task.poll();
        }
    }
}

/// Block on a future using a minimal executor
pub fn block_on<F: Future>(future: F) -> F::Output {
    let executor = Executor::new(1);
    block_on_with_executor(future, &executor.handle())
}

/// Block on a future with a specific executor handle
fn block_on_with_executor<F: Future>(future: F, _handle: &Handle) -> F::Output {
    use std::task::RawWaker;
    use std::task::RawWakerVTable;
    
    // Create a special blocking task
    struct BlockingWaker {
        thread: thread::Thread,
    }
    
    impl Wake for BlockingWaker {
        fn wake(self: Arc<Self>) {
            self.thread.unpark();
        }
        
        fn wake_by_ref(self: &Arc<Self>) {
            self.thread.unpark();
        }
    }
    
    let thread = thread::current();
    let waker = Arc::new(BlockingWaker { thread }).into();
    let mut cx = Context::from_waker(&waker);
    let mut future = Box::pin(future);
    
    loop {
        match future.as_mut().poll(&mut cx) {
            Poll::Ready(output) => return output,
            Poll::Pending => thread::park(),
        }
    }
}