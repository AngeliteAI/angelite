extern "C" {
    pub enum Socket {}

    // IP Address structure
    #[repr(C)]
    pub struct IpAddress {
        is_ipv6: bool,
        addr: IpAddrUnion,
    }

    #[repr(C)]
    pub union IpAddrUnion {
        ipv4: Ipv4Addr,
        ipv6: Ipv6Addr,
    }

    #[repr(C)]
    pub struct Ipv4Addr {
        addr: [u8; 4],
        port: u16,
    }

    #[repr(C)]
    pub struct Ipv6Addr {
        addr: [u8; 16],
        port: u16,
    }

    // Socket options enum
    #[repr(i32)]
    pub enum Option {
        REUSEADDR = 2,
        RCVTIMEO = 3,
        SNDTIMEO = 4,
        KEEPALIVE = 5,
        LINGER = 6,
        BUFFER_SIZE = 7,
        NODELAY = 8,
    }

    // CPU Buffer (assumed to be defined elsewhere)
    pub enum Buffer {}

    extern "C" {
        // Socket function declarations
        pub fn socketCreate(ipv6: bool, user_data: *mut std::ffi::c_void) -> *mut Socket;
        pub fn socketBind(sock: *mut Socket, address: *const IpAddress) -> bool;
        pub fn socketListen(sock: *mut Socket, backlog: i32) -> bool;
        pub fn socketAccept(sock: *mut Socket) -> bool;
        pub fn socketConnect(sock: *mut Socket, address: *const IpAddress) -> bool;
        pub fn socketRecv(sock: *mut Socket, buffer: *mut Buffer) -> bool;
        pub fn socketSend(sock: *mut Socket, buffer: *mut Buffer) -> bool;
        pub fn socketClose(sock: *mut Socket) -> bool;
        pub fn socketSetOption(
            sock: *mut Socket, 
            option: Option, 
            value: *const std::ffi::c_void, 
            len: u32
        ) -> bool;
    }    
}
