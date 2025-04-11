pub mod file;
pub mod net;

pub enum Handle {
    File(file::File),
    Socket(net::Socket),
    Listener(net::Listener),
    Connection(net::Connection),
}

impl Handle {
    fn latest_operation_id(&self) -> OperationId {
        match self {
            Handle::File(_) => todo!(),
            Handle::Socket(socket) => socket.latest_operation_id(),
            _ => todo!(),
        }
    }
}

#[derive(PartialEq, Eq, PartialOrd, Ord)]
pub struct OperationId(pub(crate) u64);

#[repr(C)]
pub enum OperationType {
    Accept,
    Connect,
    Read,
    Write,
    Close,
    Seek,
    Flush,
}

pub struct Operation {
    pub id: OperationId,
    pub ty: OperationType,
    pub handle: Handle,
    pub user_data: *mut (),
}

pub struct Complete(pub i32);

#[macro_export]
macro_rules! raw {
    ($in:ty, $ffi:ty) => {
        impl $in {
            pub unsafe fn into_raw(self) -> $ffi {
                self.handle
            }
            pub unsafe fn from_raw(raw: $ffi) -> Self {
                Self {
                    handle: raw,
                    ..Default::default()
                }
            }
        }
    };
}

mod future {
    use std::task::Poll;

    use crate::io::OperationId;

    use super::Handle;

    #[macro_export]
    macro_rules! stall {
        ($handle:ident, $op:ident, $ffi:expr) => {{
            *$op = 0u64;
            let ret = unsafe { $ffi };
            if let Err(err) = ret.check_operation() {
                panic!("error");
            }
            (crate::io::future::Stall {
                operation_id: OperationId(*$op),
                handle: $handle,
            })
            .await
        }};
    }

    pub struct Stall<'a> {
        pub operation_id: OperationId,
        pub handle: &'a Handle,
    }

    impl Future for Stall<'_> {
        type Output = ();
        fn poll(
            self: std::pin::Pin<&mut Self>,
            cx: &mut std::task::Context<'_>,
        ) -> std::task::Poll<Self::Output> {
            if self.operation_id < self.handle.latest_operation_id() {
                Poll::Ready(())
            } else {
                Poll::Pending
            }
        }
    }
}
