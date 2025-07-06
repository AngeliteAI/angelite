use std::os::raw::{c_char, c_int};
use std::ffi::CString;

#[allow(non_camel_case_types)]
#[repr(C)]
pub struct ___tracy_source_location_data {
    pub name: *const c_char,
    pub function: *const c_char,
    pub file: *const c_char,
    pub line: u32,
    pub color: u32,
}

#[allow(non_camel_case_types)]
#[repr(C)]
pub struct ___tracy_c_zone_context {
    pub id: u32,
    pub active: c_int,
}

#[allow(non_camel_case_types)]
#[repr(C)]
pub struct ___tracy_gpu_zone_context {
    pub ctx: *mut std::ffi::c_void,
    pub id: u16,
}

#[link(name = "tracy-client")]
extern "C" {
    pub fn ___tracy_emit_zone_begin(
        srcloc: *const ___tracy_source_location_data,
        active: c_int,
    ) -> ___tracy_c_zone_context;
    
    pub fn ___tracy_emit_zone_end(ctx: ___tracy_c_zone_context);
    
    pub fn ___tracy_emit_zone_text(
        ctx: ___tracy_c_zone_context,
        txt: *const c_char,
        size: usize,
    );
    
    pub fn ___tracy_emit_zone_name(
        ctx: ___tracy_c_zone_context,
        txt: *const c_char,
        size: usize,
    );
    
    pub fn ___tracy_emit_zone_color(ctx: ___tracy_c_zone_context, color: u32);
    
    pub fn ___tracy_emit_zone_value(ctx: ___tracy_c_zone_context, value: u64);
    
    pub fn ___tracy_emit_memory_alloc(ptr: *const std::ffi::c_void, size: usize, secure: c_int);
    
    pub fn ___tracy_emit_memory_alloc_named(
        ptr: *const std::ffi::c_void,
        size: usize,
        secure: c_int,
        name: *const c_char,
        namelen: usize,
    );
    
    pub fn ___tracy_emit_memory_free(ptr: *const std::ffi::c_void, secure: c_int);
    
    pub fn ___tracy_emit_memory_free_named(
        ptr: *const std::ffi::c_void,
        secure: c_int,
        name: *const c_char,
        namelen: usize,
    );
    
    pub fn ___tracy_emit_frame_mark(name: *const c_char);
    
    pub fn ___tracy_emit_plot(name: *const c_char, val: f64);
    
    pub fn ___tracy_emit_plot_float(name: *const c_char, val: f32);
    
    pub fn ___tracy_emit_message(txt: *const c_char, size: usize, callstack: c_int);
    
    pub fn ___tracy_emit_messageC(
        txt: *const c_char,
        size: usize,
        color: u32,
        callstack: c_int,
    );
    
    pub fn ___tracy_emit_thread_name(name: *const c_char, size: usize);
    
    pub fn ___tracy_emit_app_info(txt: *const c_char, size: usize);
}

// Rust wrapper API
pub struct Zone {
    ctx: ___tracy_c_zone_context,
}

impl Zone {
    pub fn new(name: &'static str, function: &'static str, file: &'static str, line: u32, color: u32) -> Self {
        let name_c = CString::new(name).unwrap();
        let function_c = CString::new(function).unwrap();
        let file_c = CString::new(file).unwrap();
        
        let srcloc = ___tracy_source_location_data {
            name: name_c.as_ptr(),
            function: function_c.as_ptr(),
            file: file_c.as_ptr(),
            line,
            color,
        };
        
        // Leak the CStrings to ensure they live for the duration of the program
        std::mem::forget(name_c);
        std::mem::forget(function_c);
        std::mem::forget(file_c);
        
        let ctx = unsafe { ___tracy_emit_zone_begin(&srcloc, 1) };
        
        Zone { ctx }
    }
    
    pub fn text(&self, txt: &str) {
        unsafe {
            ___tracy_emit_zone_text(self.ctx, txt.as_ptr() as *const c_char, txt.len());
        }
    }
    
    pub fn name(&self, name: &str) {
        unsafe {
            ___tracy_emit_zone_name(self.ctx, name.as_ptr() as *const c_char, name.len());
        }
    }
    
    pub fn color(&self, color: u32) {
        unsafe {
            ___tracy_emit_zone_color(self.ctx, color);
        }
    }
    
    pub fn value(&self, value: u64) {
        unsafe {
            ___tracy_emit_zone_value(self.ctx, value);
        }
    }
}

impl Drop for Zone {
    fn drop(&mut self) {
        unsafe {
            ___tracy_emit_zone_end(self.ctx);
        }
    }
}

// Convenience macros
#[macro_export]
macro_rules! tracy_zone {
    () => {
        $crate::tracy_ffi::Zone::new(
            "",
            module_path!(),
            file!(),
            line!(),
            0,
        )
    };
    ($name:expr) => {
        $crate::tracy_ffi::Zone::new(
            $name,
            module_path!(),
            file!(),
            line!(),
            0,
        )
    };
    ($name:expr, $color:expr) => {
        $crate::tracy_ffi::Zone::new(
            $name,
            module_path!(),
            file!(),
            line!(),
            $color,
        )
    };
}

pub fn frame_mark() {
    unsafe {
        ___tracy_emit_frame_mark(std::ptr::null());
    }
}

pub fn frame_mark_named(name: &str) {
    let name_c = CString::new(name).unwrap();
    unsafe {
        ___tracy_emit_frame_mark(name_c.as_ptr());
    }
}

pub fn plot(name: &str, val: f64) {
    let name_c = CString::new(name).unwrap();
    unsafe {
        ___tracy_emit_plot(name_c.as_ptr(), val);
    }
}

pub fn plot_f32(name: &str, val: f32) {
    let name_c = CString::new(name).unwrap();
    unsafe {
        ___tracy_emit_plot_float(name_c.as_ptr(), val);
    }
}

pub fn message(txt: &str) {
    unsafe {
        ___tracy_emit_message(txt.as_ptr() as *const c_char, txt.len(), 0);
    }
}

pub fn message_color(txt: &str, color: u32) {
    unsafe {
        ___tracy_emit_messageC(txt.as_ptr() as *const c_char, txt.len(), color, 0);
    }
}

pub fn thread_name(name: &str) {
    unsafe {
        ___tracy_emit_thread_name(name.as_ptr() as *const c_char, name.len());
    }
}

pub fn app_info(info: &str) {
    unsafe {
        ___tracy_emit_app_info(info.as_ptr() as *const c_char, info.len());
    }
}

// Memory tracking
pub fn alloc(ptr: *const std::ffi::c_void, size: usize) {
    unsafe {
        ___tracy_emit_memory_alloc(ptr, size, 0);
    }
}

pub fn alloc_named(ptr: *const std::ffi::c_void, size: usize, name: &str) {
    unsafe {
        ___tracy_emit_memory_alloc_named(
            ptr,
            size,
            0,
            name.as_ptr() as *const c_char,
            name.len(),
        );
    }
}

pub fn free(ptr: *const std::ffi::c_void) {
    unsafe {
        ___tracy_emit_memory_free(ptr, 0);
    }
}

pub fn free_named(ptr: *const std::ffi::c_void, name: &str) {
    unsafe {
        ___tracy_emit_memory_free_named(ptr, 0, name.as_ptr() as *const c_char, name.len());
    }
}

// Colors
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
    pub const FUCHSIA: u32 = 0xFF00FF;
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