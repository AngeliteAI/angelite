use crate::raw;
use std::{
    net::{Ipv6Addr, SocketAddr, ToSocketAddrs},
    pin::Pin,
    ptr,
};

use crate::bindings::io;
use crate::bindings::socket as ffi;

use crate::ffi::CheckOperation;

use super::OperationId;

macro_rules! socket_struct {
    ($name:ident) => {
        pub struct $name {
            handle: *mut ffi::Socket,
            indicator: Pin<Box<u64>>,
        }

        impl Default for $name {
            fn default() -> $name {
                $name {
                    handle: ptr::null_mut(),
                    indicator: Box::pin(0),
                }
            }
        }
    };
}

socket_struct!(Socket);
socket_struct!(Connection);
socket_struct!(Listener);

macro_rules! socket_create {
    ($name:ident,  $out:tt, $ty:expr) => {
        impl $out {
            async fn $name(addrs: impl ToSocketAddrs) -> Result<$out, ()> {
                for addr in addrs.to_socket_addrs().map_err(|_| ())? {
                    let ipv6 = matches!(addr, SocketAddr::V6(_));
                    let mut op = Box::pin(0u64);
                    let optr = &mut *op.as_mut() as *mut u64;
                    let socket = unsafe {
                        ffi::create(ipv6, $ty, optr as *mut _).expect("failed to allocate socket")
                    };
                    let handle = super::Handle::$out(unsafe { $out::from_raw(socket) });
                    let handle_ref = &handle;

                    crate::stall!(handle_ref, op, { ffi::bind(socket, &addr.into(), optr) });
                }

                return Err(());
            }
        }
    };
}

socket_create!(bind, Socket, io::SockType::Dgram);
socket_create!(listen, Listener, io::SockType::Stream);
socket_create!(connect, Connection, io::SockType::Stream);

raw!(Socket, *mut ffi::Socket);
raw!(Listener, *mut ffi::Socket);
raw!(Connection, *mut ffi::Socket);

impl Socket {
    pub fn latest_operation_id(&self) -> OperationId {
        OperationId(*self.indicator)
    }
}
