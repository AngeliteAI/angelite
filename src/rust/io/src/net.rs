use crate::raw;
use std::{
    net::{Ipv6Addr, SocketAddr, ToSocketAddrs},
    pin::Pin,
    ptr,
};

use io_sys::socket as ffi;
use io_sys::types as ty;

use super::OperationId;

macro_rules! socket_struct {
    ($name:ident) => {
        pub struct $name {
            handle: *mut Socket,
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
    ($out:tt, $ty:expr) => {
        impl $out {
            async fn create(addrs: impl ToSocketAddrs) -> Result<$out, ()> {
                for addr in addrs.to_socket_addrs().map_err(|_| ())? {
                    let ipv6 = matches!(addr, SocketAddr::V6(_));
                    let mut op = Box::pin(0u64);
                    let optr = &mut *op.as_mut() as *mut u64;
                    let socket = unsafe {
                        ffi::create(ipv6, $ty, optr as *mut _)
                    };
                    let handle = super::Handle::$out(unsafe { $out::from_raw(socket) });
                    let handle_ref = &handle;

                    let result =
                        crate::stall!(handle_ref, op, { ffi::bind(socket, &addr.into(), optr) });

                    dbg!(result);
                }

                return Err(());
            }
        }
    };
}

socket_create!(Socket, ty::SockType::Dgram);
socket_create!(Listener, ty::SockType::Stream);
socket_create!(Connection, ty::SockType::Stream);

raw!(Socket, *mut ty::Socket);
raw!(Listener, *mut ty::Socket);
raw!(Connection, *mut ty::Socket);

impl Socket {
    pub fn latest_operation_id(&self) -> OperationId {
        OperationId(*self.indicator)
    }
}
