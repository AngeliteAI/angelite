#[repr(C)]
pub struct Desc(u32);
#[derive(Debug, Clone, Copy)]
pub enum Domain {
    IPv4,
    IPv6,
    Unix,
}

#[derive(Debug, Clone, Copy)]
pub enum Type {
    Stream,
    Datagram,
}

pub enum Protocol {
    Tcp,
    Udp,
}

pub struct Address {
    pub domain: Domain,
    pub address: AddressData,
    pub port: u16,
}

#[repr(C)]
pub union AddressData {
    pub ipv4: [u8; 4],
    pub ipv6: [u8; 16],
    pub unix: [u8; 108],
}
