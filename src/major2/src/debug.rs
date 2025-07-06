use std::ffi::CString;
use std::os::raw::{c_char, c_void};

/// Debug profiling trait for instrumenting code
pub trait Debug {
    /// Begin a profiling zone
    fn zone_begin(&self, name: &str) -> ZoneHandle;
    
    /// Mark a frame boundary
    fn frame_mark(&self);
    
    /// Mark a named frame boundary
    fn frame_mark_named(&self, name: &str);
    
    /// Plot a numeric value
    fn plot(&self, name: &str, value: f64);
    
    /// Log a message
    fn message(&self, text: &str);
    
    /// Log a colored message
    fn message_color(&self, text: &str, color: u32);
    
    /// Set thread name
    fn thread_name(&self, name: &str);
    
    /// Track memory allocation
    fn alloc(&self, ptr: *const c_void, size: usize, name: &str);
    
    /// Track memory deallocation
    fn free(&self, ptr: *const c_void, name: &str);
}

/// Handle for a profiling zone that ends when dropped
pub struct ZoneHandle {
    ctx: u64, // Opaque handle from Zig
}

impl Drop for ZoneHandle {
    fn drop(&mut self) {
        unsafe {
            tracy_zone_end(self.ctx);
        }
    }
}

/// Tracy implementation of the Debug trait
pub struct TracyDebug;

impl TracyDebug {
    pub fn is_connected(&self) -> bool {
        unsafe { tracy_is_connected() }
    }
    
    pub fn startup(&self) {
        unsafe { tracy_startup() }
    }
}

impl Debug for TracyDebug {
    fn zone_begin(&self, name: &str) -> ZoneHandle {
        let c_name = CString::new(name).unwrap();
        let ctx = unsafe {
            tracy_zone_begin(
                c_name.as_ptr(),
                std::module_path!().as_ptr() as *const c_char,
                file!().as_ptr() as *const c_char,
                line!(),
                0, // default color
            )
        };
        ZoneHandle { ctx }
    }
    
    fn frame_mark(&self) {
        unsafe {
            tracy_frame_mark();
        }
    }
    
    fn frame_mark_named(&self, name: &str) {
        let c_name = CString::new(name).unwrap();
        unsafe {
            tracy_frame_mark_named(c_name.as_ptr());
        }
    }
    
    fn plot(&self, name: &str, value: f64) {
        let c_name = CString::new(name).unwrap();
        unsafe {
            tracy_plot(c_name.as_ptr(), value);
        }
    }
    
    fn message(&self, text: &str) {
        unsafe {
            tracy_message(text.as_ptr() as *const c_char, text.len());
        }
    }
    
    fn message_color(&self, text: &str, color: u32) {
        unsafe {
            tracy_message_color(text.as_ptr() as *const c_char, text.len(), color);
        }
    }
    
    fn thread_name(&self, name: &str) {
        unsafe {
            tracy_thread_name(name.as_ptr() as *const c_char, name.len());
        }
    }
    
    fn alloc(&self, ptr: *const c_void, size: usize, name: &str) {
        unsafe {
            tracy_alloc(ptr, size, name.as_ptr() as *const c_char, name.len());
        }
    }
    
    fn free(&self, ptr: *const c_void, name: &str) {
        unsafe {
            tracy_free(ptr, name.as_ptr() as *const c_char, name.len());
        }
    }
}

/// Global debug instance
pub static DEBUG: TracyDebug = TracyDebug;

/// Convenience macro for creating zones
#[macro_export]
macro_rules! debug_zone {
    () => {
        let _zone = $crate::debug::DEBUG.zone_begin(module_path!());
    };
    ($name:expr) => {
        let _zone = $crate::debug::DEBUG.zone_begin($name);
    };
}

/// Convenience macro for function profiling
#[macro_export]
macro_rules! profile_fn {
    () => {
        let _zone = $crate::debug::DEBUG.zone_begin(
            &format!("{}::{}", module_path!(), std::any::type_name_of_val(&std::marker::PhantomData::<fn()>))
        );
    };
}

// FFI declarations for calling Zig functions
unsafe extern "C" {
    fn tracy_zone_begin(
        name: *const c_char,
        function: *const c_char,
        file: *const c_char,
        line: u32,
        color: u32,
    ) -> u64;
    
    fn tracy_zone_end(ctx: u64);
    
    fn tracy_frame_mark();
    
    fn tracy_frame_mark_named(name: *const c_char);
    
    fn tracy_plot(name: *const c_char, value: f64);
    
    fn tracy_message(text: *const c_char, len: usize);
    
    fn tracy_message_color(text: *const c_char, len: usize, color: u32);
    
    fn tracy_thread_name(name: *const c_char, len: usize);
    
    fn tracy_alloc(ptr: *const c_void, size: usize, name: *const c_char, name_len: usize);
    
    fn tracy_free(ptr: *const c_void, name: *const c_char, name_len: usize);
    
    fn tracy_is_connected() -> bool;
    
    pub fn tracy_startup();
}

/// Colors for debug zones
pub mod colors {
    pub const DEFAULT: u32 = 0x000000;
    pub const AQUA: u32 = 0x00FFFF;
    pub const BLUE: u32 = 0x0000FF;
    pub const BROWN: u32 = 0xA52A2A;
    pub const CRIMSON: u32 = 0xDC143C;
    pub const DARK_BLUE: u32 = 0x00008B;
    pub const DARK_GREEN: u32 = 0x006400;
    pub const DARK_RED: u32 = 0x8B0000;
    pub const FOREST_GREEN: u32 = 0x228B22;
    pub const GOLD: u32 = 0xFFD700;
    pub const GRAY: u32 = 0x808080;
    pub const GREEN: u32 = 0x008000;
    pub const GREEN_YELLOW: u32 = 0xADFF2F;
    pub const LIME: u32 = 0x00FF00;
    pub const MAGENTA: u32 = 0xFF00FF;
    pub const MAROON: u32 = 0x800000;
    pub const NAVY: u32 = 0x000080;
    pub const OLIVE: u32 = 0x808000;
    pub const ORANGE: u32 = 0xFFA500;
    pub const ORANGE_RED: u32 = 0xFF4500;
    pub const ORCHID: u32 = 0xDA70D6;
    pub const PINK: u32 = 0xFFC0CB;
    pub const PURPLE: u32 = 0x800080;
    pub const RED: u32 = 0xFF0000;
    pub const ROYAL_BLUE: u32 = 0x4169E1;
    pub const SILVER: u32 = 0xC0C0C0;
    pub const SKY_BLUE: u32 = 0x87CEEB;
    pub const SLATE_BLUE: u32 = 0x6A5ACD;
    pub const STEEL_BLUE: u32 = 0x4682B4;
    pub const TEAL: u32 = 0x008080;
    pub const TOMATO: u32 = 0xFF6347;
    pub const TURQUOISE: u32 = 0x40E0D0;
    pub const VIOLET: u32 = 0xEE82EE;
    pub const YELLOW: u32 = 0xFFFF00;
    pub const YELLOW_GREEN: u32 = 0x9ACD32;
}