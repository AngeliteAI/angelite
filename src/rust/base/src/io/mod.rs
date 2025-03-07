pub mod file;
pub mod net;

pub enum Handle {
    File(file::File),
    Socket(net::Socket),
}

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
                self.0
            }
            pub unsafe fn from_raw(raw: $ffi) -> Self {
                Self(raw)
            }
        }
    };
}

mod future {
    use crate::io::OperationId;

    use super::Handle;

    pub struct Stall<'a>(OperationId, &'a Handle);

    impl Future for Stall<'_> {
        type Output = ();
        fn poll(
            self: std::pin::Pin<&mut Self>,
            cx: &mut std::task::Context<'_>,
        ) -> std::task::Poll<Self::Output> {
        }
    }
}
