use crate::Node;
use crate::error::Failure;
use crate::raft;

pub mod quic;
pub type PacketHeader = raft::Header;
pub trait Interface {
    fn new() -> Self;
    fn send(&self, data: &[u8], to: Node) -> Result<(), Failure>;
    fn recv(&self, buffer: &mut [u8], from: Node) -> Result<usize, Failure>;
}
