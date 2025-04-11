//! Socket operations

use libc::{c_int, c_char, size_t, c_void};
use crate::types::{Socket, IpAddress, SockType, Option, Buffer};

#[link(name = "example")]
unsafe extern "C" {
    pub fn create(ipv6: bool, sock_type: SockType, user_data: *mut c_void) -> *mut Socket;
    pub fn bind(sock: *mut Socket, address: *const IpAddress, op_id: *mut u64) -> bool;
    pub fn listen(sock: *mut Socket, backlog: c_int, op_id: *mut u64) -> bool;
    pub fn accept(sock: *mut Socket, op_id: *mut u64) -> bool;
    pub fn connect(sock: *mut Socket, address: *const IpAddress, op_id: *mut u64) -> bool;
    pub fn recv(sock: *mut Socket, buffer: *mut Buffer, op_id: *mut u64) -> bool;
    pub fn send(sock: *mut Socket, buffer: *mut Buffer, op_id: *mut u64) -> bool;
    pub fn close(sock: *mut Socket) -> bool;
    pub fn release(sock: *mut Socket) -> bool;
    pub fn set_option(sock: *mut Socket, option: Option, value: *const c_void, len: u32) -> bool;
}