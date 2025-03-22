//! IO module

use libc::{c_int, c_void};
use crate::types::HandleType;

unsafe extern "C" {
    pub fn handle_type(handle: *mut c_void) -> HandleType;
    pub fn last_operation_id() -> u64;
}