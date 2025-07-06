use std::net::IpAddr;
use crate::Node;
use serde::{Deserialize, Serialize};

use crate::raft::*;
#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Failure {
    #[error("Storage failure")]
    Storage(Storage),
    #[error("Network failure")]
    Network(Network),
    #[error("Log corruption")]
    Corrupt(Corrupt),
    #[error("Resource exhaustion")]
    Resource(Resource),
    #[error("Configuration error")]
    Config(BadConfig),
    #[error("Serialization error")]
    Serde(Serde),
    #[error("System error")]
    System(System),
}
#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Storage {
    #[error("Failed to read from storage at '{path}'")]
    Read { path: String },
    #[error("Failed to write to storage at '{path}'")]
    Write { path: String },
    #[error("Failed to flush storage buffers")]
    Flush,
    #[error("Failed to synchronize storage to disk")]
    Sync,
    #[error("Failed to acquire storage lock")]
    Lock,
    #[error("Storage item not found")]
    NotFound,
    #[error("Permission denied when accessing storage")]
    PermissionDenied,
    #[error("Storage data corrupted at offset {offset}")]
    Corrupted { offset: u64 },
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Network {
    #[error("Failed to connect to {addr}")]
    Connect { addr: IpAddr },
    #[error("Network resource not found")]
    NotFound,
    #[error("Failed to accept connection from {addr}")]
    Accept { addr: IpAddr },
    #[error("Permission denied for network operation")]
    PermissionDenied,
    #[error("Network operation was aborted")]
    Aborted,
    #[error("Failed to bind to address {addr}")]
    Bind { addr: IpAddr },
    #[error("Failed to send data to node {to:?}")]
    Send { to: Node },
    #[error("Failed to receive data from node {from:?}")]
    Recv { from: Node },
    #[error("Network operation timed out after {ms}ms")]
    Timeout { ms: u64 },
    #[error("Operation would block")]
    WouldBlock,
    #[error("Operation interrupted")]
    Interrupted,
    #[error("Address already in use")]
    AlreadyExists,
    #[error("Invalid input for network operation")]
    InvalidInput,
    #[error("Unexpected end of file during network operation")]
    UnexpectedEof,
    #[error("Not connected to remote host")]
    NotConnected,
    #[error("Connection refused by remote host")]
    Refused,
    #[error("Connection reset by peer")]
    Reset,
    #[error("Network destination unreachable")]
    Unreachable,
    #[error("Network operation failed for unknown reason")]
    Other,
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Corrupt {
    #[error("Log corruption detected at index {index}")]
    Log { index: u64 },
    #[error("Snapshot {id:?} is corrupted")]
    Snapshot { id: Snapshot },
    #[error("Checksum mismatch: expected {expected}, found {actual}")]
    Checksum { expected: u64, actual: u64 },
    #[error("Invalid data format")]
    Format,
    #[error("Version mismatch: expected {expected}, found {found}")]
    Version { expected: u32, found: u32 },
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Resource {
    #[error("Insufficient memory")]
    Memory,
    #[error("Insufficient disk space: {available} available, {needed} needed")]
    Disk { available: u64, needed: u64 },
    #[error("Too many open file handles")]
    Handles,
    #[error("Thread resource limit reached")]
    Threads,
    #[error("Queue overflow (size: {size})")]
    Queue { size: usize },
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum BadConfig {
    #[error("No nodes specified in configuration")]
    NoNodes,
    #[error("Duplicate node in configuration: {node:?}")]
    DuplicateNode { node: Node },
    #[error("Invalid timeout value: {ms}ms")]
    InvalidTimeout { ms: u64 },
    #[error("Invalid batch size: {size}")]
    InvalidBatch { size: u64 },
    #[error("Invalid address: '{addr}'")]
    InvalidAddr { addr: String },
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum Serde {
    #[error("Failed to encode {type_name}")]
    Encode { type_name: String },
    #[error("Failed to decode {type_name}")]
    Decode { type_name: String },
    #[error("Size limit exceeded: limit {limit}, actual {actual}")]
    Size { limit: usize, actual: usize },
    #[error("Invalid format")]
    Format,
}

#[derive(Debug, Clone, Serialize, Deserialize, thiserror::Error)]
pub enum System {
    #[error("System clock error")]
    Clock,
    #[error("Random number generation error")]
    Random,
    #[error("Thread operation failed")]
    Thread,
    #[error("Received signal: {sig}")]
    Signal { sig: i32 },
    #[error("Panic occurred: {msg}")]
    Panic { msg: String },
}
