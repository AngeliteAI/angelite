use std::{
    net::{Ipv6Addr, SocketAddr, ToSocketAddrs},
    ptr,
};

use crate::bindings::{self, CheckOperation};

pub struct Socket(*mut bindings::Socket);
pub struct Connection(*mut bindings::Socket);
pub struct Listener(*mut bindings::Socket);

macro_rules! socket_create {
    ($name:ident, $out:tt, $ty:expr) => {
        impl $out {
            fn $name(addrs: impl ToSocketAddrs) -> Result<$out, ()> {
                for addr in addrs.to_socket_addrs().map_err(|_| ())? {
                    let ipv6 = matches!(addr, SocketAddr::V6(_));
                    let socket = unsafe {
                        bindings::socketCreate(ipv6, $ty, ptr::null_mut())
                            .expect("failed to allocate socket")
                    };

                    match unsafe { bindings::socketBind(socket, &addr.into()).check_operation() } {
                        Ok(_)
                            if let Ok(_) = unsafe {
                                bindings::socketListen(socket, 1000).check_operation()
                            } =>
                        {
                            return Ok($out(socket));
                        }
                        Err(_) => {
                            unsafe { bindings::socketRelease(socket) };
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

macro_rules! socket_raw {
    ($in:tt) => {
        impl $in {
            unsafe fn into_raw(self) -> *mut bindings::Socket {
                self.0
            }
            unsafe fn from_raw(raw: *mut bindings::Socket) -> Self {
                Self(raw)
            }
        }
    };
}

socket_create!(bind, Socket, bindings::SocketType::Dgram);
socket_create!(listen, Listener, bindings::SocketType::Stream);
socket_create!(connect, Connection, bindings::SocketType::Stream);

socket_raw!(Socket);
socket_raw!(Listener);
socket_raw!(Connection);
