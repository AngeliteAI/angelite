use crate::{
    Node,
    error::{self, Failure, Network},
    interface::Interface,
};
use bimap::BiMap;

use std::{cell::RefCell, marker::PhantomData, net::{IpAddr, SocketAddr, UdpSocket}, };

pub struct Quic<T> {
    udp: Udp<T>,
}

impl<T> Interface for Quic<T> {
    fn new() -> Self {
        Self {
            udp: Udp::new(),
        }
    }

    fn send(&self, data: &[u8], to: Node) -> Result<(), Failure> {
        self.udp.send(data, to)
    }

    fn recv(&self, buffer: &mut [u8], from: Node) -> Result<usize, Failure> {
        self.udp.recv(buffer, from)
    }
}

pub fn conv_io_sys_err_to_failure(e: std::io::Error) -> Network {
    match e.kind() {
        std::io::ErrorKind::NotFound => Network::NotFound,
        std::io::ErrorKind::PermissionDenied => Network::PermissionDenied,
        std::io::ErrorKind::ConnectionRefused => Network::Connect {
            addr: "unknown".parse().unwrap(),
        },
        std::io::ErrorKind::ConnectionReset => Network::Reset,
        std::io::ErrorKind::ConnectionAborted => Network::Aborted,
        std::io::ErrorKind::NotConnected => Network::NotConnected,
        std::io::ErrorKind::AddrInUse => Network::AlreadyExists,
        std::io::ErrorKind::AddrNotAvailable => Network::Unreachable,
        _ => Network::Other,
    }
}
pub struct Udp<T> {
    socket: UdpSocket,
    unit: PhantomData<T>,
    mapping: RefCell<BiMap<Node, (IpAddr, u16)>>,
}

impl<T> Interface for Udp<T> {
    fn send(&self, data: &[u8], to: Node) -> Result<(), Failure> {
        let mapping = self.mapping.borrow();
        // Check if the mapping exists for the given Node
        let Some(addr) = mapping.get_by_left(&to) else {
            return Err(Failure::Network(Network::Send { to }));
        }; 
        self.socket
            .send_to(data, SocketAddr::from(*addr))
            .map_err(conv_io_sys_err_to_failure)
            .map_err(Failure::Network)
            .map(|_| ())
    }

    fn recv(&self, buffer: &mut [u8], from: Node) -> Result<usize, Failure> {
        thread_local! {
            static STORED_DATA: RefCell<Vec<(Vec<u8>, SocketAddr)>> = RefCell::new(Vec::new());
        }

        // First, try to receive and store new data
        let mut temp_buffer = vec![0u8; buffer.len()];
        while let Ok((size, addr)) = self.socket.recv_from(&mut temp_buffer) {
            STORED_DATA.with(|stored| {
                stored.borrow_mut().push((temp_buffer[..size].to_vec(), addr));
            });
        }

        // Then, parse stored data for matching node and return maximum possible
        let target_addr = self.mapping.borrow().get_by_left(&from).copied();
        let Some(target_addr) = target_addr else {
            return Err(Failure::Network(Network::NotFound));
        };

        let total_copied = STORED_DATA.with(|stored| {
            let mut stored = stored.borrow_mut();
            let mut total_copied = 0;
            
            stored.retain(|(data, sender_addr)| {
                if *sender_addr == SocketAddr::from(target_addr) && total_copied + data.len() <= buffer.len() {
                    buffer[total_copied..total_copied + data.len()].copy_from_slice(data);
                    total_copied += data.len();
                    false // Remove from storage
                } else {
                    true // Keep in storage
                }
            });
            
            total_copied
        });
        
        Ok(total_copied)
    }

    fn new() -> Self {
        todo!()
    }
}
