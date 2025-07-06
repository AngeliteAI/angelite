/// Convenience macros for Tracy profiling

/// Profile a function automatically
#[macro_export]
macro_rules! profile {
    () => {
        let _zone = $crate::debug::DEBUG.zone_begin(
            &format!("{}::{}", module_path!(), {
                fn f() {}
                fn type_name_of<T>(_: T) -> &'static str {
                    std::any::type_name::<T>()
                }
                let name = type_name_of(f);
                &name[..name.len() - 3]
            })
        );
    };
    ($name:expr) => {
        let _zone = $crate::debug::DEBUG.zone_begin($name);
    };
}

/// Profile a block of code
#[macro_export]
macro_rules! profile_scope {
    ($name:expr, $code:block) => {{
        let _zone = $crate::debug::DEBUG.zone_begin($name);
        $code
    }};
}

/// Mark a frame boundary
#[macro_export]
macro_rules! frame_mark {
    () => {
        $crate::debug::DEBUG.frame_mark();
    };
    ($name:expr) => {
        $crate::debug::DEBUG.frame_mark_named($name);
    };
}

/// Plot a value
#[macro_export]
macro_rules! plot {
    ($name:expr, $value:expr) => {
        $crate::debug::DEBUG.plot($name, $value as f64);
    };
}

/// Log messages with color
#[macro_export]
macro_rules! tracy_info {
    ($msg:expr) => {
        $crate::debug::DEBUG.message_color($msg, $crate::debug::colors::GREEN);
    };
}

#[macro_export]
macro_rules! tracy_warn {
    ($msg:expr) => {
        $crate::debug::DEBUG.message_color($msg, $crate::debug::colors::YELLOW);
    };
}

#[macro_export]
macro_rules! tracy_error {
    ($msg:expr) => {
        $crate::debug::DEBUG.message_color($msg, $crate::debug::colors::RED);
    };
}

/// Memory tracking macros
#[macro_export]
macro_rules! tracy_alloc {
    ($ptr:expr, $size:expr, $name:expr) => {
        $crate::debug::DEBUG.alloc($ptr as *const std::ffi::c_void, $size, $name);
    };
}

#[macro_export]
macro_rules! tracy_free {
    ($ptr:expr, $name:expr) => {
        $crate::debug::DEBUG.free($ptr as *const std::ffi::c_void, $name);
    };
}