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
    };
}

socket_struct!(Socket);
socket_struct!(Connection);
socket_struct!(Listener);

macro_rules! socket_create {
    ($name:ident, $out:tt, $ty:expr) => {
        impl $out {
            fn $name(addrs: impl ToSocketAddrs) -> Result<$out, ()> {
                for addr in addrs.to_socket_addrs().map_err(|_| ())? {
                    let ipv6 = matches!(addr, SocketAddr::V6(_));
                    let indicator = Box::pin(0u64);
                    let socket = unsafe {
                        ffi::create(ipv6, $ty, indicator.as_mut_ptr())
                            .expect("failed to allocate socket")
                    };

                    match unsafe { ffi::bind(socket, &addr.into()).check_operation() } {
                        Ok(_)
                            if let Ok(_) =
                                unsafe { ffi::listen(socket, 1000).check_operation() } =>
                        {
                            return Ok($out(socket));
                        }
                        Err(_) => {
                            unsafe { ffi::release(socket) };
                            continue;
                        }
                        _ => continue,
                    }
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
    fn latest_operation_id(&self) -> OperationId {
        OperationId(**self.indicator)
    }
}
