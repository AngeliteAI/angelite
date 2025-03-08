use crate::bindings::cpu;
use libc;
use std::mem::ManuallyDrop;

#[repr(C)]
pub struct Socket {}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct IpAddress {
    pub is_ipv6: bool,
    pub addr: IpAddressUnion,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub union IpAddressUnion {
    pub ipv4: IpAddressV4,
    pub ipv6: IpAddressV6,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct IpAddressV4 {
    pub addr: [u8; 4],
    pub port: u16,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct IpAddressV6 {
    pub addr: [u8; 16],
    pub port: u16,
}

#[repr(C)]
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Option {
    ReuseAddr = 2,
    RcvTimeo = 3,
    SndTimeo = 4,
    KeepAlive = 5,
    Linger = 6,
    BufferSize = 7,
    NoDelay = 8,
}

unsafe extern "C" {
    #[link_name = "socketCreate"]
    pub fn create(ipv6: bool, sock_type: crate::bindings::io::SockType, user_data: *mut libc::c_void) -> std::option::Option<*mut Socket>;
    #[link_name = "socketBind"]
    pub fn bind(sock: *mut Socket, address: *const IpAddress, op_id: *mut u64) -> bool;
    #[link_name = "socketListen"]
    pub fn listen(sock: *mut Socket, backlog: i32, op_id: *mut u64) -> bool;
    #[link_name = "socketAccept"]
    pub fn accept(sock: *mut Socket, op_id: *mut u64) -> bool;
    #[link_name = "socketConnect"]
    pub fn connect(sock: *mut Socket, address: *const IpAddress, op_id: *mut u64) -> bool;
    #[link_name = "socketRecv"]
    pub fn recv(sock: *mut Socket, buffer: *mut cpu::Buffer, op_id: *mut u64) -> bool;
    #[link_name = "socketSend"]
    pub fn send(sock: *mut Socket, buffer: *mut cpu::Buffer, op_id: *mut u64) -> bool;
    #[link_name = "socketClose"]
    pub fn close(sock: *mut Socket) -> bool;
    #[link_name = "socketRelease"]
    pub fn release(sock: *mut Socket) -> bool;
    #[link_name = "socketSetOption"]
    pub fn set_option(sock: *mut Socket, option: Option, value: *const libc::c_void, len: u32) -> bool;
}