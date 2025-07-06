use std::collections::VecDeque;
use std::sync::{Arc, Mutex, Condvar};

/// A simple multi-producer, single-consumer channel
pub fn channel<T>(buffer_size: usize) -> (Sender<T>, Receiver<T>) {
    let inner = Arc::new(Inner {
        queue: Mutex::new(VecDeque::with_capacity(buffer_size)),
        condvar: Condvar::new(),
        buffer_size,
        closed: Mutex::new(false),
    });
    
    (
        Sender { inner: inner.clone() },
        Receiver { inner },
    )
}

struct Inner<T> {
    queue: Mutex<VecDeque<T>>,
    condvar: Condvar,
    buffer_size: usize,
    closed: Mutex<bool>,
}

pub struct Sender<T> {
    inner: Arc<Inner<T>>,
}

pub struct Receiver<T> {
    inner: Arc<Inner<T>>,
}

impl<T> Sender<T> {
    pub fn send(&self, value: T) -> Result<(), SendError<T>> {
        let mut queue = self.inner.queue.lock().unwrap();
        
        if *self.inner.closed.lock().unwrap() {
            return Err(SendError(value));
        }
        
        // Wait if buffer is full
        while queue.len() >= self.inner.buffer_size {
            queue = self.inner.condvar.wait(queue).unwrap();
            if *self.inner.closed.lock().unwrap() {
                return Err(SendError(value));
            }
        }
        
        queue.push_back(value);
        self.inner.condvar.notify_one();
        Ok(())
    }
    
    pub fn try_send(&self, value: T) -> Result<(), TrySendError<T>> {
        let mut queue = self.inner.queue.lock().unwrap();
        
        if *self.inner.closed.lock().unwrap() {
            return Err(TrySendError::Closed(value));
        }
        
        if queue.len() >= self.inner.buffer_size {
            return Err(TrySendError::Full(value));
        }
        
        queue.push_back(value);
        self.inner.condvar.notify_one();
        Ok(())
    }
}

impl<T> Receiver<T> {
    pub fn recv(&self) -> Option<T> {
        let mut queue = self.inner.queue.lock().unwrap();
        
        loop {
            if let Some(value) = queue.pop_front() {
                self.inner.condvar.notify_one();
                return Some(value);
            }
            
            if *self.inner.closed.lock().unwrap() {
                return None;
            }
            
            queue = self.inner.condvar.wait(queue).unwrap();
        }
    }
    
    pub fn try_recv(&self) -> Result<T, TryRecvError> {
        let mut queue = self.inner.queue.lock().unwrap();
        
        if let Some(value) = queue.pop_front() {
            self.inner.condvar.notify_one();
            Ok(value)
        } else if *self.inner.closed.lock().unwrap() {
            Err(TryRecvError::Disconnected)
        } else {
            Err(TryRecvError::Empty)
        }
    }
}

impl<T> Clone for Sender<T> {
    fn clone(&self) -> Self {
        Self {
            inner: self.inner.clone(),
        }
    }
}

impl<T> Drop for Receiver<T> {
    fn drop(&mut self) {
        *self.inner.closed.lock().unwrap() = true;
        self.inner.condvar.notify_all();
    }
}

#[derive(Debug)]
pub struct SendError<T>(pub T);

impl<T> std::fmt::Display for SendError<T> {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "channel closed")
    }
}

impl<T: std::fmt::Debug> std::error::Error for SendError<T> {}

#[derive(Debug)]
pub enum TrySendError<T> {
    Full(T),
    Closed(T),
}

#[derive(Debug)]
pub enum TryRecvError {
    Empty,
    Disconnected,
}

// Async adapter for use with our runtime
use std::future::Future;
use std::pin::Pin;
use std::task::{Context, Poll, Waker};

pub struct AsyncSender<T> {
    sender: Sender<T>,
    waker_registry: Arc<Mutex<Vec<Waker>>>,
}

pub struct AsyncReceiver<T> {
    receiver: Receiver<T>,
    waker_registry: Arc<Mutex<Vec<Waker>>>,
}

pub fn async_channel<T>(buffer_size: usize) -> (AsyncSender<T>, AsyncReceiver<T>) {
    let (sender, receiver) = channel(buffer_size);
    let waker_registry = Arc::new(Mutex::new(Vec::new()));
    
    (
        AsyncSender {
            sender,
            waker_registry: waker_registry.clone(),
        },
        AsyncReceiver {
            receiver,
            waker_registry,
        },
    )
}

impl<T: Send + 'static> AsyncSender<T> {
    pub async fn send(&self, value: T) -> Result<(), SendError<T>> {
        SendFuture {
            sender: &self.sender,
            value: Some(value),
            waker_registry: &self.waker_registry,
        }.await
    }
    
    pub fn try_send(&self, value: T) -> Result<(), TrySendError<T>> {
        self.sender.try_send(value)
    }
}

impl<T: Send + 'static> AsyncReceiver<T> {
    pub async fn recv(&mut self) -> Option<T> {
        RecvFuture {
            receiver: &self.receiver,
            waker_registry: &self.waker_registry,
        }.await
    }
    
    pub fn try_recv(&self) -> Result<T, TryRecvError> {
        self.receiver.try_recv()
    }
}

impl<T> Clone for AsyncSender<T> {
    fn clone(&self) -> Self {
        Self {
            sender: self.sender.clone(),
            waker_registry: self.waker_registry.clone(),
        }
    }
}

struct SendFuture<'a, T> {
    sender: &'a Sender<T>,
    value: Option<T>,
    waker_registry: &'a Arc<Mutex<Vec<Waker>>>,
}

impl<'a, T: Send> Future for SendFuture<'a, T> {
    type Output = Result<(), SendError<T>>;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        let this = unsafe { self.get_unchecked_mut() };
        
        if let Some(value) = this.value.take() {
            match this.sender.try_send(value) {
                Ok(()) => {
                    // Wake up any waiting receivers
                    let wakers = this.waker_registry.lock().unwrap();
                    for waker in wakers.iter() {
                        waker.wake_by_ref();
                    }
                    Poll::Ready(Ok(()))
                }
                Err(TrySendError::Full(v)) => {
                    this.value = Some(v);
                    this.waker_registry.lock().unwrap().push(cx.waker().clone());
                    Poll::Pending
                }
                Err(TrySendError::Closed(v)) => {
                    Poll::Ready(Err(SendError(v)))
                }
            }
        } else {
            Poll::Ready(Ok(()))
        }
    }
}

struct RecvFuture<'a, T> {
    receiver: &'a Receiver<T>,
    waker_registry: &'a Arc<Mutex<Vec<Waker>>>,
}

impl<'a, T: Send> Future for RecvFuture<'a, T> {
    type Output = Option<T>;
    
    fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output> {
        match self.receiver.try_recv() {
            Ok(value) => {
                // Wake up any waiting senders
                let wakers = self.waker_registry.lock().unwrap();
                for waker in wakers.iter() {
                    waker.wake_by_ref();
                }
                Poll::Ready(Some(value))
            }
            Err(TryRecvError::Empty) => {
                self.waker_registry.lock().unwrap().push(cx.waker().clone());
                Poll::Pending
            }
            Err(TryRecvError::Disconnected) => {
                Poll::Ready(None)
            }
        }
    }
}