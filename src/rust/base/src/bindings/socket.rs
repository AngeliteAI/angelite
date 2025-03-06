extern "C" {
    #[link_name = "socketCreate"]
    pub fn create(ipv6: bool, user_data: *mut libc::c_void) -> *mut libc::c_void;
    #[link_name = "socketBind"]
    pub fn bind(sock: *mut libc::c_void, address: *const IpAddress) -> bool;
    #[link_name = "socketListen"]
    pub fn listen(sock: *mut libc::c_void, backlog: i32) -> bool;
    #[link_name = "socketAccept"]
    pub fn accept(sock: *mut libc::c_void) -> bool;
    #[link_name = "socketConnect"]
    pub fn connect(sock: *mut libc::c_void, address: *const IpAddress) -> bool;
    #[link_name = "socketRecv"]
    pub fn recv(sock: *mut libc::c_void, buffer: *mut cpu::Buffer) -> bool;
    #[link_name = "socketSend"]
    pub fn send(sock: *mut libc::c_void, buffer: *mut cpu::Buffer) -> bool;
    #[link_name = "socketClose"]
    pub fn close(sock: *mut libc::c_void) -> bool;
    #[link_name = "socketRelease"]
    pub fn release(sock: *mut libc::c_void) -> bool;
    #[link_name = "socketSetOption"]
    pub fn set_option(sock: *mut libc::c_void, option: Option, value: *const libc::c_void, len: u32) -> bool;
}

#[repr(C)]
pub struct IpAddress {
    pub is_ipv6: bool,
    pub addr: IpAddressUnion,
}

#[repr(C)]
pub union IpAddressUnion {
    pub ipv4: IpV4Address,
    pub ipv6: IpV6Address,
}

#[repr(C)]
pub struct IpV4Address {
    pub addr: [u8; 4],
    pub port: u16,
}

#[repr(C)]
pub struct IpV6Address {
    pub addr: [u8; 16],
    pub port: u16,
}

#[repr(i32)]
pub enum Option {
    ReuseAddr = 2,
    RcvTimeout = 3,
    SndTimeout = 4,
    KeepAlive = 5,
    Linger = 6,
    BufferSize = 7,
    NoDelay = 8,
}

pub struct Socket {}