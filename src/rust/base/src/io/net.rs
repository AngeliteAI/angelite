use std::{
    net::{Ipv6Addr, SocketAddr, ToSocketAddrs},
    ptr,
};

use crate::ffi::{self, CheckOperation};

pub struct Socket(*mut ffi::Socket);
pub struct Connection(*mut ffi::Socket);
pub struct Listener(*mut ffi::Socket);

macro_rules! socket_create {
    ($name:ident, $out:tt, $ty:expr) => {
        fn $name(addrs: impl ToSocketAddrs) -> Result<$out, ()> {
            for addr in addrs.to_socket_addrs().map_err(|_| ())? {
                let ipv6 = matches!(addr, SocketAddr::V6(_));
                let socket = unsafe {
                    ffi::socketCreate(ipv6, $ty, ptr::null_mut())
                        .expect("failed to allocate socket")
                };

                match unsafe { ffi::socketBind(socket, &addr.into()).check_operation() } {
                    Ok(_)
                        if let Ok(_) =
                            unsafe { ffi::socketListen(socket, 1000).check_operation() } =>
                    {
                        return Ok($out(socket));
                    }
                    Err(_) => {
                        unsafe { ffi::socketRelease(socket) };
                        continue;
                    }
                    _ => continue,
                }
            }

            return Err(());
        }
    };
}

socket_create!(bind, Socket, ffi::SocketType::Dgram);
