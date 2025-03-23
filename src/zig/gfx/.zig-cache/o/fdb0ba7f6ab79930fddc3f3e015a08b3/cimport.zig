pub const __builtin_bswap16 = @import("std").zig.c_builtins.__builtin_bswap16;
pub const __builtin_bswap32 = @import("std").zig.c_builtins.__builtin_bswap32;
pub const __builtin_bswap64 = @import("std").zig.c_builtins.__builtin_bswap64;
pub const __builtin_signbit = @import("std").zig.c_builtins.__builtin_signbit;
pub const __builtin_signbitf = @import("std").zig.c_builtins.__builtin_signbitf;
pub const __builtin_popcount = @import("std").zig.c_builtins.__builtin_popcount;
pub const __builtin_ctz = @import("std").zig.c_builtins.__builtin_ctz;
pub const __builtin_clz = @import("std").zig.c_builtins.__builtin_clz;
pub const __builtin_sqrt = @import("std").zig.c_builtins.__builtin_sqrt;
pub const __builtin_sqrtf = @import("std").zig.c_builtins.__builtin_sqrtf;
pub const __builtin_sin = @import("std").zig.c_builtins.__builtin_sin;
pub const __builtin_sinf = @import("std").zig.c_builtins.__builtin_sinf;
pub const __builtin_cos = @import("std").zig.c_builtins.__builtin_cos;
pub const __builtin_cosf = @import("std").zig.c_builtins.__builtin_cosf;
pub const __builtin_exp = @import("std").zig.c_builtins.__builtin_exp;
pub const __builtin_expf = @import("std").zig.c_builtins.__builtin_expf;
pub const __builtin_exp2 = @import("std").zig.c_builtins.__builtin_exp2;
pub const __builtin_exp2f = @import("std").zig.c_builtins.__builtin_exp2f;
pub const __builtin_log = @import("std").zig.c_builtins.__builtin_log;
pub const __builtin_logf = @import("std").zig.c_builtins.__builtin_logf;
pub const __builtin_log2 = @import("std").zig.c_builtins.__builtin_log2;
pub const __builtin_log2f = @import("std").zig.c_builtins.__builtin_log2f;
pub const __builtin_log10 = @import("std").zig.c_builtins.__builtin_log10;
pub const __builtin_log10f = @import("std").zig.c_builtins.__builtin_log10f;
pub const __builtin_abs = @import("std").zig.c_builtins.__builtin_abs;
pub const __builtin_labs = @import("std").zig.c_builtins.__builtin_labs;
pub const __builtin_llabs = @import("std").zig.c_builtins.__builtin_llabs;
pub const __builtin_fabs = @import("std").zig.c_builtins.__builtin_fabs;
pub const __builtin_fabsf = @import("std").zig.c_builtins.__builtin_fabsf;
pub const __builtin_floor = @import("std").zig.c_builtins.__builtin_floor;
pub const __builtin_floorf = @import("std").zig.c_builtins.__builtin_floorf;
pub const __builtin_ceil = @import("std").zig.c_builtins.__builtin_ceil;
pub const __builtin_ceilf = @import("std").zig.c_builtins.__builtin_ceilf;
pub const __builtin_trunc = @import("std").zig.c_builtins.__builtin_trunc;
pub const __builtin_truncf = @import("std").zig.c_builtins.__builtin_truncf;
pub const __builtin_round = @import("std").zig.c_builtins.__builtin_round;
pub const __builtin_roundf = @import("std").zig.c_builtins.__builtin_roundf;
pub const __builtin_strlen = @import("std").zig.c_builtins.__builtin_strlen;
pub const __builtin_strcmp = @import("std").zig.c_builtins.__builtin_strcmp;
pub const __builtin_object_size = @import("std").zig.c_builtins.__builtin_object_size;
pub const __builtin___memset_chk = @import("std").zig.c_builtins.__builtin___memset_chk;
pub const __builtin_memset = @import("std").zig.c_builtins.__builtin_memset;
pub const __builtin___memcpy_chk = @import("std").zig.c_builtins.__builtin___memcpy_chk;
pub const __builtin_memcpy = @import("std").zig.c_builtins.__builtin_memcpy;
pub const __builtin_expect = @import("std").zig.c_builtins.__builtin_expect;
pub const __builtin_nanf = @import("std").zig.c_builtins.__builtin_nanf;
pub const __builtin_huge_valf = @import("std").zig.c_builtins.__builtin_huge_valf;
pub const __builtin_inff = @import("std").zig.c_builtins.__builtin_inff;
pub const __builtin_isnan = @import("std").zig.c_builtins.__builtin_isnan;
pub const __builtin_isinf = @import("std").zig.c_builtins.__builtin_isinf;
pub const __builtin_isinf_sign = @import("std").zig.c_builtins.__builtin_isinf_sign;
pub const __has_builtin = @import("std").zig.c_builtins.__has_builtin;
pub const __builtin_assume = @import("std").zig.c_builtins.__builtin_assume;
pub const __builtin_unreachable = @import("std").zig.c_builtins.__builtin_unreachable;
pub const __builtin_constant_p = @import("std").zig.c_builtins.__builtin_constant_p;
pub const __builtin_mul_overflow = @import("std").zig.c_builtins.__builtin_mul_overflow;
pub const __u_char = u8;
pub const __u_short = c_ushort;
pub const __u_int = c_uint;
pub const __u_long = c_ulong;
pub const __int8_t = i8;
pub const __uint8_t = u8;
pub const __int16_t = c_short;
pub const __uint16_t = c_ushort;
pub const __int32_t = c_int;
pub const __uint32_t = c_uint;
pub const __int64_t = c_long;
pub const __uint64_t = c_ulong;
pub const __int_least8_t = __int8_t;
pub const __uint_least8_t = __uint8_t;
pub const __int_least16_t = __int16_t;
pub const __uint_least16_t = __uint16_t;
pub const __int_least32_t = __int32_t;
pub const __uint_least32_t = __uint32_t;
pub const __int_least64_t = __int64_t;
pub const __uint_least64_t = __uint64_t;
pub const __quad_t = c_long;
pub const __u_quad_t = c_ulong;
pub const __intmax_t = c_long;
pub const __uintmax_t = c_ulong;
pub const __dev_t = c_ulong;
pub const __uid_t = c_uint;
pub const __gid_t = c_uint;
pub const __ino_t = c_ulong;
pub const __ino64_t = c_ulong;
pub const __mode_t = c_uint;
pub const __nlink_t = c_ulong;
pub const __off_t = c_long;
pub const __off64_t = c_long;
pub const __pid_t = c_int;
pub const __fsid_t = extern struct {
    __val: [2]c_int = @import("std").mem.zeroes([2]c_int),
};
pub const __clock_t = c_long;
pub const __rlim_t = c_ulong;
pub const __rlim64_t = c_ulong;
pub const __id_t = c_uint;
pub const __time_t = c_long;
pub const __useconds_t = c_uint;
pub const __suseconds_t = c_long;
pub const __suseconds64_t = c_long;
pub const __daddr_t = c_int;
pub const __key_t = c_int;
pub const __clockid_t = c_int;
pub const __timer_t = ?*anyopaque;
pub const __blksize_t = c_long;
pub const __blkcnt_t = c_long;
pub const __blkcnt64_t = c_long;
pub const __fsblkcnt_t = c_ulong;
pub const __fsblkcnt64_t = c_ulong;
pub const __fsfilcnt_t = c_ulong;
pub const __fsfilcnt64_t = c_ulong;
pub const __fsword_t = c_long;
pub const __ssize_t = c_long;
pub const __syscall_slong_t = c_long;
pub const __syscall_ulong_t = c_ulong;
pub const __loff_t = __off64_t;
pub const __caddr_t = [*c]u8;
pub const __intptr_t = c_long;
pub const __socklen_t = c_uint;
pub const __sig_atomic_t = c_int;
pub const u_char = __u_char;
pub const u_short = __u_short;
pub const u_int = __u_int;
pub const u_long = __u_long;
pub const quad_t = __quad_t;
pub const u_quad_t = __u_quad_t;
pub const fsid_t = __fsid_t;
pub const loff_t = __loff_t;
pub const ino_t = __ino_t;
pub const dev_t = __dev_t;
pub const gid_t = __gid_t;
pub const mode_t = __mode_t;
pub const nlink_t = __nlink_t;
pub const uid_t = __uid_t;
pub const off_t = __off_t;
pub const pid_t = __pid_t;
pub const id_t = __id_t;
pub const daddr_t = __daddr_t;
pub const caddr_t = __caddr_t;
pub const key_t = __key_t;
pub const clock_t = __clock_t;
pub const clockid_t = __clockid_t;
pub const time_t = __time_t;
pub const timer_t = __timer_t;
pub const ulong = c_ulong;
pub const ushort = c_ushort;
pub const uint = c_uint;
pub const u_int8_t = __uint8_t;
pub const u_int16_t = __uint16_t;
pub const u_int32_t = __uint32_t;
pub const u_int64_t = __uint64_t;
pub const register_t = c_long;
pub fn __bswap_16(arg___bsx: __uint16_t) callconv(.c) __uint16_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @as(__uint16_t, @bitCast(@as(c_short, @truncate(((@as(c_int, @bitCast(@as(c_uint, __bsx))) >> @intCast(8)) & @as(c_int, 255)) | ((@as(c_int, @bitCast(@as(c_uint, __bsx))) & @as(c_int, 255)) << @intCast(8))))));
}
pub fn __bswap_32(arg___bsx: __uint32_t) callconv(.c) __uint32_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return ((((__bsx & @as(c_uint, 4278190080)) >> @intCast(24)) | ((__bsx & @as(c_uint, 16711680)) >> @intCast(8))) | ((__bsx & @as(c_uint, 65280)) << @intCast(8))) | ((__bsx & @as(c_uint, 255)) << @intCast(24));
}
pub fn __bswap_64(arg___bsx: __uint64_t) callconv(.c) __uint64_t {
    var __bsx = arg___bsx;
    _ = &__bsx;
    return @as(__uint64_t, @bitCast(@as(c_ulong, @truncate(((((((((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 18374686479671623680)) >> @intCast(56)) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 71776119061217280)) >> @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 280375465082880)) >> @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 1095216660480)) >> @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 4278190080)) << @intCast(8))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 16711680)) << @intCast(24))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 65280)) << @intCast(40))) | ((@as(c_ulonglong, @bitCast(@as(c_ulonglong, __bsx))) & @as(c_ulonglong, 255)) << @intCast(56))))));
}
pub fn __uint16_identity(arg___x: __uint16_t) callconv(.c) __uint16_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint32_identity(arg___x: __uint32_t) callconv(.c) __uint32_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub fn __uint64_identity(arg___x: __uint64_t) callconv(.c) __uint64_t {
    var __x = arg___x;
    _ = &__x;
    return __x;
}
pub const __sigset_t = extern struct {
    __val: [16]c_ulong = @import("std").mem.zeroes([16]c_ulong),
};
pub const sigset_t = __sigset_t;
pub const struct_timeval = extern struct {
    tv_sec: __time_t = @import("std").mem.zeroes(__time_t),
    tv_usec: __suseconds_t = @import("std").mem.zeroes(__suseconds_t),
};
pub const struct_timespec = extern struct {
    tv_sec: __time_t = @import("std").mem.zeroes(__time_t),
    tv_nsec: __syscall_slong_t = @import("std").mem.zeroes(__syscall_slong_t),
};
pub const suseconds_t = __suseconds_t;
pub const __fd_mask = c_long;
pub const fd_set = extern struct {
    __fds_bits: [16]__fd_mask = @import("std").mem.zeroes([16]__fd_mask),
};
pub const fd_mask = __fd_mask;
pub extern fn select(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]struct_timeval) c_int;
pub extern fn pselect(__nfds: c_int, noalias __readfds: [*c]fd_set, noalias __writefds: [*c]fd_set, noalias __exceptfds: [*c]fd_set, noalias __timeout: [*c]const struct_timespec, noalias __sigmask: [*c]const __sigset_t) c_int;
pub const blksize_t = __blksize_t;
pub const blkcnt_t = __blkcnt_t;
pub const fsblkcnt_t = __fsblkcnt_t;
pub const fsfilcnt_t = __fsfilcnt_t;
const struct_unnamed_1 = extern struct {
    __low: c_uint = @import("std").mem.zeroes(c_uint),
    __high: c_uint = @import("std").mem.zeroes(c_uint),
};
pub const __atomic_wide_counter = extern union {
    __value64: c_ulonglong,
    __value32: struct_unnamed_1,
};
pub const struct___pthread_internal_list = extern struct {
    __prev: [*c]struct___pthread_internal_list = @import("std").mem.zeroes([*c]struct___pthread_internal_list),
    __next: [*c]struct___pthread_internal_list = @import("std").mem.zeroes([*c]struct___pthread_internal_list),
};
pub const __pthread_list_t = struct___pthread_internal_list;
pub const struct___pthread_internal_slist = extern struct {
    __next: [*c]struct___pthread_internal_slist = @import("std").mem.zeroes([*c]struct___pthread_internal_slist),
};
pub const __pthread_slist_t = struct___pthread_internal_slist;
pub const struct___pthread_mutex_s = extern struct {
    __lock: c_int = @import("std").mem.zeroes(c_int),
    __count: c_uint = @import("std").mem.zeroes(c_uint),
    __owner: c_int = @import("std").mem.zeroes(c_int),
    __nusers: c_uint = @import("std").mem.zeroes(c_uint),
    __kind: c_int = @import("std").mem.zeroes(c_int),
    __spins: c_short = @import("std").mem.zeroes(c_short),
    __elision: c_short = @import("std").mem.zeroes(c_short),
    __list: __pthread_list_t = @import("std").mem.zeroes(__pthread_list_t),
};
pub const struct___pthread_rwlock_arch_t = extern struct {
    __readers: c_uint = @import("std").mem.zeroes(c_uint),
    __writers: c_uint = @import("std").mem.zeroes(c_uint),
    __wrphase_futex: c_uint = @import("std").mem.zeroes(c_uint),
    __writers_futex: c_uint = @import("std").mem.zeroes(c_uint),
    __pad3: c_uint = @import("std").mem.zeroes(c_uint),
    __pad4: c_uint = @import("std").mem.zeroes(c_uint),
    __cur_writer: c_int = @import("std").mem.zeroes(c_int),
    __shared: c_int = @import("std").mem.zeroes(c_int),
    __rwelision: i8 = @import("std").mem.zeroes(i8),
    __pad1: [7]u8 = @import("std").mem.zeroes([7]u8),
    __pad2: c_ulong = @import("std").mem.zeroes(c_ulong),
    __flags: c_uint = @import("std").mem.zeroes(c_uint),
};
pub const struct___pthread_cond_s = extern struct {
    __wseq: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g1_start: __atomic_wide_counter = @import("std").mem.zeroes(__atomic_wide_counter),
    __g_refs: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g_size: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
    __g1_orig_size: c_uint = @import("std").mem.zeroes(c_uint),
    __wrefs: c_uint = @import("std").mem.zeroes(c_uint),
    __g_signals: [2]c_uint = @import("std").mem.zeroes([2]c_uint),
};
pub const __tss_t = c_uint;
pub const __thrd_t = c_ulong;
pub const __once_flag = extern struct {
    __data: c_int = @import("std").mem.zeroes(c_int),
};
pub const pthread_t = c_ulong;
pub const pthread_mutexattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_condattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const pthread_key_t = c_uint;
pub const pthread_once_t = c_int;
pub const union_pthread_attr_t = extern union {
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_attr_t = union_pthread_attr_t;
pub const pthread_mutex_t = extern union {
    __data: struct___pthread_mutex_s,
    __size: [40]u8,
    __align: c_long,
};
pub const pthread_cond_t = extern union {
    __data: struct___pthread_cond_s,
    __size: [48]u8,
    __align: c_longlong,
};
pub const pthread_rwlock_t = extern union {
    __data: struct___pthread_rwlock_arch_t,
    __size: [56]u8,
    __align: c_long,
};
pub const pthread_rwlockattr_t = extern union {
    __size: [8]u8,
    __align: c_long,
};
pub const pthread_spinlock_t = c_int;
pub const pthread_barrier_t = extern union {
    __size: [32]u8,
    __align: c_long,
};
pub const pthread_barrierattr_t = extern union {
    __size: [4]u8,
    __align: c_int,
};
pub const XID = c_ulong;
pub const Mask = c_ulong;
pub const Atom = c_ulong;
pub const VisualID = c_ulong;
pub const Time = c_ulong;
pub const Window = XID;
pub const Drawable = XID;
pub const Font = XID;
pub const Pixmap = XID;
pub const Cursor = XID;
pub const Colormap = XID;
pub const GContext = XID;
pub const KeySym = XID;
pub const KeyCode = u8;
pub const ptrdiff_t = c_long;
pub const wchar_t = c_int;
pub const max_align_t = extern struct {
    __clang_max_align_nonce1: c_longlong align(8) = @import("std").mem.zeroes(c_longlong),
    __clang_max_align_nonce2: c_longdouble align(16) = @import("std").mem.zeroes(c_longdouble),
};
pub extern fn _Xmblen(str: [*c]u8, len: c_int) c_int;
pub const XPointer = [*c]u8;
pub const struct__XExtData = extern struct {
    number: c_int = @import("std").mem.zeroes(c_int),
    next: [*c]struct__XExtData = @import("std").mem.zeroes([*c]struct__XExtData),
    free_private: ?*const fn ([*c]struct__XExtData) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn ([*c]struct__XExtData) callconv(.c) c_int),
    private_data: XPointer = @import("std").mem.zeroes(XPointer),
};
pub const XExtData = struct__XExtData;
pub const XExtCodes = extern struct {
    extension: c_int = @import("std").mem.zeroes(c_int),
    major_opcode: c_int = @import("std").mem.zeroes(c_int),
    first_event: c_int = @import("std").mem.zeroes(c_int),
    first_error: c_int = @import("std").mem.zeroes(c_int),
};
pub const XPixmapFormatValues = extern struct {
    depth: c_int = @import("std").mem.zeroes(c_int),
    bits_per_pixel: c_int = @import("std").mem.zeroes(c_int),
    scanline_pad: c_int = @import("std").mem.zeroes(c_int),
};
pub const XGCValues = extern struct {
    function: c_int = @import("std").mem.zeroes(c_int),
    plane_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    foreground: c_ulong = @import("std").mem.zeroes(c_ulong),
    background: c_ulong = @import("std").mem.zeroes(c_ulong),
    line_width: c_int = @import("std").mem.zeroes(c_int),
    line_style: c_int = @import("std").mem.zeroes(c_int),
    cap_style: c_int = @import("std").mem.zeroes(c_int),
    join_style: c_int = @import("std").mem.zeroes(c_int),
    fill_style: c_int = @import("std").mem.zeroes(c_int),
    fill_rule: c_int = @import("std").mem.zeroes(c_int),
    arc_mode: c_int = @import("std").mem.zeroes(c_int),
    tile: Pixmap = @import("std").mem.zeroes(Pixmap),
    stipple: Pixmap = @import("std").mem.zeroes(Pixmap),
    ts_x_origin: c_int = @import("std").mem.zeroes(c_int),
    ts_y_origin: c_int = @import("std").mem.zeroes(c_int),
    font: Font = @import("std").mem.zeroes(Font),
    subwindow_mode: c_int = @import("std").mem.zeroes(c_int),
    graphics_exposures: c_int = @import("std").mem.zeroes(c_int),
    clip_x_origin: c_int = @import("std").mem.zeroes(c_int),
    clip_y_origin: c_int = @import("std").mem.zeroes(c_int),
    clip_mask: Pixmap = @import("std").mem.zeroes(Pixmap),
    dash_offset: c_int = @import("std").mem.zeroes(c_int),
    dashes: u8 = @import("std").mem.zeroes(u8),
};
pub const struct__XGC = opaque {};
pub const GC = ?*struct__XGC;
pub const Visual = extern struct {
    ext_data: [*c]XExtData = @import("std").mem.zeroes([*c]XExtData),
    visualid: VisualID = @import("std").mem.zeroes(VisualID),
    class: c_int = @import("std").mem.zeroes(c_int),
    red_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    green_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    blue_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    bits_per_rgb: c_int = @import("std").mem.zeroes(c_int),
    map_entries: c_int = @import("std").mem.zeroes(c_int),
};
pub const Depth = extern struct {
    depth: c_int = @import("std").mem.zeroes(c_int),
    nvisuals: c_int = @import("std").mem.zeroes(c_int),
    visuals: [*c]Visual = @import("std").mem.zeroes([*c]Visual),
};
pub const struct__XDisplay = opaque {};
pub const Screen = extern struct {
    ext_data: [*c]XExtData = @import("std").mem.zeroes([*c]XExtData),
    display: ?*struct__XDisplay = @import("std").mem.zeroes(?*struct__XDisplay),
    root: Window = @import("std").mem.zeroes(Window),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    mwidth: c_int = @import("std").mem.zeroes(c_int),
    mheight: c_int = @import("std").mem.zeroes(c_int),
    ndepths: c_int = @import("std").mem.zeroes(c_int),
    depths: [*c]Depth = @import("std").mem.zeroes([*c]Depth),
    root_depth: c_int = @import("std").mem.zeroes(c_int),
    root_visual: [*c]Visual = @import("std").mem.zeroes([*c]Visual),
    default_gc: GC = @import("std").mem.zeroes(GC),
    cmap: Colormap = @import("std").mem.zeroes(Colormap),
    white_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    black_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    max_maps: c_int = @import("std").mem.zeroes(c_int),
    min_maps: c_int = @import("std").mem.zeroes(c_int),
    backing_store: c_int = @import("std").mem.zeroes(c_int),
    save_unders: c_int = @import("std").mem.zeroes(c_int),
    root_input_mask: c_long = @import("std").mem.zeroes(c_long),
};
pub const ScreenFormat = extern struct {
    ext_data: [*c]XExtData = @import("std").mem.zeroes([*c]XExtData),
    depth: c_int = @import("std").mem.zeroes(c_int),
    bits_per_pixel: c_int = @import("std").mem.zeroes(c_int),
    scanline_pad: c_int = @import("std").mem.zeroes(c_int),
};
pub const XSetWindowAttributes = extern struct {
    background_pixmap: Pixmap = @import("std").mem.zeroes(Pixmap),
    background_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    border_pixmap: Pixmap = @import("std").mem.zeroes(Pixmap),
    border_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    bit_gravity: c_int = @import("std").mem.zeroes(c_int),
    win_gravity: c_int = @import("std").mem.zeroes(c_int),
    backing_store: c_int = @import("std").mem.zeroes(c_int),
    backing_planes: c_ulong = @import("std").mem.zeroes(c_ulong),
    backing_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    save_under: c_int = @import("std").mem.zeroes(c_int),
    event_mask: c_long = @import("std").mem.zeroes(c_long),
    do_not_propagate_mask: c_long = @import("std").mem.zeroes(c_long),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
    colormap: Colormap = @import("std").mem.zeroes(Colormap),
    cursor: Cursor = @import("std").mem.zeroes(Cursor),
};
pub const XWindowAttributes = extern struct {
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    border_width: c_int = @import("std").mem.zeroes(c_int),
    depth: c_int = @import("std").mem.zeroes(c_int),
    visual: [*c]Visual = @import("std").mem.zeroes([*c]Visual),
    root: Window = @import("std").mem.zeroes(Window),
    class: c_int = @import("std").mem.zeroes(c_int),
    bit_gravity: c_int = @import("std").mem.zeroes(c_int),
    win_gravity: c_int = @import("std").mem.zeroes(c_int),
    backing_store: c_int = @import("std").mem.zeroes(c_int),
    backing_planes: c_ulong = @import("std").mem.zeroes(c_ulong),
    backing_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    save_under: c_int = @import("std").mem.zeroes(c_int),
    colormap: Colormap = @import("std").mem.zeroes(Colormap),
    map_installed: c_int = @import("std").mem.zeroes(c_int),
    map_state: c_int = @import("std").mem.zeroes(c_int),
    all_event_masks: c_long = @import("std").mem.zeroes(c_long),
    your_event_mask: c_long = @import("std").mem.zeroes(c_long),
    do_not_propagate_mask: c_long = @import("std").mem.zeroes(c_long),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
    screen: [*c]Screen = @import("std").mem.zeroes([*c]Screen),
};
pub const XHostAddress = extern struct {
    family: c_int = @import("std").mem.zeroes(c_int),
    length: c_int = @import("std").mem.zeroes(c_int),
    address: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub const XServerInterpretedAddress = extern struct {
    typelength: c_int = @import("std").mem.zeroes(c_int),
    valuelength: c_int = @import("std").mem.zeroes(c_int),
    type: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    value: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub const struct_funcs_2 = extern struct {
    create_image: ?*const fn (?*struct__XDisplay, [*c]Visual, c_uint, c_int, c_int, [*c]u8, c_uint, c_uint, c_int, c_int) callconv(.c) [*c]struct__XImage = @import("std").mem.zeroes(?*const fn (?*struct__XDisplay, [*c]Visual, c_uint, c_int, c_int, [*c]u8, c_uint, c_uint, c_int, c_int) callconv(.c) [*c]struct__XImage),
    destroy_image: ?*const fn ([*c]struct__XImage) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn ([*c]struct__XImage) callconv(.c) c_int),
    get_pixel: ?*const fn ([*c]struct__XImage, c_int, c_int) callconv(.c) c_ulong = @import("std").mem.zeroes(?*const fn ([*c]struct__XImage, c_int, c_int) callconv(.c) c_ulong),
    put_pixel: ?*const fn ([*c]struct__XImage, c_int, c_int, c_ulong) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn ([*c]struct__XImage, c_int, c_int, c_ulong) callconv(.c) c_int),
    sub_image: ?*const fn ([*c]struct__XImage, c_int, c_int, c_uint, c_uint) callconv(.c) [*c]struct__XImage = @import("std").mem.zeroes(?*const fn ([*c]struct__XImage, c_int, c_int, c_uint, c_uint) callconv(.c) [*c]struct__XImage),
    add_pixel: ?*const fn ([*c]struct__XImage, c_long) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn ([*c]struct__XImage, c_long) callconv(.c) c_int),
};
pub const struct__XImage = extern struct {
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    xoffset: c_int = @import("std").mem.zeroes(c_int),
    format: c_int = @import("std").mem.zeroes(c_int),
    data: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    byte_order: c_int = @import("std").mem.zeroes(c_int),
    bitmap_unit: c_int = @import("std").mem.zeroes(c_int),
    bitmap_bit_order: c_int = @import("std").mem.zeroes(c_int),
    bitmap_pad: c_int = @import("std").mem.zeroes(c_int),
    depth: c_int = @import("std").mem.zeroes(c_int),
    bytes_per_line: c_int = @import("std").mem.zeroes(c_int),
    bits_per_pixel: c_int = @import("std").mem.zeroes(c_int),
    red_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    green_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    blue_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    obdata: XPointer = @import("std").mem.zeroes(XPointer),
    f: struct_funcs_2 = @import("std").mem.zeroes(struct_funcs_2),
};
pub const XImage = struct__XImage;
pub const XWindowChanges = extern struct {
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    border_width: c_int = @import("std").mem.zeroes(c_int),
    sibling: Window = @import("std").mem.zeroes(Window),
    stack_mode: c_int = @import("std").mem.zeroes(c_int),
};
pub const XColor = extern struct {
    pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    red: c_ushort = @import("std").mem.zeroes(c_ushort),
    green: c_ushort = @import("std").mem.zeroes(c_ushort),
    blue: c_ushort = @import("std").mem.zeroes(c_ushort),
    flags: u8 = @import("std").mem.zeroes(u8),
    pad: u8 = @import("std").mem.zeroes(u8),
};
pub const XSegment = extern struct {
    x1: c_short = @import("std").mem.zeroes(c_short),
    y1: c_short = @import("std").mem.zeroes(c_short),
    x2: c_short = @import("std").mem.zeroes(c_short),
    y2: c_short = @import("std").mem.zeroes(c_short),
};
pub const XPoint = extern struct {
    x: c_short = @import("std").mem.zeroes(c_short),
    y: c_short = @import("std").mem.zeroes(c_short),
};
pub const XRectangle = extern struct {
    x: c_short = @import("std").mem.zeroes(c_short),
    y: c_short = @import("std").mem.zeroes(c_short),
    width: c_ushort = @import("std").mem.zeroes(c_ushort),
    height: c_ushort = @import("std").mem.zeroes(c_ushort),
};
pub const XArc = extern struct {
    x: c_short = @import("std").mem.zeroes(c_short),
    y: c_short = @import("std").mem.zeroes(c_short),
    width: c_ushort = @import("std").mem.zeroes(c_ushort),
    height: c_ushort = @import("std").mem.zeroes(c_ushort),
    angle1: c_short = @import("std").mem.zeroes(c_short),
    angle2: c_short = @import("std").mem.zeroes(c_short),
};
pub const XKeyboardControl = extern struct {
    key_click_percent: c_int = @import("std").mem.zeroes(c_int),
    bell_percent: c_int = @import("std").mem.zeroes(c_int),
    bell_pitch: c_int = @import("std").mem.zeroes(c_int),
    bell_duration: c_int = @import("std").mem.zeroes(c_int),
    led: c_int = @import("std").mem.zeroes(c_int),
    led_mode: c_int = @import("std").mem.zeroes(c_int),
    key: c_int = @import("std").mem.zeroes(c_int),
    auto_repeat_mode: c_int = @import("std").mem.zeroes(c_int),
};
pub const XKeyboardState = extern struct {
    key_click_percent: c_int = @import("std").mem.zeroes(c_int),
    bell_percent: c_int = @import("std").mem.zeroes(c_int),
    bell_pitch: c_uint = @import("std").mem.zeroes(c_uint),
    bell_duration: c_uint = @import("std").mem.zeroes(c_uint),
    led_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    global_auto_repeat: c_int = @import("std").mem.zeroes(c_int),
    auto_repeats: [32]u8 = @import("std").mem.zeroes([32]u8),
};
pub const XTimeCoord = extern struct {
    time: Time = @import("std").mem.zeroes(Time),
    x: c_short = @import("std").mem.zeroes(c_short),
    y: c_short = @import("std").mem.zeroes(c_short),
};
pub const XModifierKeymap = extern struct {
    max_keypermod: c_int = @import("std").mem.zeroes(c_int),
    modifiermap: [*c]KeyCode = @import("std").mem.zeroes([*c]KeyCode),
};
pub const Display = struct__XDisplay;
pub const struct__XPrivate = opaque {};
pub const struct__XrmHashBucketRec = opaque {};
const struct_unnamed_3 = extern struct {
    ext_data: [*c]XExtData = @import("std").mem.zeroes([*c]XExtData),
    private1: ?*struct__XPrivate = @import("std").mem.zeroes(?*struct__XPrivate),
    fd: c_int = @import("std").mem.zeroes(c_int),
    private2: c_int = @import("std").mem.zeroes(c_int),
    proto_major_version: c_int = @import("std").mem.zeroes(c_int),
    proto_minor_version: c_int = @import("std").mem.zeroes(c_int),
    vendor: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    private3: XID = @import("std").mem.zeroes(XID),
    private4: XID = @import("std").mem.zeroes(XID),
    private5: XID = @import("std").mem.zeroes(XID),
    private6: c_int = @import("std").mem.zeroes(c_int),
    resource_alloc: ?*const fn (?*struct__XDisplay) callconv(.c) XID = @import("std").mem.zeroes(?*const fn (?*struct__XDisplay) callconv(.c) XID),
    byte_order: c_int = @import("std").mem.zeroes(c_int),
    bitmap_unit: c_int = @import("std").mem.zeroes(c_int),
    bitmap_pad: c_int = @import("std").mem.zeroes(c_int),
    bitmap_bit_order: c_int = @import("std").mem.zeroes(c_int),
    nformats: c_int = @import("std").mem.zeroes(c_int),
    pixmap_format: [*c]ScreenFormat = @import("std").mem.zeroes([*c]ScreenFormat),
    private8: c_int = @import("std").mem.zeroes(c_int),
    release: c_int = @import("std").mem.zeroes(c_int),
    private9: ?*struct__XPrivate = @import("std").mem.zeroes(?*struct__XPrivate),
    private10: ?*struct__XPrivate = @import("std").mem.zeroes(?*struct__XPrivate),
    qlen: c_int = @import("std").mem.zeroes(c_int),
    last_request_read: c_ulong = @import("std").mem.zeroes(c_ulong),
    request: c_ulong = @import("std").mem.zeroes(c_ulong),
    private11: XPointer = @import("std").mem.zeroes(XPointer),
    private12: XPointer = @import("std").mem.zeroes(XPointer),
    private13: XPointer = @import("std").mem.zeroes(XPointer),
    private14: XPointer = @import("std").mem.zeroes(XPointer),
    max_request_size: c_uint = @import("std").mem.zeroes(c_uint),
    db: ?*struct__XrmHashBucketRec = @import("std").mem.zeroes(?*struct__XrmHashBucketRec),
    private15: ?*const fn (?*struct__XDisplay) callconv(.c) c_int = @import("std").mem.zeroes(?*const fn (?*struct__XDisplay) callconv(.c) c_int),
    display_name: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    default_screen: c_int = @import("std").mem.zeroes(c_int),
    nscreens: c_int = @import("std").mem.zeroes(c_int),
    screens: [*c]Screen = @import("std").mem.zeroes([*c]Screen),
    motion_buffer: c_ulong = @import("std").mem.zeroes(c_ulong),
    private16: c_ulong = @import("std").mem.zeroes(c_ulong),
    min_keycode: c_int = @import("std").mem.zeroes(c_int),
    max_keycode: c_int = @import("std").mem.zeroes(c_int),
    private17: XPointer = @import("std").mem.zeroes(XPointer),
    private18: XPointer = @import("std").mem.zeroes(XPointer),
    private19: c_int = @import("std").mem.zeroes(c_int),
    xdefaults: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub const _XPrivDisplay = [*c]struct_unnamed_3;
pub const XKeyEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    root: Window = @import("std").mem.zeroes(Window),
    subwindow: Window = @import("std").mem.zeroes(Window),
    time: Time = @import("std").mem.zeroes(Time),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    x_root: c_int = @import("std").mem.zeroes(c_int),
    y_root: c_int = @import("std").mem.zeroes(c_int),
    state: c_uint = @import("std").mem.zeroes(c_uint),
    keycode: c_uint = @import("std").mem.zeroes(c_uint),
    same_screen: c_int = @import("std").mem.zeroes(c_int),
};
pub const XKeyPressedEvent = XKeyEvent;
pub const XKeyReleasedEvent = XKeyEvent;
pub const XButtonEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    root: Window = @import("std").mem.zeroes(Window),
    subwindow: Window = @import("std").mem.zeroes(Window),
    time: Time = @import("std").mem.zeroes(Time),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    x_root: c_int = @import("std").mem.zeroes(c_int),
    y_root: c_int = @import("std").mem.zeroes(c_int),
    state: c_uint = @import("std").mem.zeroes(c_uint),
    button: c_uint = @import("std").mem.zeroes(c_uint),
    same_screen: c_int = @import("std").mem.zeroes(c_int),
};
pub const XButtonPressedEvent = XButtonEvent;
pub const XButtonReleasedEvent = XButtonEvent;
pub const XMotionEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    root: Window = @import("std").mem.zeroes(Window),
    subwindow: Window = @import("std").mem.zeroes(Window),
    time: Time = @import("std").mem.zeroes(Time),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    x_root: c_int = @import("std").mem.zeroes(c_int),
    y_root: c_int = @import("std").mem.zeroes(c_int),
    state: c_uint = @import("std").mem.zeroes(c_uint),
    is_hint: u8 = @import("std").mem.zeroes(u8),
    same_screen: c_int = @import("std").mem.zeroes(c_int),
};
pub const XPointerMovedEvent = XMotionEvent;
pub const XCrossingEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    root: Window = @import("std").mem.zeroes(Window),
    subwindow: Window = @import("std").mem.zeroes(Window),
    time: Time = @import("std").mem.zeroes(Time),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    x_root: c_int = @import("std").mem.zeroes(c_int),
    y_root: c_int = @import("std").mem.zeroes(c_int),
    mode: c_int = @import("std").mem.zeroes(c_int),
    detail: c_int = @import("std").mem.zeroes(c_int),
    same_screen: c_int = @import("std").mem.zeroes(c_int),
    focus: c_int = @import("std").mem.zeroes(c_int),
    state: c_uint = @import("std").mem.zeroes(c_uint),
};
pub const XEnterWindowEvent = XCrossingEvent;
pub const XLeaveWindowEvent = XCrossingEvent;
pub const XFocusChangeEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    mode: c_int = @import("std").mem.zeroes(c_int),
    detail: c_int = @import("std").mem.zeroes(c_int),
};
pub const XFocusInEvent = XFocusChangeEvent;
pub const XFocusOutEvent = XFocusChangeEvent;
pub const XKeymapEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    key_vector: [32]u8 = @import("std").mem.zeroes([32]u8),
};
pub const XExposeEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    count: c_int = @import("std").mem.zeroes(c_int),
};
pub const XGraphicsExposeEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    drawable: Drawable = @import("std").mem.zeroes(Drawable),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    count: c_int = @import("std").mem.zeroes(c_int),
    major_code: c_int = @import("std").mem.zeroes(c_int),
    minor_code: c_int = @import("std").mem.zeroes(c_int),
};
pub const XNoExposeEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    drawable: Drawable = @import("std").mem.zeroes(Drawable),
    major_code: c_int = @import("std").mem.zeroes(c_int),
    minor_code: c_int = @import("std").mem.zeroes(c_int),
};
pub const XVisibilityEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    state: c_int = @import("std").mem.zeroes(c_int),
};
pub const XCreateWindowEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    parent: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    border_width: c_int = @import("std").mem.zeroes(c_int),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
};
pub const XDestroyWindowEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
};
pub const XUnmapEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    from_configure: c_int = @import("std").mem.zeroes(c_int),
};
pub const XMapEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
};
pub const XMapRequestEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    parent: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
};
pub const XReparentEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    parent: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
};
pub const XConfigureEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    border_width: c_int = @import("std").mem.zeroes(c_int),
    above: Window = @import("std").mem.zeroes(Window),
    override_redirect: c_int = @import("std").mem.zeroes(c_int),
};
pub const XGravityEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
};
pub const XResizeRequestEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
};
pub const XConfigureRequestEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    parent: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    border_width: c_int = @import("std").mem.zeroes(c_int),
    above: Window = @import("std").mem.zeroes(Window),
    detail: c_int = @import("std").mem.zeroes(c_int),
    value_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
};
pub const XCirculateEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    event: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    place: c_int = @import("std").mem.zeroes(c_int),
};
pub const XCirculateRequestEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    parent: Window = @import("std").mem.zeroes(Window),
    window: Window = @import("std").mem.zeroes(Window),
    place: c_int = @import("std").mem.zeroes(c_int),
};
pub const XPropertyEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    atom: Atom = @import("std").mem.zeroes(Atom),
    time: Time = @import("std").mem.zeroes(Time),
    state: c_int = @import("std").mem.zeroes(c_int),
};
pub const XSelectionClearEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    selection: Atom = @import("std").mem.zeroes(Atom),
    time: Time = @import("std").mem.zeroes(Time),
};
pub const XSelectionRequestEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    owner: Window = @import("std").mem.zeroes(Window),
    requestor: Window = @import("std").mem.zeroes(Window),
    selection: Atom = @import("std").mem.zeroes(Atom),
    target: Atom = @import("std").mem.zeroes(Atom),
    property: Atom = @import("std").mem.zeroes(Atom),
    time: Time = @import("std").mem.zeroes(Time),
};
pub const XSelectionEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    requestor: Window = @import("std").mem.zeroes(Window),
    selection: Atom = @import("std").mem.zeroes(Atom),
    target: Atom = @import("std").mem.zeroes(Atom),
    property: Atom = @import("std").mem.zeroes(Atom),
    time: Time = @import("std").mem.zeroes(Time),
};
pub const XColormapEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    colormap: Colormap = @import("std").mem.zeroes(Colormap),
    new: c_int = @import("std").mem.zeroes(c_int),
    state: c_int = @import("std").mem.zeroes(c_int),
};
const union_unnamed_4 = extern union {
    b: [20]u8,
    s: [10]c_short,
    l: [5]c_long,
};
pub const XClientMessageEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    message_type: Atom = @import("std").mem.zeroes(Atom),
    format: c_int = @import("std").mem.zeroes(c_int),
    data: union_unnamed_4 = @import("std").mem.zeroes(union_unnamed_4),
};
pub const XMappingEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
    request: c_int = @import("std").mem.zeroes(c_int),
    first_keycode: c_int = @import("std").mem.zeroes(c_int),
    count: c_int = @import("std").mem.zeroes(c_int),
};
pub const XErrorEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    resourceid: XID = @import("std").mem.zeroes(XID),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    error_code: u8 = @import("std").mem.zeroes(u8),
    request_code: u8 = @import("std").mem.zeroes(u8),
    minor_code: u8 = @import("std").mem.zeroes(u8),
};
pub const XAnyEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    window: Window = @import("std").mem.zeroes(Window),
};
pub const XGenericEvent = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    extension: c_int = @import("std").mem.zeroes(c_int),
    evtype: c_int = @import("std").mem.zeroes(c_int),
};
pub const XGenericEventCookie = extern struct {
    type: c_int = @import("std").mem.zeroes(c_int),
    serial: c_ulong = @import("std").mem.zeroes(c_ulong),
    send_event: c_int = @import("std").mem.zeroes(c_int),
    display: ?*Display = @import("std").mem.zeroes(?*Display),
    extension: c_int = @import("std").mem.zeroes(c_int),
    evtype: c_int = @import("std").mem.zeroes(c_int),
    cookie: c_uint = @import("std").mem.zeroes(c_uint),
    data: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque),
};
pub const union__XEvent = extern union {
    type: c_int,
    xany: XAnyEvent,
    xkey: XKeyEvent,
    xbutton: XButtonEvent,
    xmotion: XMotionEvent,
    xcrossing: XCrossingEvent,
    xfocus: XFocusChangeEvent,
    xexpose: XExposeEvent,
    xgraphicsexpose: XGraphicsExposeEvent,
    xnoexpose: XNoExposeEvent,
    xvisibility: XVisibilityEvent,
    xcreatewindow: XCreateWindowEvent,
    xdestroywindow: XDestroyWindowEvent,
    xunmap: XUnmapEvent,
    xmap: XMapEvent,
    xmaprequest: XMapRequestEvent,
    xreparent: XReparentEvent,
    xconfigure: XConfigureEvent,
    xgravity: XGravityEvent,
    xresizerequest: XResizeRequestEvent,
    xconfigurerequest: XConfigureRequestEvent,
    xcirculate: XCirculateEvent,
    xcirculaterequest: XCirculateRequestEvent,
    xproperty: XPropertyEvent,
    xselectionclear: XSelectionClearEvent,
    xselectionrequest: XSelectionRequestEvent,
    xselection: XSelectionEvent,
    xcolormap: XColormapEvent,
    xclient: XClientMessageEvent,
    xmapping: XMappingEvent,
    xerror: XErrorEvent,
    xkeymap: XKeymapEvent,
    xgeneric: XGenericEvent,
    xcookie: XGenericEventCookie,
    pad: [24]c_long,
};
pub const XEvent = union__XEvent;
pub const XCharStruct = extern struct {
    lbearing: c_short = @import("std").mem.zeroes(c_short),
    rbearing: c_short = @import("std").mem.zeroes(c_short),
    width: c_short = @import("std").mem.zeroes(c_short),
    ascent: c_short = @import("std").mem.zeroes(c_short),
    descent: c_short = @import("std").mem.zeroes(c_short),
    attributes: c_ushort = @import("std").mem.zeroes(c_ushort),
};
pub const XFontProp = extern struct {
    name: Atom = @import("std").mem.zeroes(Atom),
    card32: c_ulong = @import("std").mem.zeroes(c_ulong),
};
pub const XFontStruct = extern struct {
    ext_data: [*c]XExtData = @import("std").mem.zeroes([*c]XExtData),
    fid: Font = @import("std").mem.zeroes(Font),
    direction: c_uint = @import("std").mem.zeroes(c_uint),
    min_char_or_byte2: c_uint = @import("std").mem.zeroes(c_uint),
    max_char_or_byte2: c_uint = @import("std").mem.zeroes(c_uint),
    min_byte1: c_uint = @import("std").mem.zeroes(c_uint),
    max_byte1: c_uint = @import("std").mem.zeroes(c_uint),
    all_chars_exist: c_int = @import("std").mem.zeroes(c_int),
    default_char: c_uint = @import("std").mem.zeroes(c_uint),
    n_properties: c_int = @import("std").mem.zeroes(c_int),
    properties: [*c]XFontProp = @import("std").mem.zeroes([*c]XFontProp),
    min_bounds: XCharStruct = @import("std").mem.zeroes(XCharStruct),
    max_bounds: XCharStruct = @import("std").mem.zeroes(XCharStruct),
    per_char: [*c]XCharStruct = @import("std").mem.zeroes([*c]XCharStruct),
    ascent: c_int = @import("std").mem.zeroes(c_int),
    descent: c_int = @import("std").mem.zeroes(c_int),
};
pub const XTextItem = extern struct {
    chars: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    nchars: c_int = @import("std").mem.zeroes(c_int),
    delta: c_int = @import("std").mem.zeroes(c_int),
    font: Font = @import("std").mem.zeroes(Font),
};
pub const XChar2b = extern struct {
    byte1: u8 = @import("std").mem.zeroes(u8),
    byte2: u8 = @import("std").mem.zeroes(u8),
};
pub const XTextItem16 = extern struct {
    chars: [*c]XChar2b = @import("std").mem.zeroes([*c]XChar2b),
    nchars: c_int = @import("std").mem.zeroes(c_int),
    delta: c_int = @import("std").mem.zeroes(c_int),
    font: Font = @import("std").mem.zeroes(Font),
};
pub const XEDataObject = extern union {
    display: ?*Display,
    gc: GC,
    visual: [*c]Visual,
    screen: [*c]Screen,
    pixmap_format: [*c]ScreenFormat,
    font: [*c]XFontStruct,
};
pub const XFontSetExtents = extern struct {
    max_ink_extent: XRectangle = @import("std").mem.zeroes(XRectangle),
    max_logical_extent: XRectangle = @import("std").mem.zeroes(XRectangle),
};
pub const struct__XOM = opaque {};
pub const XOM = ?*struct__XOM;
pub const struct__XOC = opaque {};
pub const XOC = ?*struct__XOC;
pub const XFontSet = ?*struct__XOC;
pub const XmbTextItem = extern struct {
    chars: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    nchars: c_int = @import("std").mem.zeroes(c_int),
    delta: c_int = @import("std").mem.zeroes(c_int),
    font_set: XFontSet = @import("std").mem.zeroes(XFontSet),
};
pub const XwcTextItem = extern struct {
    chars: [*c]wchar_t = @import("std").mem.zeroes([*c]wchar_t),
    nchars: c_int = @import("std").mem.zeroes(c_int),
    delta: c_int = @import("std").mem.zeroes(c_int),
    font_set: XFontSet = @import("std").mem.zeroes(XFontSet),
};
pub const XOMCharSetList = extern struct {
    charset_count: c_int = @import("std").mem.zeroes(c_int),
    charset_list: [*c][*c]u8 = @import("std").mem.zeroes([*c][*c]u8),
};
pub const XOMOrientation_LTR_TTB: c_int = 0;
pub const XOMOrientation_RTL_TTB: c_int = 1;
pub const XOMOrientation_TTB_LTR: c_int = 2;
pub const XOMOrientation_TTB_RTL: c_int = 3;
pub const XOMOrientation_Context: c_int = 4;
pub const XOrientation = c_uint;
pub const XOMOrientation = extern struct {
    num_orientation: c_int = @import("std").mem.zeroes(c_int),
    orientation: [*c]XOrientation = @import("std").mem.zeroes([*c]XOrientation),
};
pub const XOMFontInfo = extern struct {
    num_font: c_int = @import("std").mem.zeroes(c_int),
    font_struct_list: [*c][*c]XFontStruct = @import("std").mem.zeroes([*c][*c]XFontStruct),
    font_name_list: [*c][*c]u8 = @import("std").mem.zeroes([*c][*c]u8),
};
pub const struct__XIM = opaque {};
pub const XIM = ?*struct__XIM;
pub const struct__XIC = opaque {};
pub const XIC = ?*struct__XIC;
pub const XIMProc = ?*const fn (XIM, XPointer, XPointer) callconv(.c) void;
pub const XICProc = ?*const fn (XIC, XPointer, XPointer) callconv(.c) c_int;
pub const XIDProc = ?*const fn (?*Display, XPointer, XPointer) callconv(.c) void;
pub const XIMStyle = c_ulong;
pub const XIMStyles = extern struct {
    count_styles: c_ushort = @import("std").mem.zeroes(c_ushort),
    supported_styles: [*c]XIMStyle = @import("std").mem.zeroes([*c]XIMStyle),
};
pub const XVaNestedList = ?*anyopaque;
pub const XIMCallback = extern struct {
    client_data: XPointer = @import("std").mem.zeroes(XPointer),
    callback: XIMProc = @import("std").mem.zeroes(XIMProc),
};
pub const XICCallback = extern struct {
    client_data: XPointer = @import("std").mem.zeroes(XPointer),
    callback: XICProc = @import("std").mem.zeroes(XICProc),
};
pub const XIMFeedback = c_ulong;
const union_unnamed_5 = extern union {
    multi_byte: [*c]u8,
    wide_char: [*c]wchar_t,
};
pub const struct__XIMText = extern struct {
    length: c_ushort = @import("std").mem.zeroes(c_ushort),
    feedback: [*c]XIMFeedback = @import("std").mem.zeroes([*c]XIMFeedback),
    encoding_is_wchar: c_int = @import("std").mem.zeroes(c_int),
    string: union_unnamed_5 = @import("std").mem.zeroes(union_unnamed_5),
};
pub const XIMText = struct__XIMText;
pub const XIMPreeditState = c_ulong;
pub const struct__XIMPreeditStateNotifyCallbackStruct = extern struct {
    state: XIMPreeditState = @import("std").mem.zeroes(XIMPreeditState),
};
pub const XIMPreeditStateNotifyCallbackStruct = struct__XIMPreeditStateNotifyCallbackStruct;
pub const XIMResetState = c_ulong;
pub const XIMStringConversionFeedback = c_ulong;
const union_unnamed_6 = extern union {
    mbs: [*c]u8,
    wcs: [*c]wchar_t,
};
pub const struct__XIMStringConversionText = extern struct {
    length: c_ushort = @import("std").mem.zeroes(c_ushort),
    feedback: [*c]XIMStringConversionFeedback = @import("std").mem.zeroes([*c]XIMStringConversionFeedback),
    encoding_is_wchar: c_int = @import("std").mem.zeroes(c_int),
    string: union_unnamed_6 = @import("std").mem.zeroes(union_unnamed_6),
};
pub const XIMStringConversionText = struct__XIMStringConversionText;
pub const XIMStringConversionPosition = c_ushort;
pub const XIMStringConversionType = c_ushort;
pub const XIMStringConversionOperation = c_ushort;
pub const XIMForwardChar: c_int = 0;
pub const XIMBackwardChar: c_int = 1;
pub const XIMForwardWord: c_int = 2;
pub const XIMBackwardWord: c_int = 3;
pub const XIMCaretUp: c_int = 4;
pub const XIMCaretDown: c_int = 5;
pub const XIMNextLine: c_int = 6;
pub const XIMPreviousLine: c_int = 7;
pub const XIMLineStart: c_int = 8;
pub const XIMLineEnd: c_int = 9;
pub const XIMAbsolutePosition: c_int = 10;
pub const XIMDontChange: c_int = 11;
pub const XIMCaretDirection = c_uint;
pub const struct__XIMStringConversionCallbackStruct = extern struct {
    position: XIMStringConversionPosition = @import("std").mem.zeroes(XIMStringConversionPosition),
    direction: XIMCaretDirection = @import("std").mem.zeroes(XIMCaretDirection),
    operation: XIMStringConversionOperation = @import("std").mem.zeroes(XIMStringConversionOperation),
    factor: c_ushort = @import("std").mem.zeroes(c_ushort),
    text: [*c]XIMStringConversionText = @import("std").mem.zeroes([*c]XIMStringConversionText),
};
pub const XIMStringConversionCallbackStruct = struct__XIMStringConversionCallbackStruct;
pub const struct__XIMPreeditDrawCallbackStruct = extern struct {
    caret: c_int = @import("std").mem.zeroes(c_int),
    chg_first: c_int = @import("std").mem.zeroes(c_int),
    chg_length: c_int = @import("std").mem.zeroes(c_int),
    text: [*c]XIMText = @import("std").mem.zeroes([*c]XIMText),
};
pub const XIMPreeditDrawCallbackStruct = struct__XIMPreeditDrawCallbackStruct;
pub const XIMIsInvisible: c_int = 0;
pub const XIMIsPrimary: c_int = 1;
pub const XIMIsSecondary: c_int = 2;
pub const XIMCaretStyle = c_uint;
pub const struct__XIMPreeditCaretCallbackStruct = extern struct {
    position: c_int = @import("std").mem.zeroes(c_int),
    direction: XIMCaretDirection = @import("std").mem.zeroes(XIMCaretDirection),
    style: XIMCaretStyle = @import("std").mem.zeroes(XIMCaretStyle),
};
pub const XIMPreeditCaretCallbackStruct = struct__XIMPreeditCaretCallbackStruct;
pub const XIMTextType: c_int = 0;
pub const XIMBitmapType: c_int = 1;
pub const XIMStatusDataType = c_uint;
const union_unnamed_7 = extern union {
    text: [*c]XIMText,
    bitmap: Pixmap,
};
pub const struct__XIMStatusDrawCallbackStruct = extern struct {
    type: XIMStatusDataType = @import("std").mem.zeroes(XIMStatusDataType),
    data: union_unnamed_7 = @import("std").mem.zeroes(union_unnamed_7),
};
pub const XIMStatusDrawCallbackStruct = struct__XIMStatusDrawCallbackStruct;
pub const struct__XIMHotKeyTrigger = extern struct {
    keysym: KeySym = @import("std").mem.zeroes(KeySym),
    modifier: c_int = @import("std").mem.zeroes(c_int),
    modifier_mask: c_int = @import("std").mem.zeroes(c_int),
};
pub const XIMHotKeyTrigger = struct__XIMHotKeyTrigger;
pub const struct__XIMHotKeyTriggers = extern struct {
    num_hot_key: c_int = @import("std").mem.zeroes(c_int),
    key: [*c]XIMHotKeyTrigger = @import("std").mem.zeroes([*c]XIMHotKeyTrigger),
};
pub const XIMHotKeyTriggers = struct__XIMHotKeyTriggers;
pub const XIMHotKeyState = c_ulong;
pub const XIMValuesList = extern struct {
    count_values: c_ushort = @import("std").mem.zeroes(c_ushort),
    supported_values: [*c][*c]u8 = @import("std").mem.zeroes([*c][*c]u8),
};
pub extern var _Xdebug: c_int;
pub extern fn XLoadQueryFont(?*Display, [*c]const u8) [*c]XFontStruct;
pub extern fn XQueryFont(?*Display, XID) [*c]XFontStruct;
pub extern fn XGetMotionEvents(?*Display, Window, Time, Time, [*c]c_int) [*c]XTimeCoord;
pub extern fn XDeleteModifiermapEntry([*c]XModifierKeymap, KeyCode, c_int) [*c]XModifierKeymap;
pub extern fn XGetModifierMapping(?*Display) [*c]XModifierKeymap;
pub extern fn XInsertModifiermapEntry([*c]XModifierKeymap, KeyCode, c_int) [*c]XModifierKeymap;
pub extern fn XNewModifiermap(c_int) [*c]XModifierKeymap;
pub extern fn XCreateImage(?*Display, [*c]Visual, c_uint, c_int, c_int, [*c]u8, c_uint, c_uint, c_int, c_int) [*c]XImage;
pub extern fn XInitImage([*c]XImage) c_int;
pub extern fn XGetImage(?*Display, Drawable, c_int, c_int, c_uint, c_uint, c_ulong, c_int) [*c]XImage;
pub extern fn XGetSubImage(?*Display, Drawable, c_int, c_int, c_uint, c_uint, c_ulong, c_int, [*c]XImage, c_int, c_int) [*c]XImage;
pub extern fn XOpenDisplay([*c]const u8) ?*Display;
pub extern fn XrmInitialize() void;
pub extern fn XFetchBytes(?*Display, [*c]c_int) [*c]u8;
pub extern fn XFetchBuffer(?*Display, [*c]c_int, c_int) [*c]u8;
pub extern fn XGetAtomName(?*Display, Atom) [*c]u8;
pub extern fn XGetAtomNames(?*Display, [*c]Atom, c_int, [*c][*c]u8) c_int;
pub extern fn XGetDefault(?*Display, [*c]const u8, [*c]const u8) [*c]u8;
pub extern fn XDisplayName([*c]const u8) [*c]u8;
pub extern fn XKeysymToString(KeySym) [*c]u8;
pub extern fn XSynchronize(?*Display, c_int) ?*const fn (?*Display) callconv(.c) c_int;
pub extern fn XSetAfterFunction(?*Display, ?*const fn (?*Display) callconv(.c) c_int) ?*const fn (?*Display) callconv(.c) c_int;
pub extern fn XInternAtom(?*Display, [*c]const u8, c_int) Atom;
pub extern fn XInternAtoms(?*Display, [*c][*c]u8, c_int, c_int, [*c]Atom) c_int;
pub extern fn XCopyColormapAndFree(?*Display, Colormap) Colormap;
pub extern fn XCreateColormap(?*Display, Window, [*c]Visual, c_int) Colormap;
pub extern fn XCreatePixmapCursor(?*Display, Pixmap, Pixmap, [*c]XColor, [*c]XColor, c_uint, c_uint) Cursor;
pub extern fn XCreateGlyphCursor(?*Display, Font, Font, c_uint, c_uint, [*c]const XColor, [*c]const XColor) Cursor;
pub extern fn XCreateFontCursor(?*Display, c_uint) Cursor;
pub extern fn XLoadFont(?*Display, [*c]const u8) Font;
pub extern fn XCreateGC(?*Display, Drawable, c_ulong, [*c]XGCValues) GC;
pub extern fn XGContextFromGC(GC) GContext;
pub extern fn XFlushGC(?*Display, GC) void;
pub extern fn XCreatePixmap(?*Display, Drawable, c_uint, c_uint, c_uint) Pixmap;
pub extern fn XCreateBitmapFromData(?*Display, Drawable, [*c]const u8, c_uint, c_uint) Pixmap;
pub extern fn XCreatePixmapFromBitmapData(?*Display, Drawable, [*c]u8, c_uint, c_uint, c_ulong, c_ulong, c_uint) Pixmap;
pub extern fn XCreateSimpleWindow(?*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_ulong, c_ulong) Window;
pub extern fn XGetSelectionOwner(?*Display, Atom) Window;
pub extern fn XCreateWindow(?*Display, Window, c_int, c_int, c_uint, c_uint, c_uint, c_int, c_uint, [*c]Visual, c_ulong, [*c]XSetWindowAttributes) Window;
pub extern fn XListInstalledColormaps(?*Display, Window, [*c]c_int) [*c]Colormap;
pub extern fn XListFonts(?*Display, [*c]const u8, c_int, [*c]c_int) [*c][*c]u8;
pub extern fn XListFontsWithInfo(?*Display, [*c]const u8, c_int, [*c]c_int, [*c][*c]XFontStruct) [*c][*c]u8;
pub extern fn XGetFontPath(?*Display, [*c]c_int) [*c][*c]u8;
pub extern fn XListExtensions(?*Display, [*c]c_int) [*c][*c]u8;
pub extern fn XListProperties(?*Display, Window, [*c]c_int) [*c]Atom;
pub extern fn XListHosts(?*Display, [*c]c_int, [*c]c_int) [*c]XHostAddress;
pub extern fn XKeycodeToKeysym(?*Display, KeyCode, c_int) KeySym;
pub extern fn XLookupKeysym([*c]XKeyEvent, c_int) KeySym;
pub extern fn XGetKeyboardMapping(?*Display, KeyCode, c_int, [*c]c_int) [*c]KeySym;
pub extern fn XStringToKeysym([*c]const u8) KeySym;
pub extern fn XMaxRequestSize(?*Display) c_long;
pub extern fn XExtendedMaxRequestSize(?*Display) c_long;
pub extern fn XResourceManagerString(?*Display) [*c]u8;
pub extern fn XScreenResourceString([*c]Screen) [*c]u8;
pub extern fn XDisplayMotionBufferSize(?*Display) c_ulong;
pub extern fn XVisualIDFromVisual([*c]Visual) VisualID;
pub extern fn XInitThreads() c_int;
pub extern fn XLockDisplay(?*Display) void;
pub extern fn XUnlockDisplay(?*Display) void;
pub extern fn XInitExtension(?*Display, [*c]const u8) [*c]XExtCodes;
pub extern fn XAddExtension(?*Display) [*c]XExtCodes;
pub extern fn XFindOnExtensionList([*c][*c]XExtData, c_int) [*c]XExtData;
pub extern fn XEHeadOfExtensionList(XEDataObject) [*c][*c]XExtData;
pub extern fn XRootWindow(?*Display, c_int) Window;
pub extern fn XDefaultRootWindow(?*Display) Window;
pub extern fn XRootWindowOfScreen([*c]Screen) Window;
pub extern fn XDefaultVisual(?*Display, c_int) [*c]Visual;
pub extern fn XDefaultVisualOfScreen([*c]Screen) [*c]Visual;
pub extern fn XDefaultGC(?*Display, c_int) GC;
pub extern fn XDefaultGCOfScreen([*c]Screen) GC;
pub extern fn XBlackPixel(?*Display, c_int) c_ulong;
pub extern fn XWhitePixel(?*Display, c_int) c_ulong;
pub extern fn XAllPlanes() c_ulong;
pub extern fn XBlackPixelOfScreen([*c]Screen) c_ulong;
pub extern fn XWhitePixelOfScreen([*c]Screen) c_ulong;
pub extern fn XNextRequest(?*Display) c_ulong;
pub extern fn XLastKnownRequestProcessed(?*Display) c_ulong;
pub extern fn XServerVendor(?*Display) [*c]u8;
pub extern fn XDisplayString(?*Display) [*c]u8;
pub extern fn XDefaultColormap(?*Display, c_int) Colormap;
pub extern fn XDefaultColormapOfScreen([*c]Screen) Colormap;
pub extern fn XDisplayOfScreen([*c]Screen) ?*Display;
pub extern fn XScreenOfDisplay(?*Display, c_int) [*c]Screen;
pub extern fn XDefaultScreenOfDisplay(?*Display) [*c]Screen;
pub extern fn XEventMaskOfScreen([*c]Screen) c_long;
pub extern fn XScreenNumberOfScreen([*c]Screen) c_int;
pub const XErrorHandler = ?*const fn (?*Display, [*c]XErrorEvent) callconv(.c) c_int;
pub extern fn XSetErrorHandler(XErrorHandler) XErrorHandler;
pub const XIOErrorHandler = ?*const fn (?*Display) callconv(.c) c_int;
pub extern fn XSetIOErrorHandler(XIOErrorHandler) XIOErrorHandler;
pub const XIOErrorExitHandler = ?*const fn (?*Display, ?*anyopaque) callconv(.c) void;
pub extern fn XSetIOErrorExitHandler(?*Display, XIOErrorExitHandler, ?*anyopaque) void;
pub extern fn XListPixmapFormats(?*Display, [*c]c_int) [*c]XPixmapFormatValues;
pub extern fn XListDepths(?*Display, c_int, [*c]c_int) [*c]c_int;
pub extern fn XReconfigureWMWindow(?*Display, Window, c_int, c_uint, [*c]XWindowChanges) c_int;
pub extern fn XGetWMProtocols(?*Display, Window, [*c][*c]Atom, [*c]c_int) c_int;
pub extern fn XSetWMProtocols(?*Display, Window, [*c]Atom, c_int) c_int;
pub extern fn XIconifyWindow(?*Display, Window, c_int) c_int;
pub extern fn XWithdrawWindow(?*Display, Window, c_int) c_int;
pub extern fn XGetCommand(?*Display, Window, [*c][*c][*c]u8, [*c]c_int) c_int;
pub extern fn XGetWMColormapWindows(?*Display, Window, [*c][*c]Window, [*c]c_int) c_int;
pub extern fn XSetWMColormapWindows(?*Display, Window, [*c]Window, c_int) c_int;
pub extern fn XFreeStringList([*c][*c]u8) void;
pub extern fn XSetTransientForHint(?*Display, Window, Window) c_int;
pub extern fn XActivateScreenSaver(?*Display) c_int;
pub extern fn XAddHost(?*Display, [*c]XHostAddress) c_int;
pub extern fn XAddHosts(?*Display, [*c]XHostAddress, c_int) c_int;
pub extern fn XAddToExtensionList([*c][*c]struct__XExtData, [*c]XExtData) c_int;
pub extern fn XAddToSaveSet(?*Display, Window) c_int;
pub extern fn XAllocColor(?*Display, Colormap, [*c]XColor) c_int;
pub extern fn XAllocColorCells(?*Display, Colormap, c_int, [*c]c_ulong, c_uint, [*c]c_ulong, c_uint) c_int;
pub extern fn XAllocColorPlanes(?*Display, Colormap, c_int, [*c]c_ulong, c_int, c_int, c_int, c_int, [*c]c_ulong, [*c]c_ulong, [*c]c_ulong) c_int;
pub extern fn XAllocNamedColor(?*Display, Colormap, [*c]const u8, [*c]XColor, [*c]XColor) c_int;
pub extern fn XAllowEvents(?*Display, c_int, Time) c_int;
pub extern fn XAutoRepeatOff(?*Display) c_int;
pub extern fn XAutoRepeatOn(?*Display) c_int;
pub extern fn XBell(?*Display, c_int) c_int;
pub extern fn XBitmapBitOrder(?*Display) c_int;
pub extern fn XBitmapPad(?*Display) c_int;
pub extern fn XBitmapUnit(?*Display) c_int;
pub extern fn XCellsOfScreen([*c]Screen) c_int;
pub extern fn XChangeActivePointerGrab(?*Display, c_uint, Cursor, Time) c_int;
pub extern fn XChangeGC(?*Display, GC, c_ulong, [*c]XGCValues) c_int;
pub extern fn XChangeKeyboardControl(?*Display, c_ulong, [*c]XKeyboardControl) c_int;
pub extern fn XChangeKeyboardMapping(?*Display, c_int, c_int, [*c]KeySym, c_int) c_int;
pub extern fn XChangePointerControl(?*Display, c_int, c_int, c_int, c_int, c_int) c_int;
pub extern fn XChangeProperty(?*Display, Window, Atom, Atom, c_int, c_int, [*c]const u8, c_int) c_int;
pub extern fn XChangeSaveSet(?*Display, Window, c_int) c_int;
pub extern fn XChangeWindowAttributes(?*Display, Window, c_ulong, [*c]XSetWindowAttributes) c_int;
pub extern fn XCheckIfEvent(?*Display, [*c]XEvent, ?*const fn (?*Display, [*c]XEvent, XPointer) callconv(.c) c_int, XPointer) c_int;
pub extern fn XCheckMaskEvent(?*Display, c_long, [*c]XEvent) c_int;
pub extern fn XCheckTypedEvent(?*Display, c_int, [*c]XEvent) c_int;
pub extern fn XCheckTypedWindowEvent(?*Display, Window, c_int, [*c]XEvent) c_int;
pub extern fn XCheckWindowEvent(?*Display, Window, c_long, [*c]XEvent) c_int;
pub extern fn XCirculateSubwindows(?*Display, Window, c_int) c_int;
pub extern fn XCirculateSubwindowsDown(?*Display, Window) c_int;
pub extern fn XCirculateSubwindowsUp(?*Display, Window) c_int;
pub extern fn XClearArea(?*Display, Window, c_int, c_int, c_uint, c_uint, c_int) c_int;
pub extern fn XClearWindow(?*Display, Window) c_int;
pub extern fn XCloseDisplay(?*Display) c_int;
pub extern fn XConfigureWindow(?*Display, Window, c_uint, [*c]XWindowChanges) c_int;
pub extern fn XConnectionNumber(?*Display) c_int;
pub extern fn XConvertSelection(?*Display, Atom, Atom, Atom, Window, Time) c_int;
pub extern fn XCopyArea(?*Display, Drawable, Drawable, GC, c_int, c_int, c_uint, c_uint, c_int, c_int) c_int;
pub extern fn XCopyGC(?*Display, GC, c_ulong, GC) c_int;
pub extern fn XCopyPlane(?*Display, Drawable, Drawable, GC, c_int, c_int, c_uint, c_uint, c_int, c_int, c_ulong) c_int;
pub extern fn XDefaultDepth(?*Display, c_int) c_int;
pub extern fn XDefaultDepthOfScreen([*c]Screen) c_int;
pub extern fn XDefaultScreen(?*Display) c_int;
pub extern fn XDefineCursor(?*Display, Window, Cursor) c_int;
pub extern fn XDeleteProperty(?*Display, Window, Atom) c_int;
pub extern fn XDestroyWindow(?*Display, Window) c_int;
pub extern fn XDestroySubwindows(?*Display, Window) c_int;
pub extern fn XDoesBackingStore([*c]Screen) c_int;
pub extern fn XDoesSaveUnders([*c]Screen) c_int;
pub extern fn XDisableAccessControl(?*Display) c_int;
pub extern fn XDisplayCells(?*Display, c_int) c_int;
pub extern fn XDisplayHeight(?*Display, c_int) c_int;
pub extern fn XDisplayHeightMM(?*Display, c_int) c_int;
pub extern fn XDisplayKeycodes(?*Display, [*c]c_int, [*c]c_int) c_int;
pub extern fn XDisplayPlanes(?*Display, c_int) c_int;
pub extern fn XDisplayWidth(?*Display, c_int) c_int;
pub extern fn XDisplayWidthMM(?*Display, c_int) c_int;
pub extern fn XDrawArc(?*Display, Drawable, GC, c_int, c_int, c_uint, c_uint, c_int, c_int) c_int;
pub extern fn XDrawArcs(?*Display, Drawable, GC, [*c]XArc, c_int) c_int;
pub extern fn XDrawImageString(?*Display, Drawable, GC, c_int, c_int, [*c]const u8, c_int) c_int;
pub extern fn XDrawImageString16(?*Display, Drawable, GC, c_int, c_int, [*c]const XChar2b, c_int) c_int;
pub extern fn XDrawLine(?*Display, Drawable, GC, c_int, c_int, c_int, c_int) c_int;
pub extern fn XDrawLines(?*Display, Drawable, GC, [*c]XPoint, c_int, c_int) c_int;
pub extern fn XDrawPoint(?*Display, Drawable, GC, c_int, c_int) c_int;
pub extern fn XDrawPoints(?*Display, Drawable, GC, [*c]XPoint, c_int, c_int) c_int;
pub extern fn XDrawRectangle(?*Display, Drawable, GC, c_int, c_int, c_uint, c_uint) c_int;
pub extern fn XDrawRectangles(?*Display, Drawable, GC, [*c]XRectangle, c_int) c_int;
pub extern fn XDrawSegments(?*Display, Drawable, GC, [*c]XSegment, c_int) c_int;
pub extern fn XDrawString(?*Display, Drawable, GC, c_int, c_int, [*c]const u8, c_int) c_int;
pub extern fn XDrawString16(?*Display, Drawable, GC, c_int, c_int, [*c]const XChar2b, c_int) c_int;
pub extern fn XDrawText(?*Display, Drawable, GC, c_int, c_int, [*c]XTextItem, c_int) c_int;
pub extern fn XDrawText16(?*Display, Drawable, GC, c_int, c_int, [*c]XTextItem16, c_int) c_int;
pub extern fn XEnableAccessControl(?*Display) c_int;
pub extern fn XEventsQueued(?*Display, c_int) c_int;
pub extern fn XFetchName(?*Display, Window, [*c][*c]u8) c_int;
pub extern fn XFillArc(?*Display, Drawable, GC, c_int, c_int, c_uint, c_uint, c_int, c_int) c_int;
pub extern fn XFillArcs(?*Display, Drawable, GC, [*c]XArc, c_int) c_int;
pub extern fn XFillPolygon(?*Display, Drawable, GC, [*c]XPoint, c_int, c_int, c_int) c_int;
pub extern fn XFillRectangle(?*Display, Drawable, GC, c_int, c_int, c_uint, c_uint) c_int;
pub extern fn XFillRectangles(?*Display, Drawable, GC, [*c]XRectangle, c_int) c_int;
pub extern fn XFlush(?*Display) c_int;
pub extern fn XForceScreenSaver(?*Display, c_int) c_int;
pub extern fn XFree(?*anyopaque) c_int;
pub extern fn XFreeColormap(?*Display, Colormap) c_int;
pub extern fn XFreeColors(?*Display, Colormap, [*c]c_ulong, c_int, c_ulong) c_int;
pub extern fn XFreeCursor(?*Display, Cursor) c_int;
pub extern fn XFreeExtensionList([*c][*c]u8) c_int;
pub extern fn XFreeFont(?*Display, [*c]XFontStruct) c_int;
pub extern fn XFreeFontInfo([*c][*c]u8, [*c]XFontStruct, c_int) c_int;
pub extern fn XFreeFontNames([*c][*c]u8) c_int;
pub extern fn XFreeFontPath([*c][*c]u8) c_int;
pub extern fn XFreeGC(?*Display, GC) c_int;
pub extern fn XFreeModifiermap([*c]XModifierKeymap) c_int;
pub extern fn XFreePixmap(?*Display, Pixmap) c_int;
pub extern fn XGeometry(?*Display, c_int, [*c]const u8, [*c]const u8, c_uint, c_uint, c_uint, c_int, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub extern fn XGetErrorDatabaseText(?*Display, [*c]const u8, [*c]const u8, [*c]const u8, [*c]u8, c_int) c_int;
pub extern fn XGetErrorText(?*Display, c_int, [*c]u8, c_int) c_int;
pub extern fn XGetFontProperty([*c]XFontStruct, Atom, [*c]c_ulong) c_int;
pub extern fn XGetGCValues(?*Display, GC, c_ulong, [*c]XGCValues) c_int;
pub extern fn XGetGeometry(?*Display, Drawable, [*c]Window, [*c]c_int, [*c]c_int, [*c]c_uint, [*c]c_uint, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XGetIconName(?*Display, Window, [*c][*c]u8) c_int;
pub extern fn XGetInputFocus(?*Display, [*c]Window, [*c]c_int) c_int;
pub extern fn XGetKeyboardControl(?*Display, [*c]XKeyboardState) c_int;
pub extern fn XGetPointerControl(?*Display, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub extern fn XGetPointerMapping(?*Display, [*c]u8, c_int) c_int;
pub extern fn XGetScreenSaver(?*Display, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub extern fn XGetTransientForHint(?*Display, Window, [*c]Window) c_int;
pub extern fn XGetWindowProperty(?*Display, Window, Atom, c_long, c_long, c_int, Atom, [*c]Atom, [*c]c_int, [*c]c_ulong, [*c]c_ulong, [*c][*c]u8) c_int;
pub extern fn XGetWindowAttributes(?*Display, Window, [*c]XWindowAttributes) c_int;
pub extern fn XGrabButton(?*Display, c_uint, c_uint, Window, c_int, c_uint, c_int, c_int, Window, Cursor) c_int;
pub extern fn XGrabKey(?*Display, c_int, c_uint, Window, c_int, c_int, c_int) c_int;
pub extern fn XGrabKeyboard(?*Display, Window, c_int, c_int, c_int, Time) c_int;
pub extern fn XGrabPointer(?*Display, Window, c_int, c_uint, c_int, c_int, Window, Cursor, Time) c_int;
pub extern fn XGrabServer(?*Display) c_int;
pub extern fn XHeightMMOfScreen([*c]Screen) c_int;
pub extern fn XHeightOfScreen([*c]Screen) c_int;
pub extern fn XIfEvent(?*Display, [*c]XEvent, ?*const fn (?*Display, [*c]XEvent, XPointer) callconv(.c) c_int, XPointer) c_int;
pub extern fn XImageByteOrder(?*Display) c_int;
pub extern fn XInstallColormap(?*Display, Colormap) c_int;
pub extern fn XKeysymToKeycode(?*Display, KeySym) KeyCode;
pub extern fn XKillClient(?*Display, XID) c_int;
pub extern fn XLookupColor(?*Display, Colormap, [*c]const u8, [*c]XColor, [*c]XColor) c_int;
pub extern fn XLowerWindow(?*Display, Window) c_int;
pub extern fn XMapRaised(?*Display, Window) c_int;
pub extern fn XMapSubwindows(?*Display, Window) c_int;
pub extern fn XMapWindow(?*Display, Window) c_int;
pub extern fn XMaskEvent(?*Display, c_long, [*c]XEvent) c_int;
pub extern fn XMaxCmapsOfScreen([*c]Screen) c_int;
pub extern fn XMinCmapsOfScreen([*c]Screen) c_int;
pub extern fn XMoveResizeWindow(?*Display, Window, c_int, c_int, c_uint, c_uint) c_int;
pub extern fn XMoveWindow(?*Display, Window, c_int, c_int) c_int;
pub extern fn XNextEvent(?*Display, [*c]XEvent) c_int;
pub extern fn XNoOp(?*Display) c_int;
pub extern fn XParseColor(?*Display, Colormap, [*c]const u8, [*c]XColor) c_int;
pub extern fn XParseGeometry([*c]const u8, [*c]c_int, [*c]c_int, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XPeekEvent(?*Display, [*c]XEvent) c_int;
pub extern fn XPeekIfEvent(?*Display, [*c]XEvent, ?*const fn (?*Display, [*c]XEvent, XPointer) callconv(.c) c_int, XPointer) c_int;
pub extern fn XPending(?*Display) c_int;
pub extern fn XPlanesOfScreen([*c]Screen) c_int;
pub extern fn XProtocolRevision(?*Display) c_int;
pub extern fn XProtocolVersion(?*Display) c_int;
pub extern fn XPutBackEvent(?*Display, [*c]XEvent) c_int;
pub extern fn XPutImage(?*Display, Drawable, GC, [*c]XImage, c_int, c_int, c_int, c_int, c_uint, c_uint) c_int;
pub extern fn XQLength(?*Display) c_int;
pub extern fn XQueryBestCursor(?*Display, Drawable, c_uint, c_uint, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XQueryBestSize(?*Display, c_int, Drawable, c_uint, c_uint, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XQueryBestStipple(?*Display, Drawable, c_uint, c_uint, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XQueryBestTile(?*Display, Drawable, c_uint, c_uint, [*c]c_uint, [*c]c_uint) c_int;
pub extern fn XQueryColor(?*Display, Colormap, [*c]XColor) c_int;
pub extern fn XQueryColors(?*Display, Colormap, [*c]XColor, c_int) c_int;
pub extern fn XQueryExtension(?*Display, [*c]const u8, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub extern fn XQueryKeymap(?*Display, [*c]u8) c_int;
pub extern fn XQueryPointer(?*Display, Window, [*c]Window, [*c]Window, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_uint) c_int;
pub extern fn XQueryTextExtents(?*Display, XID, [*c]const u8, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]XCharStruct) c_int;
pub extern fn XQueryTextExtents16(?*Display, XID, [*c]const XChar2b, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]XCharStruct) c_int;
pub extern fn XQueryTree(?*Display, Window, [*c]Window, [*c]Window, [*c][*c]Window, [*c]c_uint) c_int;
pub extern fn XRaiseWindow(?*Display, Window) c_int;
pub extern fn XReadBitmapFile(?*Display, Drawable, [*c]const u8, [*c]c_uint, [*c]c_uint, [*c]Pixmap, [*c]c_int, [*c]c_int) c_int;
pub extern fn XReadBitmapFileData([*c]const u8, [*c]c_uint, [*c]c_uint, [*c][*c]u8, [*c]c_int, [*c]c_int) c_int;
pub extern fn XRebindKeysym(?*Display, KeySym, [*c]KeySym, c_int, [*c]const u8, c_int) c_int;
pub extern fn XRecolorCursor(?*Display, Cursor, [*c]XColor, [*c]XColor) c_int;
pub extern fn XRefreshKeyboardMapping([*c]XMappingEvent) c_int;
pub extern fn XRemoveFromSaveSet(?*Display, Window) c_int;
pub extern fn XRemoveHost(?*Display, [*c]XHostAddress) c_int;
pub extern fn XRemoveHosts(?*Display, [*c]XHostAddress, c_int) c_int;
pub extern fn XReparentWindow(?*Display, Window, Window, c_int, c_int) c_int;
pub extern fn XResetScreenSaver(?*Display) c_int;
pub extern fn XResizeWindow(?*Display, Window, c_uint, c_uint) c_int;
pub extern fn XRestackWindows(?*Display, [*c]Window, c_int) c_int;
pub extern fn XRotateBuffers(?*Display, c_int) c_int;
pub extern fn XRotateWindowProperties(?*Display, Window, [*c]Atom, c_int, c_int) c_int;
pub extern fn XScreenCount(?*Display) c_int;
pub extern fn XSelectInput(?*Display, Window, c_long) c_int;
pub extern fn XSendEvent(?*Display, Window, c_int, c_long, [*c]XEvent) c_int;
pub extern fn XSetAccessControl(?*Display, c_int) c_int;
pub extern fn XSetArcMode(?*Display, GC, c_int) c_int;
pub extern fn XSetBackground(?*Display, GC, c_ulong) c_int;
pub extern fn XSetClipMask(?*Display, GC, Pixmap) c_int;
pub extern fn XSetClipOrigin(?*Display, GC, c_int, c_int) c_int;
pub extern fn XSetClipRectangles(?*Display, GC, c_int, c_int, [*c]XRectangle, c_int, c_int) c_int;
pub extern fn XSetCloseDownMode(?*Display, c_int) c_int;
pub extern fn XSetCommand(?*Display, Window, [*c][*c]u8, c_int) c_int;
pub extern fn XSetDashes(?*Display, GC, c_int, [*c]const u8, c_int) c_int;
pub extern fn XSetFillRule(?*Display, GC, c_int) c_int;
pub extern fn XSetFillStyle(?*Display, GC, c_int) c_int;
pub extern fn XSetFont(?*Display, GC, Font) c_int;
pub extern fn XSetFontPath(?*Display, [*c][*c]u8, c_int) c_int;
pub extern fn XSetForeground(?*Display, GC, c_ulong) c_int;
pub extern fn XSetFunction(?*Display, GC, c_int) c_int;
pub extern fn XSetGraphicsExposures(?*Display, GC, c_int) c_int;
pub extern fn XSetIconName(?*Display, Window, [*c]const u8) c_int;
pub extern fn XSetInputFocus(?*Display, Window, c_int, Time) c_int;
pub extern fn XSetLineAttributes(?*Display, GC, c_uint, c_int, c_int, c_int) c_int;
pub extern fn XSetModifierMapping(?*Display, [*c]XModifierKeymap) c_int;
pub extern fn XSetPlaneMask(?*Display, GC, c_ulong) c_int;
pub extern fn XSetPointerMapping(?*Display, [*c]const u8, c_int) c_int;
pub extern fn XSetScreenSaver(?*Display, c_int, c_int, c_int, c_int) c_int;
pub extern fn XSetSelectionOwner(?*Display, Atom, Window, Time) c_int;
pub extern fn XSetState(?*Display, GC, c_ulong, c_ulong, c_int, c_ulong) c_int;
pub extern fn XSetStipple(?*Display, GC, Pixmap) c_int;
pub extern fn XSetSubwindowMode(?*Display, GC, c_int) c_int;
pub extern fn XSetTSOrigin(?*Display, GC, c_int, c_int) c_int;
pub extern fn XSetTile(?*Display, GC, Pixmap) c_int;
pub extern fn XSetWindowBackground(?*Display, Window, c_ulong) c_int;
pub extern fn XSetWindowBackgroundPixmap(?*Display, Window, Pixmap) c_int;
pub extern fn XSetWindowBorder(?*Display, Window, c_ulong) c_int;
pub extern fn XSetWindowBorderPixmap(?*Display, Window, Pixmap) c_int;
pub extern fn XSetWindowBorderWidth(?*Display, Window, c_uint) c_int;
pub extern fn XSetWindowColormap(?*Display, Window, Colormap) c_int;
pub extern fn XStoreBuffer(?*Display, [*c]const u8, c_int, c_int) c_int;
pub extern fn XStoreBytes(?*Display, [*c]const u8, c_int) c_int;
pub extern fn XStoreColor(?*Display, Colormap, [*c]XColor) c_int;
pub extern fn XStoreColors(?*Display, Colormap, [*c]XColor, c_int) c_int;
pub extern fn XStoreName(?*Display, Window, [*c]const u8) c_int;
pub extern fn XStoreNamedColor(?*Display, Colormap, [*c]const u8, c_ulong, c_int) c_int;
pub extern fn XSync(?*Display, c_int) c_int;
pub extern fn XTextExtents([*c]XFontStruct, [*c]const u8, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]XCharStruct) c_int;
pub extern fn XTextExtents16([*c]XFontStruct, [*c]const XChar2b, c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]XCharStruct) c_int;
pub extern fn XTextWidth([*c]XFontStruct, [*c]const u8, c_int) c_int;
pub extern fn XTextWidth16([*c]XFontStruct, [*c]const XChar2b, c_int) c_int;
pub extern fn XTranslateCoordinates(?*Display, Window, Window, c_int, c_int, [*c]c_int, [*c]c_int, [*c]Window) c_int;
pub extern fn XUndefineCursor(?*Display, Window) c_int;
pub extern fn XUngrabButton(?*Display, c_uint, c_uint, Window) c_int;
pub extern fn XUngrabKey(?*Display, c_int, c_uint, Window) c_int;
pub extern fn XUngrabKeyboard(?*Display, Time) c_int;
pub extern fn XUngrabPointer(?*Display, Time) c_int;
pub extern fn XUngrabServer(?*Display) c_int;
pub extern fn XUninstallColormap(?*Display, Colormap) c_int;
pub extern fn XUnloadFont(?*Display, Font) c_int;
pub extern fn XUnmapSubwindows(?*Display, Window) c_int;
pub extern fn XUnmapWindow(?*Display, Window) c_int;
pub extern fn XVendorRelease(?*Display) c_int;
pub extern fn XWarpPointer(?*Display, Window, Window, c_int, c_int, c_uint, c_uint, c_int, c_int) c_int;
pub extern fn XWidthMMOfScreen([*c]Screen) c_int;
pub extern fn XWidthOfScreen([*c]Screen) c_int;
pub extern fn XWindowEvent(?*Display, Window, c_long, [*c]XEvent) c_int;
pub extern fn XWriteBitmapFile(?*Display, [*c]const u8, Pixmap, c_uint, c_uint, c_int, c_int) c_int;
pub extern fn XSupportsLocale() c_int;
pub extern fn XSetLocaleModifiers([*c]const u8) [*c]u8;
pub extern fn XOpenOM(?*Display, ?*struct__XrmHashBucketRec, [*c]const u8, [*c]const u8) XOM;
pub extern fn XCloseOM(XOM) c_int;
pub extern fn XSetOMValues(XOM, ...) [*c]u8;
pub extern fn XGetOMValues(XOM, ...) [*c]u8;
pub extern fn XDisplayOfOM(XOM) ?*Display;
pub extern fn XLocaleOfOM(XOM) [*c]u8;
pub extern fn XCreateOC(XOM, ...) XOC;
pub extern fn XDestroyOC(XOC) void;
pub extern fn XOMOfOC(XOC) XOM;
pub extern fn XSetOCValues(XOC, ...) [*c]u8;
pub extern fn XGetOCValues(XOC, ...) [*c]u8;
pub extern fn XCreateFontSet(?*Display, [*c]const u8, [*c][*c][*c]u8, [*c]c_int, [*c][*c]u8) XFontSet;
pub extern fn XFreeFontSet(?*Display, XFontSet) void;
pub extern fn XFontsOfFontSet(XFontSet, [*c][*c][*c]XFontStruct, [*c][*c][*c]u8) c_int;
pub extern fn XBaseFontNameListOfFontSet(XFontSet) [*c]u8;
pub extern fn XLocaleOfFontSet(XFontSet) [*c]u8;
pub extern fn XContextDependentDrawing(XFontSet) c_int;
pub extern fn XDirectionalDependentDrawing(XFontSet) c_int;
pub extern fn XContextualDrawing(XFontSet) c_int;
pub extern fn XExtentsOfFontSet(XFontSet) [*c]XFontSetExtents;
pub extern fn XmbTextEscapement(XFontSet, [*c]const u8, c_int) c_int;
pub extern fn XwcTextEscapement(XFontSet, [*c]const wchar_t, c_int) c_int;
pub extern fn Xutf8TextEscapement(XFontSet, [*c]const u8, c_int) c_int;
pub extern fn XmbTextExtents(XFontSet, [*c]const u8, c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn XwcTextExtents(XFontSet, [*c]const wchar_t, c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn Xutf8TextExtents(XFontSet, [*c]const u8, c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn XmbTextPerCharExtents(XFontSet, [*c]const u8, c_int, [*c]XRectangle, [*c]XRectangle, c_int, [*c]c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn XwcTextPerCharExtents(XFontSet, [*c]const wchar_t, c_int, [*c]XRectangle, [*c]XRectangle, c_int, [*c]c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn Xutf8TextPerCharExtents(XFontSet, [*c]const u8, c_int, [*c]XRectangle, [*c]XRectangle, c_int, [*c]c_int, [*c]XRectangle, [*c]XRectangle) c_int;
pub extern fn XmbDrawText(?*Display, Drawable, GC, c_int, c_int, [*c]XmbTextItem, c_int) void;
pub extern fn XwcDrawText(?*Display, Drawable, GC, c_int, c_int, [*c]XwcTextItem, c_int) void;
pub extern fn Xutf8DrawText(?*Display, Drawable, GC, c_int, c_int, [*c]XmbTextItem, c_int) void;
pub extern fn XmbDrawString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const u8, c_int) void;
pub extern fn XwcDrawString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const wchar_t, c_int) void;
pub extern fn Xutf8DrawString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const u8, c_int) void;
pub extern fn XmbDrawImageString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const u8, c_int) void;
pub extern fn XwcDrawImageString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const wchar_t, c_int) void;
pub extern fn Xutf8DrawImageString(?*Display, Drawable, XFontSet, GC, c_int, c_int, [*c]const u8, c_int) void;
pub extern fn XOpenIM(?*Display, ?*struct__XrmHashBucketRec, [*c]u8, [*c]u8) XIM;
pub extern fn XCloseIM(XIM) c_int;
pub extern fn XGetIMValues(XIM, ...) [*c]u8;
pub extern fn XSetIMValues(XIM, ...) [*c]u8;
pub extern fn XDisplayOfIM(XIM) ?*Display;
pub extern fn XLocaleOfIM(XIM) [*c]u8;
pub extern fn XCreateIC(XIM, ...) XIC;
pub extern fn XDestroyIC(XIC) void;
pub extern fn XSetICFocus(XIC) void;
pub extern fn XUnsetICFocus(XIC) void;
pub extern fn XwcResetIC(XIC) [*c]wchar_t;
pub extern fn XmbResetIC(XIC) [*c]u8;
pub extern fn Xutf8ResetIC(XIC) [*c]u8;
pub extern fn XSetICValues(XIC, ...) [*c]u8;
pub extern fn XGetICValues(XIC, ...) [*c]u8;
pub extern fn XIMOfIC(XIC) XIM;
pub extern fn XFilterEvent([*c]XEvent, Window) c_int;
pub extern fn XmbLookupString(XIC, [*c]XKeyPressedEvent, [*c]u8, c_int, [*c]KeySym, [*c]c_int) c_int;
pub extern fn XwcLookupString(XIC, [*c]XKeyPressedEvent, [*c]wchar_t, c_int, [*c]KeySym, [*c]c_int) c_int;
pub extern fn Xutf8LookupString(XIC, [*c]XKeyPressedEvent, [*c]u8, c_int, [*c]KeySym, [*c]c_int) c_int;
pub extern fn XVaCreateNestedList(c_int, ...) XVaNestedList;
pub extern fn XRegisterIMInstantiateCallback(?*Display, ?*struct__XrmHashBucketRec, [*c]u8, [*c]u8, XIDProc, XPointer) c_int;
pub extern fn XUnregisterIMInstantiateCallback(?*Display, ?*struct__XrmHashBucketRec, [*c]u8, [*c]u8, XIDProc, XPointer) c_int;
pub const XConnectionWatchProc = ?*const fn (?*Display, XPointer, c_int, c_int, [*c]XPointer) callconv(.c) void;
pub extern fn XInternalConnectionNumbers(?*Display, [*c][*c]c_int, [*c]c_int) c_int;
pub extern fn XProcessInternalConnection(?*Display, c_int) void;
pub extern fn XAddConnectionWatch(?*Display, XConnectionWatchProc, XPointer) c_int;
pub extern fn XRemoveConnectionWatch(?*Display, XConnectionWatchProc, XPointer) void;
pub extern fn XSetAuthorization([*c]u8, c_int, [*c]u8, c_int) void;
pub extern fn _Xmbtowc([*c]wchar_t, [*c]u8, c_int) c_int;
pub extern fn _Xwctomb([*c]u8, wchar_t) c_int;
pub extern fn XGetEventData(?*Display, [*c]XGenericEventCookie) c_int;
pub extern fn XFreeEventData(?*Display, [*c]XGenericEventCookie) void;
const struct_unnamed_8 = extern struct {
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
};
pub const XSizeHints = extern struct {
    flags: c_long = @import("std").mem.zeroes(c_long),
    x: c_int = @import("std").mem.zeroes(c_int),
    y: c_int = @import("std").mem.zeroes(c_int),
    width: c_int = @import("std").mem.zeroes(c_int),
    height: c_int = @import("std").mem.zeroes(c_int),
    min_width: c_int = @import("std").mem.zeroes(c_int),
    min_height: c_int = @import("std").mem.zeroes(c_int),
    max_width: c_int = @import("std").mem.zeroes(c_int),
    max_height: c_int = @import("std").mem.zeroes(c_int),
    width_inc: c_int = @import("std").mem.zeroes(c_int),
    height_inc: c_int = @import("std").mem.zeroes(c_int),
    min_aspect: struct_unnamed_8 = @import("std").mem.zeroes(struct_unnamed_8),
    max_aspect: struct_unnamed_8 = @import("std").mem.zeroes(struct_unnamed_8),
    base_width: c_int = @import("std").mem.zeroes(c_int),
    base_height: c_int = @import("std").mem.zeroes(c_int),
    win_gravity: c_int = @import("std").mem.zeroes(c_int),
};
pub const XWMHints = extern struct {
    flags: c_long = @import("std").mem.zeroes(c_long),
    input: c_int = @import("std").mem.zeroes(c_int),
    initial_state: c_int = @import("std").mem.zeroes(c_int),
    icon_pixmap: Pixmap = @import("std").mem.zeroes(Pixmap),
    icon_window: Window = @import("std").mem.zeroes(Window),
    icon_x: c_int = @import("std").mem.zeroes(c_int),
    icon_y: c_int = @import("std").mem.zeroes(c_int),
    icon_mask: Pixmap = @import("std").mem.zeroes(Pixmap),
    window_group: XID = @import("std").mem.zeroes(XID),
};
pub const XTextProperty = extern struct {
    value: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    encoding: Atom = @import("std").mem.zeroes(Atom),
    format: c_int = @import("std").mem.zeroes(c_int),
    nitems: c_ulong = @import("std").mem.zeroes(c_ulong),
};
pub const XStringStyle: c_int = 0;
pub const XCompoundTextStyle: c_int = 1;
pub const XTextStyle: c_int = 2;
pub const XStdICCTextStyle: c_int = 3;
pub const XUTF8StringStyle: c_int = 4;
pub const XICCEncodingStyle = c_uint;
pub const XIconSize = extern struct {
    min_width: c_int = @import("std").mem.zeroes(c_int),
    min_height: c_int = @import("std").mem.zeroes(c_int),
    max_width: c_int = @import("std").mem.zeroes(c_int),
    max_height: c_int = @import("std").mem.zeroes(c_int),
    width_inc: c_int = @import("std").mem.zeroes(c_int),
    height_inc: c_int = @import("std").mem.zeroes(c_int),
};
pub const XClassHint = extern struct {
    res_name: [*c]u8 = @import("std").mem.zeroes([*c]u8),
    res_class: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub const struct__XComposeStatus = extern struct {
    compose_ptr: XPointer = @import("std").mem.zeroes(XPointer),
    chars_matched: c_int = @import("std").mem.zeroes(c_int),
};
pub const XComposeStatus = struct__XComposeStatus;
pub const struct__XRegion = opaque {};
pub const Region = ?*struct__XRegion;
pub const XVisualInfo = extern struct {
    visual: [*c]Visual = @import("std").mem.zeroes([*c]Visual),
    visualid: VisualID = @import("std").mem.zeroes(VisualID),
    screen: c_int = @import("std").mem.zeroes(c_int),
    depth: c_int = @import("std").mem.zeroes(c_int),
    class: c_int = @import("std").mem.zeroes(c_int),
    red_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    green_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    blue_mask: c_ulong = @import("std").mem.zeroes(c_ulong),
    colormap_size: c_int = @import("std").mem.zeroes(c_int),
    bits_per_rgb: c_int = @import("std").mem.zeroes(c_int),
};
pub const XStandardColormap = extern struct {
    colormap: Colormap = @import("std").mem.zeroes(Colormap),
    red_max: c_ulong = @import("std").mem.zeroes(c_ulong),
    red_mult: c_ulong = @import("std").mem.zeroes(c_ulong),
    green_max: c_ulong = @import("std").mem.zeroes(c_ulong),
    green_mult: c_ulong = @import("std").mem.zeroes(c_ulong),
    blue_max: c_ulong = @import("std").mem.zeroes(c_ulong),
    blue_mult: c_ulong = @import("std").mem.zeroes(c_ulong),
    base_pixel: c_ulong = @import("std").mem.zeroes(c_ulong),
    visualid: VisualID = @import("std").mem.zeroes(VisualID),
    killid: XID = @import("std").mem.zeroes(XID),
};
pub const XContext = c_int;
pub extern fn XAllocClassHint() [*c]XClassHint;
pub extern fn XAllocIconSize() [*c]XIconSize;
pub extern fn XAllocSizeHints() [*c]XSizeHints;
pub extern fn XAllocStandardColormap() [*c]XStandardColormap;
pub extern fn XAllocWMHints() [*c]XWMHints;
pub extern fn XClipBox(Region, [*c]XRectangle) c_int;
pub extern fn XCreateRegion() Region;
pub extern fn XDefaultString() [*c]const u8;
pub extern fn XDeleteContext(?*Display, XID, XContext) c_int;
pub extern fn XDestroyRegion(Region) c_int;
pub extern fn XEmptyRegion(Region) c_int;
pub extern fn XEqualRegion(Region, Region) c_int;
pub extern fn XFindContext(?*Display, XID, XContext, [*c]XPointer) c_int;
pub extern fn XGetClassHint(?*Display, Window, [*c]XClassHint) c_int;
pub extern fn XGetIconSizes(?*Display, Window, [*c][*c]XIconSize, [*c]c_int) c_int;
pub extern fn XGetNormalHints(?*Display, Window, [*c]XSizeHints) c_int;
pub extern fn XGetRGBColormaps(?*Display, Window, [*c][*c]XStandardColormap, [*c]c_int, Atom) c_int;
pub extern fn XGetSizeHints(?*Display, Window, [*c]XSizeHints, Atom) c_int;
pub extern fn XGetStandardColormap(?*Display, Window, [*c]XStandardColormap, Atom) c_int;
pub extern fn XGetTextProperty(?*Display, Window, [*c]XTextProperty, Atom) c_int;
pub extern fn XGetVisualInfo(?*Display, c_long, [*c]XVisualInfo, [*c]c_int) [*c]XVisualInfo;
pub extern fn XGetWMClientMachine(?*Display, Window, [*c]XTextProperty) c_int;
pub extern fn XGetWMHints(?*Display, Window) [*c]XWMHints;
pub extern fn XGetWMIconName(?*Display, Window, [*c]XTextProperty) c_int;
pub extern fn XGetWMName(?*Display, Window, [*c]XTextProperty) c_int;
pub extern fn XGetWMNormalHints(?*Display, Window, [*c]XSizeHints, [*c]c_long) c_int;
pub extern fn XGetWMSizeHints(?*Display, Window, [*c]XSizeHints, [*c]c_long, Atom) c_int;
pub extern fn XGetZoomHints(?*Display, Window, [*c]XSizeHints) c_int;
pub extern fn XIntersectRegion(Region, Region, Region) c_int;
pub extern fn XConvertCase(KeySym, [*c]KeySym, [*c]KeySym) void;
pub extern fn XLookupString([*c]XKeyEvent, [*c]u8, c_int, [*c]KeySym, [*c]XComposeStatus) c_int;
pub extern fn XMatchVisualInfo(?*Display, c_int, c_int, c_int, [*c]XVisualInfo) c_int;
pub extern fn XOffsetRegion(Region, c_int, c_int) c_int;
pub extern fn XPointInRegion(Region, c_int, c_int) c_int;
pub extern fn XPolygonRegion([*c]XPoint, c_int, c_int) Region;
pub extern fn XRectInRegion(Region, c_int, c_int, c_uint, c_uint) c_int;
pub extern fn XSaveContext(?*Display, XID, XContext, [*c]const u8) c_int;
pub extern fn XSetClassHint(?*Display, Window, [*c]XClassHint) c_int;
pub extern fn XSetIconSizes(?*Display, Window, [*c]XIconSize, c_int) c_int;
pub extern fn XSetNormalHints(?*Display, Window, [*c]XSizeHints) c_int;
pub extern fn XSetRGBColormaps(?*Display, Window, [*c]XStandardColormap, c_int, Atom) void;
pub extern fn XSetSizeHints(?*Display, Window, [*c]XSizeHints, Atom) c_int;
pub extern fn XSetStandardProperties(?*Display, Window, [*c]const u8, [*c]const u8, Pixmap, [*c][*c]u8, c_int, [*c]XSizeHints) c_int;
pub extern fn XSetTextProperty(?*Display, Window, [*c]XTextProperty, Atom) void;
pub extern fn XSetWMClientMachine(?*Display, Window, [*c]XTextProperty) void;
pub extern fn XSetWMHints(?*Display, Window, [*c]XWMHints) c_int;
pub extern fn XSetWMIconName(?*Display, Window, [*c]XTextProperty) void;
pub extern fn XSetWMName(?*Display, Window, [*c]XTextProperty) void;
pub extern fn XSetWMNormalHints(?*Display, Window, [*c]XSizeHints) void;
pub extern fn XSetWMProperties(?*Display, Window, [*c]XTextProperty, [*c]XTextProperty, [*c][*c]u8, c_int, [*c]XSizeHints, [*c]XWMHints, [*c]XClassHint) void;
pub extern fn XmbSetWMProperties(?*Display, Window, [*c]const u8, [*c]const u8, [*c][*c]u8, c_int, [*c]XSizeHints, [*c]XWMHints, [*c]XClassHint) void;
pub extern fn Xutf8SetWMProperties(?*Display, Window, [*c]const u8, [*c]const u8, [*c][*c]u8, c_int, [*c]XSizeHints, [*c]XWMHints, [*c]XClassHint) void;
pub extern fn XSetWMSizeHints(?*Display, Window, [*c]XSizeHints, Atom) void;
pub extern fn XSetRegion(?*Display, GC, Region) c_int;
pub extern fn XSetStandardColormap(?*Display, Window, [*c]XStandardColormap, Atom) void;
pub extern fn XSetZoomHints(?*Display, Window, [*c]XSizeHints) c_int;
pub extern fn XShrinkRegion(Region, c_int, c_int) c_int;
pub extern fn XStringListToTextProperty([*c][*c]u8, c_int, [*c]XTextProperty) c_int;
pub extern fn XSubtractRegion(Region, Region, Region) c_int;
pub extern fn XmbTextListToTextProperty(display: ?*Display, list: [*c][*c]u8, count: c_int, style: XICCEncodingStyle, text_prop_return: [*c]XTextProperty) c_int;
pub extern fn XwcTextListToTextProperty(display: ?*Display, list: [*c][*c]wchar_t, count: c_int, style: XICCEncodingStyle, text_prop_return: [*c]XTextProperty) c_int;
pub extern fn Xutf8TextListToTextProperty(display: ?*Display, list: [*c][*c]u8, count: c_int, style: XICCEncodingStyle, text_prop_return: [*c]XTextProperty) c_int;
pub extern fn XwcFreeStringList(list: [*c][*c]wchar_t) void;
pub extern fn XTextPropertyToStringList([*c]XTextProperty, [*c][*c][*c]u8, [*c]c_int) c_int;
pub extern fn XmbTextPropertyToTextList(display: ?*Display, text_prop: [*c]const XTextProperty, list_return: [*c][*c][*c]u8, count_return: [*c]c_int) c_int;
pub extern fn XwcTextPropertyToTextList(display: ?*Display, text_prop: [*c]const XTextProperty, list_return: [*c][*c][*c]wchar_t, count_return: [*c]c_int) c_int;
pub extern fn Xutf8TextPropertyToTextList(display: ?*Display, text_prop: [*c]const XTextProperty, list_return: [*c][*c][*c]u8, count_return: [*c]c_int) c_int;
pub extern fn XUnionRectWithRegion([*c]XRectangle, Region, Region) c_int;
pub extern fn XUnionRegion(Region, Region, Region) c_int;
pub extern fn XWMGeometry(?*Display, c_int, [*c]const u8, [*c]const u8, c_uint, [*c]XSizeHints, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int, [*c]c_int) c_int;
pub extern fn XXorRegion(Region, Region, Region) c_int;
pub const __llvm__ = @as(c_int, 1);
pub const __clang__ = @as(c_int, 1);
pub const __clang_major__ = @as(c_int, 19);
pub const __clang_minor__ = @as(c_int, 1);
pub const __clang_patchlevel__ = @as(c_int, 7);
pub const __clang_version__ = "19.1.7 (https://github.com/ziglang/zig-bootstrap 1c3c59435891bc9caf8cd1d3783773369d191c5f)";
pub const __GNUC__ = @as(c_int, 4);
pub const __GNUC_MINOR__ = @as(c_int, 2);
pub const __GNUC_PATCHLEVEL__ = @as(c_int, 1);
pub const __GXX_ABI_VERSION = @as(c_int, 1002);
pub const __ATOMIC_RELAXED = @as(c_int, 0);
pub const __ATOMIC_CONSUME = @as(c_int, 1);
pub const __ATOMIC_ACQUIRE = @as(c_int, 2);
pub const __ATOMIC_RELEASE = @as(c_int, 3);
pub const __ATOMIC_ACQ_REL = @as(c_int, 4);
pub const __ATOMIC_SEQ_CST = @as(c_int, 5);
pub const __MEMORY_SCOPE_SYSTEM = @as(c_int, 0);
pub const __MEMORY_SCOPE_DEVICE = @as(c_int, 1);
pub const __MEMORY_SCOPE_WRKGRP = @as(c_int, 2);
pub const __MEMORY_SCOPE_WVFRNT = @as(c_int, 3);
pub const __MEMORY_SCOPE_SINGLE = @as(c_int, 4);
pub const __OPENCL_MEMORY_SCOPE_WORK_ITEM = @as(c_int, 0);
pub const __OPENCL_MEMORY_SCOPE_WORK_GROUP = @as(c_int, 1);
pub const __OPENCL_MEMORY_SCOPE_DEVICE = @as(c_int, 2);
pub const __OPENCL_MEMORY_SCOPE_ALL_SVM_DEVICES = @as(c_int, 3);
pub const __OPENCL_MEMORY_SCOPE_SUB_GROUP = @as(c_int, 4);
pub const __FPCLASS_SNAN = @as(c_int, 0x0001);
pub const __FPCLASS_QNAN = @as(c_int, 0x0002);
pub const __FPCLASS_NEGINF = @as(c_int, 0x0004);
pub const __FPCLASS_NEGNORMAL = @as(c_int, 0x0008);
pub const __FPCLASS_NEGSUBNORMAL = @as(c_int, 0x0010);
pub const __FPCLASS_NEGZERO = @as(c_int, 0x0020);
pub const __FPCLASS_POSZERO = @as(c_int, 0x0040);
pub const __FPCLASS_POSSUBNORMAL = @as(c_int, 0x0080);
pub const __FPCLASS_POSNORMAL = @as(c_int, 0x0100);
pub const __FPCLASS_POSINF = @as(c_int, 0x0200);
pub const __PRAGMA_REDEFINE_EXTNAME = @as(c_int, 1);
pub const __VERSION__ = "Clang 19.1.7 (https://github.com/ziglang/zig-bootstrap 1c3c59435891bc9caf8cd1d3783773369d191c5f)";
pub const __OBJC_BOOL_IS_BOOL = @as(c_int, 0);
pub const __CONSTANT_CFSTRINGS__ = @as(c_int, 1);
pub const __clang_literal_encoding__ = "UTF-8";
pub const __clang_wide_literal_encoding__ = "UTF-32";
pub const __ORDER_LITTLE_ENDIAN__ = @as(c_int, 1234);
pub const __ORDER_BIG_ENDIAN__ = @as(c_int, 4321);
pub const __ORDER_PDP_ENDIAN__ = @as(c_int, 3412);
pub const __BYTE_ORDER__ = __ORDER_LITTLE_ENDIAN__;
pub const __LITTLE_ENDIAN__ = @as(c_int, 1);
pub const _LP64 = @as(c_int, 1);
pub const __LP64__ = @as(c_int, 1);
pub const __CHAR_BIT__ = @as(c_int, 8);
pub const __BOOL_WIDTH__ = @as(c_int, 8);
pub const __SHRT_WIDTH__ = @as(c_int, 16);
pub const __INT_WIDTH__ = @as(c_int, 32);
pub const __LONG_WIDTH__ = @as(c_int, 64);
pub const __LLONG_WIDTH__ = @as(c_int, 64);
pub const __BITINT_MAXWIDTH__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 8388608, .decimal);
pub const __SCHAR_MAX__ = @as(c_int, 127);
pub const __SHRT_MAX__ = @as(c_int, 32767);
pub const __INT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __LONG_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __LONG_LONG_MAX__ = @as(c_longlong, 9223372036854775807);
pub const __WCHAR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __WCHAR_WIDTH__ = @as(c_int, 32);
pub const __WINT_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __WINT_WIDTH__ = @as(c_int, 32);
pub const __INTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTMAX_WIDTH__ = @as(c_int, 64);
pub const __SIZE_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __SIZE_WIDTH__ = @as(c_int, 64);
pub const __UINTMAX_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTMAX_WIDTH__ = @as(c_int, 64);
pub const __PTRDIFF_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __PTRDIFF_WIDTH__ = @as(c_int, 64);
pub const __INTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INTPTR_WIDTH__ = @as(c_int, 64);
pub const __UINTPTR_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINTPTR_WIDTH__ = @as(c_int, 64);
pub const __SIZEOF_DOUBLE__ = @as(c_int, 8);
pub const __SIZEOF_FLOAT__ = @as(c_int, 4);
pub const __SIZEOF_INT__ = @as(c_int, 4);
pub const __SIZEOF_LONG__ = @as(c_int, 8);
pub const __SIZEOF_LONG_DOUBLE__ = @as(c_int, 16);
pub const __SIZEOF_LONG_LONG__ = @as(c_int, 8);
pub const __SIZEOF_POINTER__ = @as(c_int, 8);
pub const __SIZEOF_SHORT__ = @as(c_int, 2);
pub const __SIZEOF_PTRDIFF_T__ = @as(c_int, 8);
pub const __SIZEOF_SIZE_T__ = @as(c_int, 8);
pub const __SIZEOF_WCHAR_T__ = @as(c_int, 4);
pub const __SIZEOF_WINT_T__ = @as(c_int, 4);
pub const __SIZEOF_INT128__ = @as(c_int, 16);
pub const __INTMAX_TYPE__ = c_long;
pub const __INTMAX_FMTd__ = "ld";
pub const __INTMAX_FMTi__ = "li";
pub const __INTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):95:9
pub const __UINTMAX_TYPE__ = c_ulong;
pub const __UINTMAX_FMTo__ = "lo";
pub const __UINTMAX_FMTu__ = "lu";
pub const __UINTMAX_FMTx__ = "lx";
pub const __UINTMAX_FMTX__ = "lX";
pub const __UINTMAX_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):101:9
pub const __PTRDIFF_TYPE__ = c_long;
pub const __PTRDIFF_FMTd__ = "ld";
pub const __PTRDIFF_FMTi__ = "li";
pub const __INTPTR_TYPE__ = c_long;
pub const __INTPTR_FMTd__ = "ld";
pub const __INTPTR_FMTi__ = "li";
pub const __SIZE_TYPE__ = c_ulong;
pub const __SIZE_FMTo__ = "lo";
pub const __SIZE_FMTu__ = "lu";
pub const __SIZE_FMTx__ = "lx";
pub const __SIZE_FMTX__ = "lX";
pub const __WCHAR_TYPE__ = c_int;
pub const __WINT_TYPE__ = c_uint;
pub const __SIG_ATOMIC_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __SIG_ATOMIC_WIDTH__ = @as(c_int, 32);
pub const __CHAR16_TYPE__ = c_ushort;
pub const __CHAR32_TYPE__ = c_uint;
pub const __UINTPTR_TYPE__ = c_ulong;
pub const __UINTPTR_FMTo__ = "lo";
pub const __UINTPTR_FMTu__ = "lu";
pub const __UINTPTR_FMTx__ = "lx";
pub const __UINTPTR_FMTX__ = "lX";
pub const __FLT16_DENORM_MIN__ = @as(f16, 5.9604644775390625e-8);
pub const __FLT16_NORM_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT16_DIG__ = @as(c_int, 3);
pub const __FLT16_DECIMAL_DIG__ = @as(c_int, 5);
pub const __FLT16_EPSILON__ = @as(f16, 9.765625e-4);
pub const __FLT16_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT16_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT16_MANT_DIG__ = @as(c_int, 11);
pub const __FLT16_MAX_10_EXP__ = @as(c_int, 4);
pub const __FLT16_MAX_EXP__ = @as(c_int, 16);
pub const __FLT16_MAX__ = @as(f16, 6.5504e+4);
pub const __FLT16_MIN_10_EXP__ = -@as(c_int, 4);
pub const __FLT16_MIN_EXP__ = -@as(c_int, 13);
pub const __FLT16_MIN__ = @as(f16, 6.103515625e-5);
pub const __FLT_DENORM_MIN__ = @as(f32, 1.40129846e-45);
pub const __FLT_NORM_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_HAS_DENORM__ = @as(c_int, 1);
pub const __FLT_DIG__ = @as(c_int, 6);
pub const __FLT_DECIMAL_DIG__ = @as(c_int, 9);
pub const __FLT_EPSILON__ = @as(f32, 1.19209290e-7);
pub const __FLT_HAS_INFINITY__ = @as(c_int, 1);
pub const __FLT_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __FLT_MANT_DIG__ = @as(c_int, 24);
pub const __FLT_MAX_10_EXP__ = @as(c_int, 38);
pub const __FLT_MAX_EXP__ = @as(c_int, 128);
pub const __FLT_MAX__ = @as(f32, 3.40282347e+38);
pub const __FLT_MIN_10_EXP__ = -@as(c_int, 37);
pub const __FLT_MIN_EXP__ = -@as(c_int, 125);
pub const __FLT_MIN__ = @as(f32, 1.17549435e-38);
pub const __DBL_DENORM_MIN__ = @as(f64, 4.9406564584124654e-324);
pub const __DBL_NORM_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_HAS_DENORM__ = @as(c_int, 1);
pub const __DBL_DIG__ = @as(c_int, 15);
pub const __DBL_DECIMAL_DIG__ = @as(c_int, 17);
pub const __DBL_EPSILON__ = @as(f64, 2.2204460492503131e-16);
pub const __DBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __DBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __DBL_MANT_DIG__ = @as(c_int, 53);
pub const __DBL_MAX_10_EXP__ = @as(c_int, 308);
pub const __DBL_MAX_EXP__ = @as(c_int, 1024);
pub const __DBL_MAX__ = @as(f64, 1.7976931348623157e+308);
pub const __DBL_MIN_10_EXP__ = -@as(c_int, 307);
pub const __DBL_MIN_EXP__ = -@as(c_int, 1021);
pub const __DBL_MIN__ = @as(f64, 2.2250738585072014e-308);
pub const __LDBL_DENORM_MIN__ = @as(c_longdouble, 3.64519953188247460253e-4951);
pub const __LDBL_NORM_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_HAS_DENORM__ = @as(c_int, 1);
pub const __LDBL_DIG__ = @as(c_int, 18);
pub const __LDBL_DECIMAL_DIG__ = @as(c_int, 21);
pub const __LDBL_EPSILON__ = @as(c_longdouble, 1.08420217248550443401e-19);
pub const __LDBL_HAS_INFINITY__ = @as(c_int, 1);
pub const __LDBL_HAS_QUIET_NAN__ = @as(c_int, 1);
pub const __LDBL_MANT_DIG__ = @as(c_int, 64);
pub const __LDBL_MAX_10_EXP__ = @as(c_int, 4932);
pub const __LDBL_MAX_EXP__ = @as(c_int, 16384);
pub const __LDBL_MAX__ = @as(c_longdouble, 1.18973149535723176502e+4932);
pub const __LDBL_MIN_10_EXP__ = -@as(c_int, 4931);
pub const __LDBL_MIN_EXP__ = -@as(c_int, 16381);
pub const __LDBL_MIN__ = @as(c_longdouble, 3.36210314311209350626e-4932);
pub const __POINTER_WIDTH__ = @as(c_int, 64);
pub const __BIGGEST_ALIGNMENT__ = @as(c_int, 16);
pub const __WINT_UNSIGNED__ = @as(c_int, 1);
pub const __INT8_TYPE__ = i8;
pub const __INT8_FMTd__ = "hhd";
pub const __INT8_FMTi__ = "hhi";
pub const __INT8_C_SUFFIX__ = "";
pub const __INT16_TYPE__ = c_short;
pub const __INT16_FMTd__ = "hd";
pub const __INT16_FMTi__ = "hi";
pub const __INT16_C_SUFFIX__ = "";
pub const __INT32_TYPE__ = c_int;
pub const __INT32_FMTd__ = "d";
pub const __INT32_FMTi__ = "i";
pub const __INT32_C_SUFFIX__ = "";
pub const __INT64_TYPE__ = c_long;
pub const __INT64_FMTd__ = "ld";
pub const __INT64_FMTi__ = "li";
pub const __INT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `L`");
// (no file):202:9
pub const __UINT8_TYPE__ = u8;
pub const __UINT8_FMTo__ = "hho";
pub const __UINT8_FMTu__ = "hhu";
pub const __UINT8_FMTx__ = "hhx";
pub const __UINT8_FMTX__ = "hhX";
pub const __UINT8_C_SUFFIX__ = "";
pub const __UINT8_MAX__ = @as(c_int, 255);
pub const __INT8_MAX__ = @as(c_int, 127);
pub const __UINT16_TYPE__ = c_ushort;
pub const __UINT16_FMTo__ = "ho";
pub const __UINT16_FMTu__ = "hu";
pub const __UINT16_FMTx__ = "hx";
pub const __UINT16_FMTX__ = "hX";
pub const __UINT16_C_SUFFIX__ = "";
pub const __UINT16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __INT16_MAX__ = @as(c_int, 32767);
pub const __UINT32_TYPE__ = c_uint;
pub const __UINT32_FMTo__ = "o";
pub const __UINT32_FMTu__ = "u";
pub const __UINT32_FMTx__ = "x";
pub const __UINT32_FMTX__ = "X";
pub const __UINT32_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `U`");
// (no file):224:9
pub const __UINT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __INT32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __UINT64_TYPE__ = c_ulong;
pub const __UINT64_FMTo__ = "lo";
pub const __UINT64_FMTu__ = "lu";
pub const __UINT64_FMTx__ = "lx";
pub const __UINT64_FMTX__ = "lX";
pub const __UINT64_C_SUFFIX__ = @compileError("unable to translate macro: undefined identifier `UL`");
// (no file):232:9
pub const __UINT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __INT64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST8_TYPE__ = i8;
pub const __INT_LEAST8_MAX__ = @as(c_int, 127);
pub const __INT_LEAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_LEAST8_FMTd__ = "hhd";
pub const __INT_LEAST8_FMTi__ = "hhi";
pub const __UINT_LEAST8_TYPE__ = u8;
pub const __UINT_LEAST8_MAX__ = @as(c_int, 255);
pub const __UINT_LEAST8_FMTo__ = "hho";
pub const __UINT_LEAST8_FMTu__ = "hhu";
pub const __UINT_LEAST8_FMTx__ = "hhx";
pub const __UINT_LEAST8_FMTX__ = "hhX";
pub const __INT_LEAST16_TYPE__ = c_short;
pub const __INT_LEAST16_MAX__ = @as(c_int, 32767);
pub const __INT_LEAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_LEAST16_FMTd__ = "hd";
pub const __INT_LEAST16_FMTi__ = "hi";
pub const __UINT_LEAST16_TYPE__ = c_ushort;
pub const __UINT_LEAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_LEAST16_FMTo__ = "ho";
pub const __UINT_LEAST16_FMTu__ = "hu";
pub const __UINT_LEAST16_FMTx__ = "hx";
pub const __UINT_LEAST16_FMTX__ = "hX";
pub const __INT_LEAST32_TYPE__ = c_int;
pub const __INT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_LEAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_LEAST32_FMTd__ = "d";
pub const __INT_LEAST32_FMTi__ = "i";
pub const __UINT_LEAST32_TYPE__ = c_uint;
pub const __UINT_LEAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_LEAST32_FMTo__ = "o";
pub const __UINT_LEAST32_FMTu__ = "u";
pub const __UINT_LEAST32_FMTx__ = "x";
pub const __UINT_LEAST32_FMTX__ = "X";
pub const __INT_LEAST64_TYPE__ = c_long;
pub const __INT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_LEAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_LEAST64_FMTd__ = "ld";
pub const __INT_LEAST64_FMTi__ = "li";
pub const __UINT_LEAST64_TYPE__ = c_ulong;
pub const __UINT_LEAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_LEAST64_FMTo__ = "lo";
pub const __UINT_LEAST64_FMTu__ = "lu";
pub const __UINT_LEAST64_FMTx__ = "lx";
pub const __UINT_LEAST64_FMTX__ = "lX";
pub const __INT_FAST8_TYPE__ = i8;
pub const __INT_FAST8_MAX__ = @as(c_int, 127);
pub const __INT_FAST8_WIDTH__ = @as(c_int, 8);
pub const __INT_FAST8_FMTd__ = "hhd";
pub const __INT_FAST8_FMTi__ = "hhi";
pub const __UINT_FAST8_TYPE__ = u8;
pub const __UINT_FAST8_MAX__ = @as(c_int, 255);
pub const __UINT_FAST8_FMTo__ = "hho";
pub const __UINT_FAST8_FMTu__ = "hhu";
pub const __UINT_FAST8_FMTx__ = "hhx";
pub const __UINT_FAST8_FMTX__ = "hhX";
pub const __INT_FAST16_TYPE__ = c_short;
pub const __INT_FAST16_MAX__ = @as(c_int, 32767);
pub const __INT_FAST16_WIDTH__ = @as(c_int, 16);
pub const __INT_FAST16_FMTd__ = "hd";
pub const __INT_FAST16_FMTi__ = "hi";
pub const __UINT_FAST16_TYPE__ = c_ushort;
pub const __UINT_FAST16_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 65535, .decimal);
pub const __UINT_FAST16_FMTo__ = "ho";
pub const __UINT_FAST16_FMTu__ = "hu";
pub const __UINT_FAST16_FMTx__ = "hx";
pub const __UINT_FAST16_FMTX__ = "hX";
pub const __INT_FAST32_TYPE__ = c_int;
pub const __INT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 2147483647, .decimal);
pub const __INT_FAST32_WIDTH__ = @as(c_int, 32);
pub const __INT_FAST32_FMTd__ = "d";
pub const __INT_FAST32_FMTi__ = "i";
pub const __UINT_FAST32_TYPE__ = c_uint;
pub const __UINT_FAST32_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_uint, 4294967295, .decimal);
pub const __UINT_FAST32_FMTo__ = "o";
pub const __UINT_FAST32_FMTu__ = "u";
pub const __UINT_FAST32_FMTx__ = "x";
pub const __UINT_FAST32_FMTX__ = "X";
pub const __INT_FAST64_TYPE__ = c_long;
pub const __INT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_long, 9223372036854775807, .decimal);
pub const __INT_FAST64_WIDTH__ = @as(c_int, 64);
pub const __INT_FAST64_FMTd__ = "ld";
pub const __INT_FAST64_FMTi__ = "li";
pub const __UINT_FAST64_TYPE__ = c_ulong;
pub const __UINT_FAST64_MAX__ = @import("std").zig.c_translation.promoteIntLiteral(c_ulong, 18446744073709551615, .decimal);
pub const __UINT_FAST64_FMTo__ = "lo";
pub const __UINT_FAST64_FMTu__ = "lu";
pub const __UINT_FAST64_FMTx__ = "lx";
pub const __UINT_FAST64_FMTX__ = "lX";
pub const __USER_LABEL_PREFIX__ = "";
pub const __FINITE_MATH_ONLY__ = @as(c_int, 0);
pub const __GNUC_STDC_INLINE__ = @as(c_int, 1);
pub const __GCC_ATOMIC_TEST_AND_SET_TRUEVAL = @as(c_int, 1);
pub const __GCC_DESTRUCTIVE_SIZE = @as(c_int, 64);
pub const __GCC_CONSTRUCTIVE_SIZE = @as(c_int, 64);
pub const __CLANG_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __CLANG_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_BOOL_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR16_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_CHAR32_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_WCHAR_T_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_SHORT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_INT_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_LLONG_LOCK_FREE = @as(c_int, 2);
pub const __GCC_ATOMIC_POINTER_LOCK_FREE = @as(c_int, 2);
pub const __NO_INLINE__ = @as(c_int, 1);
pub const __PIC__ = @as(c_int, 2);
pub const __pic__ = @as(c_int, 2);
pub const __FLT_RADIX__ = @as(c_int, 2);
pub const __DECIMAL_DIG__ = __LDBL_DECIMAL_DIG__;
pub const __ELF__ = @as(c_int, 1);
pub const __GCC_ASM_FLAG_OUTPUTS__ = @as(c_int, 1);
pub const __code_model_small__ = @as(c_int, 1);
pub const __amd64__ = @as(c_int, 1);
pub const __amd64 = @as(c_int, 1);
pub const __x86_64 = @as(c_int, 1);
pub const __x86_64__ = @as(c_int, 1);
pub const __SEG_GS = @as(c_int, 1);
pub const __SEG_FS = @as(c_int, 1);
pub const __seg_gs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):365:9
pub const __seg_fs = @compileError("unable to translate macro: undefined identifier `address_space`");
// (no file):366:9
pub const __corei7 = @as(c_int, 1);
pub const __corei7__ = @as(c_int, 1);
pub const __tune_corei7__ = @as(c_int, 1);
pub const __REGISTER_PREFIX__ = "";
pub const __NO_MATH_INLINES = @as(c_int, 1);
pub const __AES__ = @as(c_int, 1);
pub const __PCLMUL__ = @as(c_int, 1);
pub const __LAHF_SAHF__ = @as(c_int, 1);
pub const __LZCNT__ = @as(c_int, 1);
pub const __RDRND__ = @as(c_int, 1);
pub const __FSGSBASE__ = @as(c_int, 1);
pub const __BMI__ = @as(c_int, 1);
pub const __BMI2__ = @as(c_int, 1);
pub const __POPCNT__ = @as(c_int, 1);
pub const __PRFCHW__ = @as(c_int, 1);
pub const __RDSEED__ = @as(c_int, 1);
pub const __ADX__ = @as(c_int, 1);
pub const __MOVBE__ = @as(c_int, 1);
pub const __FMA__ = @as(c_int, 1);
pub const __F16C__ = @as(c_int, 1);
pub const __FXSR__ = @as(c_int, 1);
pub const __XSAVE__ = @as(c_int, 1);
pub const __XSAVEOPT__ = @as(c_int, 1);
pub const __XSAVEC__ = @as(c_int, 1);
pub const __XSAVES__ = @as(c_int, 1);
pub const __PKU__ = @as(c_int, 1);
pub const __CLFLUSHOPT__ = @as(c_int, 1);
pub const __INVPCID__ = @as(c_int, 1);
pub const __CRC32__ = @as(c_int, 1);
pub const __AVX2__ = @as(c_int, 1);
pub const __AVX__ = @as(c_int, 1);
pub const __SSE4_2__ = @as(c_int, 1);
pub const __SSE4_1__ = @as(c_int, 1);
pub const __SSSE3__ = @as(c_int, 1);
pub const __SSE3__ = @as(c_int, 1);
pub const __SSE2__ = @as(c_int, 1);
pub const __SSE2_MATH__ = @as(c_int, 1);
pub const __SSE__ = @as(c_int, 1);
pub const __SSE_MATH__ = @as(c_int, 1);
pub const __MMX__ = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_1 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_2 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_4 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_8 = @as(c_int, 1);
pub const __GCC_HAVE_SYNC_COMPARE_AND_SWAP_16 = @as(c_int, 1);
pub const __SIZEOF_FLOAT128__ = @as(c_int, 16);
pub const unix = @as(c_int, 1);
pub const __unix = @as(c_int, 1);
pub const __unix__ = @as(c_int, 1);
pub const linux = @as(c_int, 1);
pub const __linux = @as(c_int, 1);
pub const __linux__ = @as(c_int, 1);
pub const __gnu_linux__ = @as(c_int, 1);
pub const __FLOAT128__ = @as(c_int, 1);
pub const __STDC__ = @as(c_int, 1);
pub const __STDC_HOSTED__ = @as(c_int, 1);
pub const __STDC_VERSION__ = @as(c_long, 201710);
pub const __STDC_UTF_16__ = @as(c_int, 1);
pub const __STDC_UTF_32__ = @as(c_int, 1);
pub const __STDC_EMBED_NOT_FOUND__ = @as(c_int, 0);
pub const __STDC_EMBED_FOUND__ = @as(c_int, 1);
pub const __STDC_EMBED_EMPTY__ = @as(c_int, 2);
pub const _DEBUG = @as(c_int, 1);
pub const __GCC_HAVE_DWARF2_CFI_ASM = @as(c_int, 1);
pub const _X11_XLIB_H_ = "";
pub const XlibSpecificationRelease = @as(c_int, 6);
pub const _SYS_TYPES_H = @as(c_int, 1);
pub const _FEATURES_H = @as(c_int, 1);
pub const __KERNEL_STRICT_NAMES = "";
pub inline fn __GNUC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GNUC__ << @as(c_int, 16)) + __GNUC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub inline fn __glibc_clang_prereq(maj: anytype, min: anytype) @TypeOf(((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__clang_major__ << @as(c_int, 16)) + __clang_minor__) >= ((maj << @as(c_int, 16)) + min);
}
pub const __GLIBC_USE = @compileError("unable to translate macro: undefined identifier `__GLIBC_USE_`");
// /usr/include/features.h:186:9
pub const _DEFAULT_SOURCE = @as(c_int, 1);
pub const __GLIBC_USE_ISOC2X = @as(c_int, 0);
pub const __USE_ISOC11 = @as(c_int, 1);
pub const __USE_ISOC99 = @as(c_int, 1);
pub const __USE_ISOC95 = @as(c_int, 1);
pub const __USE_POSIX_IMPLICITLY = @as(c_int, 1);
pub const _POSIX_SOURCE = @as(c_int, 1);
pub const _POSIX_C_SOURCE = @as(c_long, 200809);
pub const __USE_POSIX = @as(c_int, 1);
pub const __USE_POSIX2 = @as(c_int, 1);
pub const __USE_POSIX199309 = @as(c_int, 1);
pub const __USE_POSIX199506 = @as(c_int, 1);
pub const __USE_XOPEN2K = @as(c_int, 1);
pub const __USE_XOPEN2K8 = @as(c_int, 1);
pub const _ATFILE_SOURCE = @as(c_int, 1);
pub const __WORDSIZE = @as(c_int, 64);
pub const __WORDSIZE_TIME64_COMPAT32 = @as(c_int, 1);
pub const __SYSCALL_WORDSIZE = @as(c_int, 64);
pub const __TIMESIZE = __WORDSIZE;
pub const __USE_MISC = @as(c_int, 1);
pub const __USE_ATFILE = @as(c_int, 1);
pub const __USE_FORTIFY_LEVEL = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_GETS = @as(c_int, 0);
pub const __GLIBC_USE_DEPRECATED_SCANF = @as(c_int, 0);
pub const _STDC_PREDEF_H = @as(c_int, 1);
pub const __STDC_IEC_559__ = @as(c_int, 1);
pub const __STDC_IEC_60559_BFP__ = @as(c_long, 201404);
pub const __STDC_IEC_559_COMPLEX__ = @as(c_int, 1);
pub const __STDC_IEC_60559_COMPLEX__ = @as(c_long, 201404);
pub const __STDC_ISO_10646__ = @as(c_long, 201706);
pub const __GNU_LIBRARY__ = @as(c_int, 6);
pub const __GLIBC__ = @as(c_int, 2);
pub const __GLIBC_MINOR__ = @as(c_int, 35);
pub inline fn __GLIBC_PREREQ(maj: anytype, min: anytype) @TypeOf(((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min)) {
    _ = &maj;
    _ = &min;
    return ((__GLIBC__ << @as(c_int, 16)) + __GLIBC_MINOR__) >= ((maj << @as(c_int, 16)) + min);
}
pub const _SYS_CDEFS_H = @as(c_int, 1);
pub const __glibc_has_attribute = @compileError("unable to translate macro: undefined identifier `__has_attribute`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:45:10
pub inline fn __glibc_has_builtin(name: anytype) @TypeOf(__has_builtin(name)) {
    _ = &name;
    return __has_builtin(name);
}
pub const __glibc_has_extension = @compileError("unable to translate macro: undefined identifier `__has_extension`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:55:10
pub const __LEAF = "";
pub const __LEAF_ATTR = "";
pub const __THROW = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:79:11
pub const __THROWNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:80:11
pub const __NTH = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:81:11
pub const __NTHNL = @compileError("unable to translate macro: undefined identifier `__nothrow__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:82:11
pub inline fn __P(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub inline fn __PMT(args: anytype) @TypeOf(args) {
    _ = &args;
    return args;
}
pub const __CONCAT = @compileError("unable to translate C expr: unexpected token '##'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:124:9
pub const __STRING = @compileError("unable to translate C expr: unexpected token '#'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:125:9
pub const __ptr_t = ?*anyopaque;
pub const __BEGIN_DECLS = "";
pub const __END_DECLS = "";
pub inline fn __bos(ptr: anytype) @TypeOf(__builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1))) {
    _ = &ptr;
    return __builtin_object_size(ptr, __USE_FORTIFY_LEVEL > @as(c_int, 1));
}
pub inline fn __bos0(ptr: anytype) @TypeOf(__builtin_object_size(ptr, @as(c_int, 0))) {
    _ = &ptr;
    return __builtin_object_size(ptr, @as(c_int, 0));
}
pub inline fn __glibc_objsize0(__o: anytype) @TypeOf(__bos0(__o)) {
    _ = &__o;
    return __bos0(__o);
}
pub inline fn __glibc_objsize(__o: anytype) @TypeOf(__bos(__o)) {
    _ = &__o;
    return __bos(__o);
}
pub inline fn __glibc_safe_len_cond(__l: anytype, __s: anytype, __osz: anytype) @TypeOf(__l <= @import("std").zig.c_translation.MacroArithmetic.div(__osz, __s)) {
    _ = &__l;
    _ = &__s;
    _ = &__osz;
    return __l <= @import("std").zig.c_translation.MacroArithmetic.div(__osz, __s);
}
pub const __glibc_unsigned_or_positive = @compileError("unable to translate C expr: unexpected token '__typeof'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:160:9
pub inline fn __glibc_safe_or_unknown_len(__l: anytype, __s: anytype, __osz: anytype) @TypeOf(((__glibc_unsigned_or_positive(__l) != 0) and (__builtin_constant_p(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz)) != 0)) and (__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz) != 0)) {
    _ = &__l;
    _ = &__s;
    _ = &__osz;
    return ((__glibc_unsigned_or_positive(__l) != 0) and (__builtin_constant_p(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz)) != 0)) and (__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz) != 0);
}
pub inline fn __glibc_unsafe_len(__l: anytype, __s: anytype, __osz: anytype) @TypeOf(((__glibc_unsigned_or_positive(__l) != 0) and (__builtin_constant_p(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz)) != 0)) and !(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz) != 0)) {
    _ = &__l;
    _ = &__s;
    _ = &__osz;
    return ((__glibc_unsigned_or_positive(__l) != 0) and (__builtin_constant_p(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz)) != 0)) and !(__glibc_safe_len_cond(__SIZE_TYPE__(__l), __s, __osz) != 0);
}
pub const __glibc_fortify = @compileError("unable to translate C expr: expected ')' instead got '...'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:185:9
pub const __glibc_fortify_n = @compileError("unable to translate C expr: expected ')' instead got '...'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:195:9
pub const __warnattr = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:207:10
pub const __errordecl = @compileError("unable to translate C expr: unexpected token 'extern'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:208:10
pub const __flexarr = @compileError("unable to translate C expr: unexpected token '['");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:216:10
pub const __glibc_c99_flexarr_available = @as(c_int, 1);
pub const __REDIRECT = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:247:10
pub const __REDIRECT_NTH = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:254:11
pub const __REDIRECT_NTHNL = @compileError("unable to translate C expr: unexpected token '__asm__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:256:11
pub const __ASMNAME = @compileError("unable to translate C expr: unexpected token ','");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:259:10
pub inline fn __ASMNAME2(prefix: anytype, cname: anytype) @TypeOf(__STRING(prefix) ++ cname) {
    _ = &prefix;
    _ = &cname;
    return __STRING(prefix) ++ cname;
}
pub const __attribute_malloc__ = @compileError("unable to translate macro: undefined identifier `__malloc__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:281:10
pub const __attribute_alloc_size__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:292:10
pub const __attribute_alloc_align__ = @compileError("unable to translate macro: undefined identifier `__alloc_align__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:298:10
pub const __attribute_pure__ = @compileError("unable to translate macro: undefined identifier `__pure__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:308:10
pub const __attribute_const__ = @compileError("unable to translate C expr: unexpected token '__attribute__'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:315:10
pub const __attribute_maybe_unused__ = @compileError("unable to translate macro: undefined identifier `__unused__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:321:10
pub const __attribute_used__ = @compileError("unable to translate macro: undefined identifier `__used__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:330:10
pub const __attribute_noinline__ = @compileError("unable to translate macro: undefined identifier `__noinline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:331:10
pub const __attribute_deprecated__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:339:10
pub const __attribute_deprecated_msg__ = @compileError("unable to translate macro: undefined identifier `__deprecated__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:349:10
pub const __attribute_format_arg__ = @compileError("unable to translate macro: undefined identifier `__format_arg__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:362:10
pub const __attribute_format_strfmon__ = @compileError("unable to translate macro: undefined identifier `__format__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:372:10
pub const __attribute_nonnull__ = @compileError("unable to translate macro: undefined identifier `__nonnull__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:384:11
pub inline fn __nonnull(params: anytype) @TypeOf(__attribute_nonnull__(params)) {
    _ = &params;
    return __attribute_nonnull__(params);
}
pub const __returns_nonnull = @compileError("unable to translate macro: undefined identifier `__returns_nonnull__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:397:10
pub const __attribute_warn_unused_result__ = @compileError("unable to translate macro: undefined identifier `__warn_unused_result__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:406:10
pub const __wur = "";
pub const __always_inline = @compileError("unable to translate macro: undefined identifier `__always_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:424:10
pub const __attribute_artificial__ = @compileError("unable to translate macro: undefined identifier `__artificial__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:433:10
pub const __extern_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:451:11
pub const __extern_always_inline = @compileError("unable to translate macro: undefined identifier `__gnu_inline__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:452:11
pub const __fortify_function = __extern_always_inline ++ __attribute_artificial__;
pub const __restrict_arr = @compileError("unable to translate C expr: unexpected token '__restrict'");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:495:10
pub inline fn __glibc_unlikely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 0))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 0));
}
pub inline fn __glibc_likely(cond: anytype) @TypeOf(__builtin_expect(cond, @as(c_int, 1))) {
    _ = &cond;
    return __builtin_expect(cond, @as(c_int, 1));
}
pub const __attribute_nonstring__ = "";
pub const __attribute_copy__ = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:544:10
pub const __LDOUBLE_REDIRECTS_TO_FLOAT128_ABI = @as(c_int, 0);
pub inline fn __LDBL_REDIR1(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR(name: anytype, proto: anytype) @TypeOf(name ++ proto) {
    _ = &name;
    _ = &proto;
    return name ++ proto;
}
pub inline fn __LDBL_REDIR1_NTH(name: anytype, proto: anytype, alias: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return name ++ proto ++ __THROW;
}
pub inline fn __LDBL_REDIR_NTH(name: anytype, proto: anytype) @TypeOf(name ++ proto ++ __THROW) {
    _ = &name;
    _ = &proto;
    return name ++ proto ++ __THROW;
}
pub const __LDBL_REDIR2_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:620:10
pub const __LDBL_REDIR_DECL = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:621:10
pub inline fn __REDIRECT_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT(name, proto, alias);
}
pub inline fn __REDIRECT_NTH_LDBL(name: anytype, proto: anytype, alias: anytype) @TypeOf(__REDIRECT_NTH(name, proto, alias)) {
    _ = &name;
    _ = &proto;
    _ = &alias;
    return __REDIRECT_NTH(name, proto, alias);
}
pub const __glibc_macro_warning1 = @compileError("unable to translate macro: undefined identifier `_Pragma`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:635:10
pub const __glibc_macro_warning = @compileError("unable to translate macro: undefined identifier `GCC`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:636:10
pub const __HAVE_GENERIC_SELECTION = @as(c_int, 1);
pub const __fortified_attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:681:11
pub const __attr_access = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:682:11
pub const __attr_access_none = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:683:11
pub const __attr_dealloc = @compileError("unable to translate C expr: unexpected token ''");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:693:10
pub const __attr_dealloc_free = "";
pub const __attribute_returns_twice__ = @compileError("unable to translate macro: undefined identifier `__returns_twice__`");
// /usr/include/x86_64-linux-gnu/sys/cdefs.h:700:10
pub const __stub___compat_bdflush = "";
pub const __stub_chflags = "";
pub const __stub_fchflags = "";
pub const __stub_gtty = "";
pub const __stub_revoke = "";
pub const __stub_setlogin = "";
pub const __stub_sigreturn = "";
pub const __stub_stty = "";
pub const _BITS_TYPES_H = @as(c_int, 1);
pub const __S16_TYPE = c_short;
pub const __U16_TYPE = c_ushort;
pub const __S32_TYPE = c_int;
pub const __U32_TYPE = c_uint;
pub const __SLONGWORD_TYPE = c_long;
pub const __ULONGWORD_TYPE = c_ulong;
pub const __SQUAD_TYPE = c_long;
pub const __UQUAD_TYPE = c_ulong;
pub const __SWORD_TYPE = c_long;
pub const __UWORD_TYPE = c_ulong;
pub const __SLONG32_TYPE = c_int;
pub const __ULONG32_TYPE = c_uint;
pub const __S64_TYPE = c_long;
pub const __U64_TYPE = c_ulong;
pub const __STD_TYPE = @compileError("unable to translate C expr: unexpected token 'typedef'");
// /usr/include/x86_64-linux-gnu/bits/types.h:137:10
pub const _BITS_TYPESIZES_H = @as(c_int, 1);
pub const __SYSCALL_SLONG_TYPE = __SLONGWORD_TYPE;
pub const __SYSCALL_ULONG_TYPE = __ULONGWORD_TYPE;
pub const __DEV_T_TYPE = __UQUAD_TYPE;
pub const __UID_T_TYPE = __U32_TYPE;
pub const __GID_T_TYPE = __U32_TYPE;
pub const __INO_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __INO64_T_TYPE = __UQUAD_TYPE;
pub const __MODE_T_TYPE = __U32_TYPE;
pub const __NLINK_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSWORD_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __OFF64_T_TYPE = __SQUAD_TYPE;
pub const __PID_T_TYPE = __S32_TYPE;
pub const __RLIM_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __RLIM64_T_TYPE = __UQUAD_TYPE;
pub const __BLKCNT_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __BLKCNT64_T_TYPE = __SQUAD_TYPE;
pub const __FSBLKCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSBLKCNT64_T_TYPE = __UQUAD_TYPE;
pub const __FSFILCNT_T_TYPE = __SYSCALL_ULONG_TYPE;
pub const __FSFILCNT64_T_TYPE = __UQUAD_TYPE;
pub const __ID_T_TYPE = __U32_TYPE;
pub const __CLOCK_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __TIME_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __USECONDS_T_TYPE = __U32_TYPE;
pub const __SUSECONDS_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __SUSECONDS64_T_TYPE = __SQUAD_TYPE;
pub const __DADDR_T_TYPE = __S32_TYPE;
pub const __KEY_T_TYPE = __S32_TYPE;
pub const __CLOCKID_T_TYPE = __S32_TYPE;
pub const __TIMER_T_TYPE = ?*anyopaque;
pub const __BLKSIZE_T_TYPE = __SYSCALL_SLONG_TYPE;
pub const __FSID_T_TYPE = @compileError("unable to translate macro: undefined identifier `__val`");
// /usr/include/x86_64-linux-gnu/bits/typesizes.h:73:9
pub const __SSIZE_T_TYPE = __SWORD_TYPE;
pub const __CPU_MASK_TYPE = __SYSCALL_ULONG_TYPE;
pub const __OFF_T_MATCHES_OFF64_T = @as(c_int, 1);
pub const __INO_T_MATCHES_INO64_T = @as(c_int, 1);
pub const __RLIM_T_MATCHES_RLIM64_T = @as(c_int, 1);
pub const __STATFS_MATCHES_STATFS64 = @as(c_int, 1);
pub const __KERNEL_OLD_TIMEVAL_MATCHES_TIMEVAL64 = @as(c_int, 1);
pub const __FD_SETSIZE = @as(c_int, 1024);
pub const _BITS_TIME64_H = @as(c_int, 1);
pub const __TIME64_T_TYPE = __TIME_T_TYPE;
pub const __u_char_defined = "";
pub const __ino_t_defined = "";
pub const __dev_t_defined = "";
pub const __gid_t_defined = "";
pub const __mode_t_defined = "";
pub const __nlink_t_defined = "";
pub const __uid_t_defined = "";
pub const __off_t_defined = "";
pub const __pid_t_defined = "";
pub const __id_t_defined = "";
pub const __ssize_t_defined = "";
pub const __daddr_t_defined = "";
pub const __key_t_defined = "";
pub const __clock_t_defined = @as(c_int, 1);
pub const __clockid_t_defined = @as(c_int, 1);
pub const __time_t_defined = @as(c_int, 1);
pub const __timer_t_defined = @as(c_int, 1);
pub const __need_size_t = "";
pub const _SIZE_T = "";
pub const _BITS_STDINT_INTN_H = @as(c_int, 1);
pub const __BIT_TYPES_DEFINED__ = @as(c_int, 1);
pub const _ENDIAN_H = @as(c_int, 1);
pub const _BITS_ENDIAN_H = @as(c_int, 1);
pub const __LITTLE_ENDIAN = @as(c_int, 1234);
pub const __BIG_ENDIAN = @as(c_int, 4321);
pub const __PDP_ENDIAN = @as(c_int, 3412);
pub const _BITS_ENDIANNESS_H = @as(c_int, 1);
pub const __BYTE_ORDER = __LITTLE_ENDIAN;
pub const __FLOAT_WORD_ORDER = __BYTE_ORDER;
pub inline fn __LONG_LONG_PAIR(HI: anytype, LO: anytype) @TypeOf(HI) {
    _ = &HI;
    _ = &LO;
    return blk: {
        _ = &LO;
        break :blk HI;
    };
}
pub const LITTLE_ENDIAN = __LITTLE_ENDIAN;
pub const BIG_ENDIAN = __BIG_ENDIAN;
pub const PDP_ENDIAN = __PDP_ENDIAN;
pub const BYTE_ORDER = __BYTE_ORDER;
pub const _BITS_BYTESWAP_H = @as(c_int, 1);
pub inline fn __bswap_constant_16(x: anytype) __uint16_t {
    _ = &x;
    return @import("std").zig.c_translation.cast(__uint16_t, ((x >> @as(c_int, 8)) & @as(c_int, 0xff)) | ((x & @as(c_int, 0xff)) << @as(c_int, 8)));
}
pub inline fn __bswap_constant_32(x: anytype) @TypeOf(((((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24))) {
    _ = &x;
    return ((((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0xff000000, .hex)) >> @as(c_int, 24)) | ((x & @import("std").zig.c_translation.promoteIntLiteral(c_uint, 0x00ff0000, .hex)) >> @as(c_int, 8))) | ((x & @as(c_uint, 0x0000ff00)) << @as(c_int, 8))) | ((x & @as(c_uint, 0x000000ff)) << @as(c_int, 24));
}
pub inline fn __bswap_constant_64(x: anytype) @TypeOf(((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56))) {
    _ = &x;
    return ((((((((x & @as(c_ulonglong, 0xff00000000000000)) >> @as(c_int, 56)) | ((x & @as(c_ulonglong, 0x00ff000000000000)) >> @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x0000ff0000000000)) >> @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000ff00000000)) >> @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x00000000ff000000)) << @as(c_int, 8))) | ((x & @as(c_ulonglong, 0x0000000000ff0000)) << @as(c_int, 24))) | ((x & @as(c_ulonglong, 0x000000000000ff00)) << @as(c_int, 40))) | ((x & @as(c_ulonglong, 0x00000000000000ff)) << @as(c_int, 56));
}
pub const _BITS_UINTN_IDENTITY_H = @as(c_int, 1);
pub inline fn htobe16(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn htole16(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn be16toh(x: anytype) @TypeOf(__bswap_16(x)) {
    _ = &x;
    return __bswap_16(x);
}
pub inline fn le16toh(x: anytype) @TypeOf(__uint16_identity(x)) {
    _ = &x;
    return __uint16_identity(x);
}
pub inline fn htobe32(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn htole32(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn be32toh(x: anytype) @TypeOf(__bswap_32(x)) {
    _ = &x;
    return __bswap_32(x);
}
pub inline fn le32toh(x: anytype) @TypeOf(__uint32_identity(x)) {
    _ = &x;
    return __uint32_identity(x);
}
pub inline fn htobe64(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn htole64(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub inline fn be64toh(x: anytype) @TypeOf(__bswap_64(x)) {
    _ = &x;
    return __bswap_64(x);
}
pub inline fn le64toh(x: anytype) @TypeOf(__uint64_identity(x)) {
    _ = &x;
    return __uint64_identity(x);
}
pub const _SYS_SELECT_H = @as(c_int, 1);
pub const __FD_ZERO = @compileError("unable to translate macro: undefined identifier `__i`");
// /usr/include/x86_64-linux-gnu/bits/select.h:25:9
pub const __FD_SET = @compileError("unable to translate C expr: expected ')' instead got '|='");
// /usr/include/x86_64-linux-gnu/bits/select.h:32:9
pub const __FD_CLR = @compileError("unable to translate C expr: expected ')' instead got '&='");
// /usr/include/x86_64-linux-gnu/bits/select.h:34:9
pub inline fn __FD_ISSET(d: anytype, s: anytype) @TypeOf((__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0)) {
    _ = &d;
    _ = &s;
    return (__FDS_BITS(s)[@as(usize, @intCast(__FD_ELT(d)))] & __FD_MASK(d)) != @as(c_int, 0);
}
pub const __sigset_t_defined = @as(c_int, 1);
pub const ____sigset_t_defined = "";
pub const _SIGSET_NWORDS = @import("std").zig.c_translation.MacroArithmetic.div(@as(c_int, 1024), @as(c_int, 8) * @import("std").zig.c_translation.sizeof(c_ulong));
pub const __timeval_defined = @as(c_int, 1);
pub const _STRUCT_TIMESPEC = @as(c_int, 1);
pub const __suseconds_t_defined = "";
pub const __NFDBITS = @as(c_int, 8) * @import("std").zig.c_translation.cast(c_int, @import("std").zig.c_translation.sizeof(__fd_mask));
pub inline fn __FD_ELT(d: anytype) @TypeOf(@import("std").zig.c_translation.MacroArithmetic.div(d, __NFDBITS)) {
    _ = &d;
    return @import("std").zig.c_translation.MacroArithmetic.div(d, __NFDBITS);
}
pub inline fn __FD_MASK(d: anytype) __fd_mask {
    _ = &d;
    return @import("std").zig.c_translation.cast(__fd_mask, @as(c_ulong, 1) << @import("std").zig.c_translation.MacroArithmetic.rem(d, __NFDBITS));
}
pub inline fn __FDS_BITS(set: anytype) @TypeOf(set.*.__fds_bits) {
    _ = &set;
    return set.*.__fds_bits;
}
pub const FD_SETSIZE = __FD_SETSIZE;
pub const NFDBITS = __NFDBITS;
pub inline fn FD_SET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_SET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_SET(fd, fdsetp);
}
pub inline fn FD_CLR(fd: anytype, fdsetp: anytype) @TypeOf(__FD_CLR(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_CLR(fd, fdsetp);
}
pub inline fn FD_ISSET(fd: anytype, fdsetp: anytype) @TypeOf(__FD_ISSET(fd, fdsetp)) {
    _ = &fd;
    _ = &fdsetp;
    return __FD_ISSET(fd, fdsetp);
}
pub inline fn FD_ZERO(fdsetp: anytype) @TypeOf(__FD_ZERO(fdsetp)) {
    _ = &fdsetp;
    return __FD_ZERO(fdsetp);
}
pub const __blksize_t_defined = "";
pub const __blkcnt_t_defined = "";
pub const __fsblkcnt_t_defined = "";
pub const __fsfilcnt_t_defined = "";
pub const _BITS_PTHREADTYPES_COMMON_H = @as(c_int, 1);
pub const _THREAD_SHARED_TYPES_H = @as(c_int, 1);
pub const _BITS_PTHREADTYPES_ARCH_H = @as(c_int, 1);
pub const __SIZEOF_PTHREAD_MUTEX_T = @as(c_int, 40);
pub const __SIZEOF_PTHREAD_ATTR_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_RWLOCK_T = @as(c_int, 56);
pub const __SIZEOF_PTHREAD_BARRIER_T = @as(c_int, 32);
pub const __SIZEOF_PTHREAD_MUTEXATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_COND_T = @as(c_int, 48);
pub const __SIZEOF_PTHREAD_CONDATTR_T = @as(c_int, 4);
pub const __SIZEOF_PTHREAD_RWLOCKATTR_T = @as(c_int, 8);
pub const __SIZEOF_PTHREAD_BARRIERATTR_T = @as(c_int, 4);
pub const __LOCK_ALIGNMENT = "";
pub const __ONCE_ALIGNMENT = "";
pub const _BITS_ATOMIC_WIDE_COUNTER_H = "";
pub const _THREAD_MUTEX_INTERNAL_H = @as(c_int, 1);
pub const __PTHREAD_MUTEX_HAVE_PREV = @as(c_int, 1);
pub const __PTHREAD_MUTEX_INITIALIZER = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/struct_mutex.h:56:10
pub const _RWLOCK_INTERNAL_H = "";
pub const __PTHREAD_RWLOCK_ELISION_EXTRA = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/struct_rwlock.h:40:11
pub inline fn __PTHREAD_RWLOCK_INITIALIZER(__flags: anytype) @TypeOf(__flags) {
    _ = &__flags;
    return blk: {
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = @as(c_int, 0);
        _ = &__PTHREAD_RWLOCK_ELISION_EXTRA;
        _ = @as(c_int, 0);
        break :blk __flags;
    };
}
pub const __ONCE_FLAG_INIT = @compileError("unable to translate C expr: unexpected token '{'");
// /usr/include/x86_64-linux-gnu/bits/thread-shared-types.h:113:9
pub const __have_pthread_attr_t = @as(c_int, 1);
pub const X_H = "";
pub const X_PROTOCOL = @as(c_int, 11);
pub const X_PROTOCOL_REVISION = @as(c_int, 0);
pub const _XTYPEDEF_XID = "";
pub const _XTYPEDEF_MASK = "";
pub const _XTYPEDEF_ATOM = "";
pub const _XTYPEDEF_FONT = "";
pub const None = @as(c_long, 0);
pub const ParentRelative = @as(c_long, 1);
pub const CopyFromParent = @as(c_long, 0);
pub const PointerWindow = @as(c_long, 0);
pub const InputFocus = @as(c_long, 1);
pub const PointerRoot = @as(c_long, 1);
pub const AnyPropertyType = @as(c_long, 0);
pub const AnyKey = @as(c_long, 0);
pub const AnyButton = @as(c_long, 0);
pub const AllTemporary = @as(c_long, 0);
pub const CurrentTime = @as(c_long, 0);
pub const NoSymbol = @as(c_long, 0);
pub const NoEventMask = @as(c_long, 0);
pub const KeyPressMask = @as(c_long, 1) << @as(c_int, 0);
pub const KeyReleaseMask = @as(c_long, 1) << @as(c_int, 1);
pub const ButtonPressMask = @as(c_long, 1) << @as(c_int, 2);
pub const ButtonReleaseMask = @as(c_long, 1) << @as(c_int, 3);
pub const EnterWindowMask = @as(c_long, 1) << @as(c_int, 4);
pub const LeaveWindowMask = @as(c_long, 1) << @as(c_int, 5);
pub const PointerMotionMask = @as(c_long, 1) << @as(c_int, 6);
pub const PointerMotionHintMask = @as(c_long, 1) << @as(c_int, 7);
pub const Button1MotionMask = @as(c_long, 1) << @as(c_int, 8);
pub const Button2MotionMask = @as(c_long, 1) << @as(c_int, 9);
pub const Button3MotionMask = @as(c_long, 1) << @as(c_int, 10);
pub const Button4MotionMask = @as(c_long, 1) << @as(c_int, 11);
pub const Button5MotionMask = @as(c_long, 1) << @as(c_int, 12);
pub const ButtonMotionMask = @as(c_long, 1) << @as(c_int, 13);
pub const KeymapStateMask = @as(c_long, 1) << @as(c_int, 14);
pub const ExposureMask = @as(c_long, 1) << @as(c_int, 15);
pub const VisibilityChangeMask = @as(c_long, 1) << @as(c_int, 16);
pub const StructureNotifyMask = @as(c_long, 1) << @as(c_int, 17);
pub const ResizeRedirectMask = @as(c_long, 1) << @as(c_int, 18);
pub const SubstructureNotifyMask = @as(c_long, 1) << @as(c_int, 19);
pub const SubstructureRedirectMask = @as(c_long, 1) << @as(c_int, 20);
pub const FocusChangeMask = @as(c_long, 1) << @as(c_int, 21);
pub const PropertyChangeMask = @as(c_long, 1) << @as(c_int, 22);
pub const ColormapChangeMask = @as(c_long, 1) << @as(c_int, 23);
pub const OwnerGrabButtonMask = @as(c_long, 1) << @as(c_int, 24);
pub const KeyPress = @as(c_int, 2);
pub const KeyRelease = @as(c_int, 3);
pub const ButtonPress = @as(c_int, 4);
pub const ButtonRelease = @as(c_int, 5);
pub const MotionNotify = @as(c_int, 6);
pub const EnterNotify = @as(c_int, 7);
pub const LeaveNotify = @as(c_int, 8);
pub const FocusIn = @as(c_int, 9);
pub const FocusOut = @as(c_int, 10);
pub const KeymapNotify = @as(c_int, 11);
pub const Expose = @as(c_int, 12);
pub const GraphicsExpose = @as(c_int, 13);
pub const NoExpose = @as(c_int, 14);
pub const VisibilityNotify = @as(c_int, 15);
pub const CreateNotify = @as(c_int, 16);
pub const DestroyNotify = @as(c_int, 17);
pub const UnmapNotify = @as(c_int, 18);
pub const MapNotify = @as(c_int, 19);
pub const MapRequest = @as(c_int, 20);
pub const ReparentNotify = @as(c_int, 21);
pub const ConfigureNotify = @as(c_int, 22);
pub const ConfigureRequest = @as(c_int, 23);
pub const GravityNotify = @as(c_int, 24);
pub const ResizeRequest = @as(c_int, 25);
pub const CirculateNotify = @as(c_int, 26);
pub const CirculateRequest = @as(c_int, 27);
pub const PropertyNotify = @as(c_int, 28);
pub const SelectionClear = @as(c_int, 29);
pub const SelectionRequest = @as(c_int, 30);
pub const SelectionNotify = @as(c_int, 31);
pub const ColormapNotify = @as(c_int, 32);
pub const ClientMessage = @as(c_int, 33);
pub const MappingNotify = @as(c_int, 34);
pub const GenericEvent = @as(c_int, 35);
pub const LASTEvent = @as(c_int, 36);
pub const ShiftMask = @as(c_int, 1) << @as(c_int, 0);
pub const LockMask = @as(c_int, 1) << @as(c_int, 1);
pub const ControlMask = @as(c_int, 1) << @as(c_int, 2);
pub const Mod1Mask = @as(c_int, 1) << @as(c_int, 3);
pub const Mod2Mask = @as(c_int, 1) << @as(c_int, 4);
pub const Mod3Mask = @as(c_int, 1) << @as(c_int, 5);
pub const Mod4Mask = @as(c_int, 1) << @as(c_int, 6);
pub const Mod5Mask = @as(c_int, 1) << @as(c_int, 7);
pub const ShiftMapIndex = @as(c_int, 0);
pub const LockMapIndex = @as(c_int, 1);
pub const ControlMapIndex = @as(c_int, 2);
pub const Mod1MapIndex = @as(c_int, 3);
pub const Mod2MapIndex = @as(c_int, 4);
pub const Mod3MapIndex = @as(c_int, 5);
pub const Mod4MapIndex = @as(c_int, 6);
pub const Mod5MapIndex = @as(c_int, 7);
pub const Button1Mask = @as(c_int, 1) << @as(c_int, 8);
pub const Button2Mask = @as(c_int, 1) << @as(c_int, 9);
pub const Button3Mask = @as(c_int, 1) << @as(c_int, 10);
pub const Button4Mask = @as(c_int, 1) << @as(c_int, 11);
pub const Button5Mask = @as(c_int, 1) << @as(c_int, 12);
pub const AnyModifier = @as(c_int, 1) << @as(c_int, 15);
pub const Button1 = @as(c_int, 1);
pub const Button2 = @as(c_int, 2);
pub const Button3 = @as(c_int, 3);
pub const Button4 = @as(c_int, 4);
pub const Button5 = @as(c_int, 5);
pub const NotifyNormal = @as(c_int, 0);
pub const NotifyGrab = @as(c_int, 1);
pub const NotifyUngrab = @as(c_int, 2);
pub const NotifyWhileGrabbed = @as(c_int, 3);
pub const NotifyHint = @as(c_int, 1);
pub const NotifyAncestor = @as(c_int, 0);
pub const NotifyVirtual = @as(c_int, 1);
pub const NotifyInferior = @as(c_int, 2);
pub const NotifyNonlinear = @as(c_int, 3);
pub const NotifyNonlinearVirtual = @as(c_int, 4);
pub const NotifyPointer = @as(c_int, 5);
pub const NotifyPointerRoot = @as(c_int, 6);
pub const NotifyDetailNone = @as(c_int, 7);
pub const VisibilityUnobscured = @as(c_int, 0);
pub const VisibilityPartiallyObscured = @as(c_int, 1);
pub const VisibilityFullyObscured = @as(c_int, 2);
pub const PlaceOnTop = @as(c_int, 0);
pub const PlaceOnBottom = @as(c_int, 1);
pub const FamilyInternet = @as(c_int, 0);
pub const FamilyDECnet = @as(c_int, 1);
pub const FamilyChaos = @as(c_int, 2);
pub const FamilyInternet6 = @as(c_int, 6);
pub const FamilyServerInterpreted = @as(c_int, 5);
pub const PropertyNewValue = @as(c_int, 0);
pub const PropertyDelete = @as(c_int, 1);
pub const ColormapUninstalled = @as(c_int, 0);
pub const ColormapInstalled = @as(c_int, 1);
pub const GrabModeSync = @as(c_int, 0);
pub const GrabModeAsync = @as(c_int, 1);
pub const GrabSuccess = @as(c_int, 0);
pub const AlreadyGrabbed = @as(c_int, 1);
pub const GrabInvalidTime = @as(c_int, 2);
pub const GrabNotViewable = @as(c_int, 3);
pub const GrabFrozen = @as(c_int, 4);
pub const AsyncPointer = @as(c_int, 0);
pub const SyncPointer = @as(c_int, 1);
pub const ReplayPointer = @as(c_int, 2);
pub const AsyncKeyboard = @as(c_int, 3);
pub const SyncKeyboard = @as(c_int, 4);
pub const ReplayKeyboard = @as(c_int, 5);
pub const AsyncBoth = @as(c_int, 6);
pub const SyncBoth = @as(c_int, 7);
pub const RevertToNone = @import("std").zig.c_translation.cast(c_int, None);
pub const RevertToPointerRoot = @import("std").zig.c_translation.cast(c_int, PointerRoot);
pub const RevertToParent = @as(c_int, 2);
pub const Success = @as(c_int, 0);
pub const BadRequest = @as(c_int, 1);
pub const BadValue = @as(c_int, 2);
pub const BadWindow = @as(c_int, 3);
pub const BadPixmap = @as(c_int, 4);
pub const BadAtom = @as(c_int, 5);
pub const BadCursor = @as(c_int, 6);
pub const BadFont = @as(c_int, 7);
pub const BadMatch = @as(c_int, 8);
pub const BadDrawable = @as(c_int, 9);
pub const BadAccess = @as(c_int, 10);
pub const BadAlloc = @as(c_int, 11);
pub const BadColor = @as(c_int, 12);
pub const BadGC = @as(c_int, 13);
pub const BadIDChoice = @as(c_int, 14);
pub const BadName = @as(c_int, 15);
pub const BadLength = @as(c_int, 16);
pub const BadImplementation = @as(c_int, 17);
pub const FirstExtensionError = @as(c_int, 128);
pub const LastExtensionError = @as(c_int, 255);
pub const InputOutput = @as(c_int, 1);
pub const InputOnly = @as(c_int, 2);
pub const CWBackPixmap = @as(c_long, 1) << @as(c_int, 0);
pub const CWBackPixel = @as(c_long, 1) << @as(c_int, 1);
pub const CWBorderPixmap = @as(c_long, 1) << @as(c_int, 2);
pub const CWBorderPixel = @as(c_long, 1) << @as(c_int, 3);
pub const CWBitGravity = @as(c_long, 1) << @as(c_int, 4);
pub const CWWinGravity = @as(c_long, 1) << @as(c_int, 5);
pub const CWBackingStore = @as(c_long, 1) << @as(c_int, 6);
pub const CWBackingPlanes = @as(c_long, 1) << @as(c_int, 7);
pub const CWBackingPixel = @as(c_long, 1) << @as(c_int, 8);
pub const CWOverrideRedirect = @as(c_long, 1) << @as(c_int, 9);
pub const CWSaveUnder = @as(c_long, 1) << @as(c_int, 10);
pub const CWEventMask = @as(c_long, 1) << @as(c_int, 11);
pub const CWDontPropagate = @as(c_long, 1) << @as(c_int, 12);
pub const CWColormap = @as(c_long, 1) << @as(c_int, 13);
pub const CWCursor = @as(c_long, 1) << @as(c_int, 14);
pub const CWX = @as(c_int, 1) << @as(c_int, 0);
pub const CWY = @as(c_int, 1) << @as(c_int, 1);
pub const CWWidth = @as(c_int, 1) << @as(c_int, 2);
pub const CWHeight = @as(c_int, 1) << @as(c_int, 3);
pub const CWBorderWidth = @as(c_int, 1) << @as(c_int, 4);
pub const CWSibling = @as(c_int, 1) << @as(c_int, 5);
pub const CWStackMode = @as(c_int, 1) << @as(c_int, 6);
pub const ForgetGravity = @as(c_int, 0);
pub const NorthWestGravity = @as(c_int, 1);
pub const NorthGravity = @as(c_int, 2);
pub const NorthEastGravity = @as(c_int, 3);
pub const WestGravity = @as(c_int, 4);
pub const CenterGravity = @as(c_int, 5);
pub const EastGravity = @as(c_int, 6);
pub const SouthWestGravity = @as(c_int, 7);
pub const SouthGravity = @as(c_int, 8);
pub const SouthEastGravity = @as(c_int, 9);
pub const StaticGravity = @as(c_int, 10);
pub const UnmapGravity = @as(c_int, 0);
pub const NotUseful = @as(c_int, 0);
pub const WhenMapped = @as(c_int, 1);
pub const Always = @as(c_int, 2);
pub const IsUnmapped = @as(c_int, 0);
pub const IsUnviewable = @as(c_int, 1);
pub const IsViewable = @as(c_int, 2);
pub const SetModeInsert = @as(c_int, 0);
pub const SetModeDelete = @as(c_int, 1);
pub const DestroyAll = @as(c_int, 0);
pub const RetainPermanent = @as(c_int, 1);
pub const RetainTemporary = @as(c_int, 2);
pub const Above = @as(c_int, 0);
pub const Below = @as(c_int, 1);
pub const TopIf = @as(c_int, 2);
pub const BottomIf = @as(c_int, 3);
pub const Opposite = @as(c_int, 4);
pub const RaiseLowest = @as(c_int, 0);
pub const LowerHighest = @as(c_int, 1);
pub const PropModeReplace = @as(c_int, 0);
pub const PropModePrepend = @as(c_int, 1);
pub const PropModeAppend = @as(c_int, 2);
pub const GXclear = @as(c_int, 0x0);
pub const GXand = @as(c_int, 0x1);
pub const GXandReverse = @as(c_int, 0x2);
pub const GXcopy = @as(c_int, 0x3);
pub const GXandInverted = @as(c_int, 0x4);
pub const GXnoop = @as(c_int, 0x5);
pub const GXxor = @as(c_int, 0x6);
pub const GXor = @as(c_int, 0x7);
pub const GXnor = @as(c_int, 0x8);
pub const GXequiv = @as(c_int, 0x9);
pub const GXinvert = @as(c_int, 0xa);
pub const GXorReverse = @as(c_int, 0xb);
pub const GXcopyInverted = @as(c_int, 0xc);
pub const GXorInverted = @as(c_int, 0xd);
pub const GXnand = @as(c_int, 0xe);
pub const GXset = @as(c_int, 0xf);
pub const LineSolid = @as(c_int, 0);
pub const LineOnOffDash = @as(c_int, 1);
pub const LineDoubleDash = @as(c_int, 2);
pub const CapNotLast = @as(c_int, 0);
pub const CapButt = @as(c_int, 1);
pub const CapRound = @as(c_int, 2);
pub const CapProjecting = @as(c_int, 3);
pub const JoinMiter = @as(c_int, 0);
pub const JoinRound = @as(c_int, 1);
pub const JoinBevel = @as(c_int, 2);
pub const FillSolid = @as(c_int, 0);
pub const FillTiled = @as(c_int, 1);
pub const FillStippled = @as(c_int, 2);
pub const FillOpaqueStippled = @as(c_int, 3);
pub const EvenOddRule = @as(c_int, 0);
pub const WindingRule = @as(c_int, 1);
pub const ClipByChildren = @as(c_int, 0);
pub const IncludeInferiors = @as(c_int, 1);
pub const Unsorted = @as(c_int, 0);
pub const YSorted = @as(c_int, 1);
pub const YXSorted = @as(c_int, 2);
pub const YXBanded = @as(c_int, 3);
pub const CoordModeOrigin = @as(c_int, 0);
pub const CoordModePrevious = @as(c_int, 1);
pub const Complex = @as(c_int, 0);
pub const Nonconvex = @as(c_int, 1);
pub const Convex = @as(c_int, 2);
pub const ArcChord = @as(c_int, 0);
pub const ArcPieSlice = @as(c_int, 1);
pub const GCFunction = @as(c_long, 1) << @as(c_int, 0);
pub const GCPlaneMask = @as(c_long, 1) << @as(c_int, 1);
pub const GCForeground = @as(c_long, 1) << @as(c_int, 2);
pub const GCBackground = @as(c_long, 1) << @as(c_int, 3);
pub const GCLineWidth = @as(c_long, 1) << @as(c_int, 4);
pub const GCLineStyle = @as(c_long, 1) << @as(c_int, 5);
pub const GCCapStyle = @as(c_long, 1) << @as(c_int, 6);
pub const GCJoinStyle = @as(c_long, 1) << @as(c_int, 7);
pub const GCFillStyle = @as(c_long, 1) << @as(c_int, 8);
pub const GCFillRule = @as(c_long, 1) << @as(c_int, 9);
pub const GCTile = @as(c_long, 1) << @as(c_int, 10);
pub const GCStipple = @as(c_long, 1) << @as(c_int, 11);
pub const GCTileStipXOrigin = @as(c_long, 1) << @as(c_int, 12);
pub const GCTileStipYOrigin = @as(c_long, 1) << @as(c_int, 13);
pub const GCFont = @as(c_long, 1) << @as(c_int, 14);
pub const GCSubwindowMode = @as(c_long, 1) << @as(c_int, 15);
pub const GCGraphicsExposures = @as(c_long, 1) << @as(c_int, 16);
pub const GCClipXOrigin = @as(c_long, 1) << @as(c_int, 17);
pub const GCClipYOrigin = @as(c_long, 1) << @as(c_int, 18);
pub const GCClipMask = @as(c_long, 1) << @as(c_int, 19);
pub const GCDashOffset = @as(c_long, 1) << @as(c_int, 20);
pub const GCDashList = @as(c_long, 1) << @as(c_int, 21);
pub const GCArcMode = @as(c_long, 1) << @as(c_int, 22);
pub const GCLastBit = @as(c_int, 22);
pub const FontLeftToRight = @as(c_int, 0);
pub const FontRightToLeft = @as(c_int, 1);
pub const FontChange = @as(c_int, 255);
pub const XYBitmap = @as(c_int, 0);
pub const XYPixmap = @as(c_int, 1);
pub const ZPixmap = @as(c_int, 2);
pub const AllocNone = @as(c_int, 0);
pub const AllocAll = @as(c_int, 1);
pub const DoRed = @as(c_int, 1) << @as(c_int, 0);
pub const DoGreen = @as(c_int, 1) << @as(c_int, 1);
pub const DoBlue = @as(c_int, 1) << @as(c_int, 2);
pub const CursorShape = @as(c_int, 0);
pub const TileShape = @as(c_int, 1);
pub const StippleShape = @as(c_int, 2);
pub const AutoRepeatModeOff = @as(c_int, 0);
pub const AutoRepeatModeOn = @as(c_int, 1);
pub const AutoRepeatModeDefault = @as(c_int, 2);
pub const LedModeOff = @as(c_int, 0);
pub const LedModeOn = @as(c_int, 1);
pub const KBKeyClickPercent = @as(c_long, 1) << @as(c_int, 0);
pub const KBBellPercent = @as(c_long, 1) << @as(c_int, 1);
pub const KBBellPitch = @as(c_long, 1) << @as(c_int, 2);
pub const KBBellDuration = @as(c_long, 1) << @as(c_int, 3);
pub const KBLed = @as(c_long, 1) << @as(c_int, 4);
pub const KBLedMode = @as(c_long, 1) << @as(c_int, 5);
pub const KBKey = @as(c_long, 1) << @as(c_int, 6);
pub const KBAutoRepeatMode = @as(c_long, 1) << @as(c_int, 7);
pub const MappingSuccess = @as(c_int, 0);
pub const MappingBusy = @as(c_int, 1);
pub const MappingFailed = @as(c_int, 2);
pub const MappingModifier = @as(c_int, 0);
pub const MappingKeyboard = @as(c_int, 1);
pub const MappingPointer = @as(c_int, 2);
pub const DontPreferBlanking = @as(c_int, 0);
pub const PreferBlanking = @as(c_int, 1);
pub const DefaultBlanking = @as(c_int, 2);
pub const DisableScreenSaver = @as(c_int, 0);
pub const DisableScreenInterval = @as(c_int, 0);
pub const DontAllowExposures = @as(c_int, 0);
pub const AllowExposures = @as(c_int, 1);
pub const DefaultExposures = @as(c_int, 2);
pub const ScreenSaverReset = @as(c_int, 0);
pub const ScreenSaverActive = @as(c_int, 1);
pub const HostInsert = @as(c_int, 0);
pub const HostDelete = @as(c_int, 1);
pub const EnableAccess = @as(c_int, 1);
pub const DisableAccess = @as(c_int, 0);
pub const StaticGray = @as(c_int, 0);
pub const GrayScale = @as(c_int, 1);
pub const StaticColor = @as(c_int, 2);
pub const PseudoColor = @as(c_int, 3);
pub const TrueColor = @as(c_int, 4);
pub const DirectColor = @as(c_int, 5);
pub const LSBFirst = @as(c_int, 0);
pub const MSBFirst = @as(c_int, 1);
pub const _XFUNCPROTO_H_ = "";
pub const NeedFunctionPrototypes = @as(c_int, 1);
pub const NeedVarargsPrototypes = @as(c_int, 1);
pub const NeedNestedPrototypes = @as(c_int, 1);
pub const _Xconst = @compileError("unable to translate C expr: unexpected token 'const'");
// /usr/include/X11/Xfuncproto.h:47:9
pub const NARROWPROTO = "";
pub const FUNCPROTO = @as(c_int, 15);
pub const NeedWidePrototypes = @as(c_int, 0);
pub const _XFUNCPROTOBEGIN = "";
pub const _XFUNCPROTOEND = "";
pub const _X_SENTINEL = @compileError("unable to translate macro: undefined identifier `__sentinel__`");
// /usr/include/X11/Xfuncproto.h:92:10
pub const _X_EXPORT = @compileError("unable to translate macro: undefined identifier `visibility`");
// /usr/include/X11/Xfuncproto.h:100:10
pub const _X_HIDDEN = @compileError("unable to translate macro: undefined identifier `visibility`");
// /usr/include/X11/Xfuncproto.h:101:10
pub const _X_INTERNAL = @compileError("unable to translate macro: undefined identifier `visibility`");
// /usr/include/X11/Xfuncproto.h:102:10
pub inline fn _X_LIKELY(x: anytype) @TypeOf(__builtin_expect(!!(x != 0), @as(c_int, 1))) {
    _ = &x;
    return __builtin_expect(!!(x != 0), @as(c_int, 1));
}
pub inline fn _X_UNLIKELY(x: anytype) @TypeOf(__builtin_expect(!!(x != 0), @as(c_int, 0))) {
    _ = &x;
    return __builtin_expect(!!(x != 0), @as(c_int, 0));
}
pub const _X_COLD = @compileError("unable to translate macro: undefined identifier `__cold__`");
// /usr/include/X11/Xfuncproto.h:127:10
pub const _X_DEPRECATED = @compileError("unable to translate macro: undefined identifier `deprecated`");
// /usr/include/X11/Xfuncproto.h:136:10
pub const _X_DEPRECATED_MSG = @compileError("unable to translate macro: undefined identifier `deprecated`");
// /usr/include/X11/Xfuncproto.h:144:10
pub const _X_NORETURN = @compileError("unable to translate macro: undefined identifier `noreturn`");
// /usr/include/X11/Xfuncproto.h:153:10
pub const _X_ATTRIBUTE_PRINTF = @compileError("unable to translate macro: undefined identifier `__format__`");
// /usr/include/X11/Xfuncproto.h:161:10
pub const _X_NONNULL = @compileError("unable to translate C expr: expected ')' instead got '...'");
// /usr/include/X11/Xfuncproto.h:171:9
pub const _X_UNUSED = @compileError("unable to translate macro: undefined identifier `__unused__`");
// /usr/include/X11/Xfuncproto.h:182:9
pub const _X_INLINE = @compileError("unable to translate C expr: unexpected token 'inline'");
// /usr/include/X11/Xfuncproto.h:193:10
pub const _X_RESTRICT_KYWD = @compileError("unable to translate C expr: unexpected token 'restrict'");
// /usr/include/X11/Xfuncproto.h:206:11
pub const _X_NOTSAN = @compileError("unable to translate macro: undefined identifier `no_sanitize_thread`");
// /usr/include/X11/Xfuncproto.h:216:10
pub const _X_NONSTRING = "";
pub const _XOSDEFS_H_ = "";
pub const __need_ptrdiff_t = "";
pub const __need_wchar_t = "";
pub const __need_NULL = "";
pub const __need_max_align_t = "";
pub const __need_offsetof = "";
pub const __STDDEF_H = "";
pub const _PTRDIFF_T = "";
pub const _WCHAR_T = "";
pub const NULL = @import("std").zig.c_translation.cast(?*anyopaque, @as(c_int, 0));
pub const __CLANG_MAX_ALIGN_T_DEFINED = "";
pub const offsetof = @compileError("unable to translate C expr: unexpected token 'an identifier'");
// /snap/zig/13822/lib/include/__stddef_offsetof.h:16:9
pub const X_HAVE_UTF8_STRING = @as(c_int, 1);
pub const Bool = c_int;
pub const Status = c_int;
pub const True = @as(c_int, 1);
pub const False = @as(c_int, 0);
pub const QueuedAlready = @as(c_int, 0);
pub const QueuedAfterReading = @as(c_int, 1);
pub const QueuedAfterFlush = @as(c_int, 2);
pub inline fn ConnectionNumber(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.fd) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.fd;
}
pub inline fn RootWindow(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.root) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.root;
}
pub inline fn DefaultScreen(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.default_screen;
}
pub inline fn DefaultRootWindow(dpy: anytype) @TypeOf(ScreenOfDisplay(dpy, DefaultScreen(dpy)).*.root) {
    _ = &dpy;
    return ScreenOfDisplay(dpy, DefaultScreen(dpy)).*.root;
}
pub inline fn DefaultVisual(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.root_visual) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.root_visual;
}
pub inline fn DefaultGC(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.default_gc) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.default_gc;
}
pub inline fn BlackPixel(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.black_pixel) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.black_pixel;
}
pub inline fn WhitePixel(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.white_pixel) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.white_pixel;
}
pub const AllPlanes = @import("std").zig.c_translation.cast(c_ulong, ~@as(c_long, 0));
pub inline fn QLength(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.qlen) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.qlen;
}
pub inline fn DisplayWidth(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.width) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.width;
}
pub inline fn DisplayHeight(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.height) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.height;
}
pub inline fn DisplayWidthMM(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.mwidth) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.mwidth;
}
pub inline fn DisplayHeightMM(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.mheight) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.mheight;
}
pub inline fn DisplayPlanes(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.root_depth) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.root_depth;
}
pub inline fn DisplayCells(dpy: anytype, scr: anytype) @TypeOf(DefaultVisual(dpy, scr).*.map_entries) {
    _ = &dpy;
    _ = &scr;
    return DefaultVisual(dpy, scr).*.map_entries;
}
pub inline fn ScreenCount(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.nscreens) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.nscreens;
}
pub inline fn ServerVendor(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.vendor) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.vendor;
}
pub inline fn ProtocolVersion(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.proto_major_version) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.proto_major_version;
}
pub inline fn ProtocolRevision(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.proto_minor_version) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.proto_minor_version;
}
pub inline fn VendorRelease(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.release) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.release;
}
pub inline fn DisplayString(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.display_name) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.display_name;
}
pub inline fn DefaultDepth(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.root_depth) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.root_depth;
}
pub inline fn DefaultColormap(dpy: anytype, scr: anytype) @TypeOf(ScreenOfDisplay(dpy, scr).*.cmap) {
    _ = &dpy;
    _ = &scr;
    return ScreenOfDisplay(dpy, scr).*.cmap;
}
pub inline fn BitmapUnit(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_unit) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_unit;
}
pub inline fn BitmapBitOrder(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_bit_order) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_bit_order;
}
pub inline fn BitmapPad(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_pad) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.bitmap_pad;
}
pub inline fn ImageByteOrder(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.byte_order) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.byte_order;
}
pub inline fn NextRequest(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.request + @as(c_int, 1)) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.request + @as(c_int, 1);
}
pub inline fn LastKnownRequestProcessed(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.last_request_read) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.last_request_read;
}
pub inline fn ScreenOfDisplay(dpy: anytype, scr: anytype) @TypeOf(&@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.screens[@as(usize, @intCast(scr))]) {
    _ = &dpy;
    _ = &scr;
    return &@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.screens[@as(usize, @intCast(scr))];
}
pub inline fn DefaultScreenOfDisplay(dpy: anytype) @TypeOf(ScreenOfDisplay(dpy, DefaultScreen(dpy))) {
    _ = &dpy;
    return ScreenOfDisplay(dpy, DefaultScreen(dpy));
}
pub inline fn DisplayOfScreen(s: anytype) @TypeOf(s.*.display) {
    _ = &s;
    return s.*.display;
}
pub inline fn RootWindowOfScreen(s: anytype) @TypeOf(s.*.root) {
    _ = &s;
    return s.*.root;
}
pub inline fn BlackPixelOfScreen(s: anytype) @TypeOf(s.*.black_pixel) {
    _ = &s;
    return s.*.black_pixel;
}
pub inline fn WhitePixelOfScreen(s: anytype) @TypeOf(s.*.white_pixel) {
    _ = &s;
    return s.*.white_pixel;
}
pub inline fn DefaultColormapOfScreen(s: anytype) @TypeOf(s.*.cmap) {
    _ = &s;
    return s.*.cmap;
}
pub inline fn DefaultDepthOfScreen(s: anytype) @TypeOf(s.*.root_depth) {
    _ = &s;
    return s.*.root_depth;
}
pub inline fn DefaultGCOfScreen(s: anytype) @TypeOf(s.*.default_gc) {
    _ = &s;
    return s.*.default_gc;
}
pub inline fn DefaultVisualOfScreen(s: anytype) @TypeOf(s.*.root_visual) {
    _ = &s;
    return s.*.root_visual;
}
pub inline fn WidthOfScreen(s: anytype) @TypeOf(s.*.width) {
    _ = &s;
    return s.*.width;
}
pub inline fn HeightOfScreen(s: anytype) @TypeOf(s.*.height) {
    _ = &s;
    return s.*.height;
}
pub inline fn WidthMMOfScreen(s: anytype) @TypeOf(s.*.mwidth) {
    _ = &s;
    return s.*.mwidth;
}
pub inline fn HeightMMOfScreen(s: anytype) @TypeOf(s.*.mheight) {
    _ = &s;
    return s.*.mheight;
}
pub inline fn PlanesOfScreen(s: anytype) @TypeOf(s.*.root_depth) {
    _ = &s;
    return s.*.root_depth;
}
pub inline fn CellsOfScreen(s: anytype) @TypeOf(DefaultVisualOfScreen(s).*.map_entries) {
    _ = &s;
    return DefaultVisualOfScreen(s).*.map_entries;
}
pub inline fn MinCmapsOfScreen(s: anytype) @TypeOf(s.*.min_maps) {
    _ = &s;
    return s.*.min_maps;
}
pub inline fn MaxCmapsOfScreen(s: anytype) @TypeOf(s.*.max_maps) {
    _ = &s;
    return s.*.max_maps;
}
pub inline fn DoesSaveUnders(s: anytype) @TypeOf(s.*.save_unders) {
    _ = &s;
    return s.*.save_unders;
}
pub inline fn DoesBackingStore(s: anytype) @TypeOf(s.*.backing_store) {
    _ = &s;
    return s.*.backing_store;
}
pub inline fn EventMaskOfScreen(s: anytype) @TypeOf(s.*.root_input_mask) {
    _ = &s;
    return s.*.root_input_mask;
}
pub inline fn XAllocID(dpy: anytype) @TypeOf(@import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.resource_alloc.*(dpy)) {
    _ = &dpy;
    return @import("std").zig.c_translation.cast(_XPrivDisplay, dpy).*.resource_alloc.*(dpy);
}
pub const XNRequiredCharSet = "requiredCharSet";
pub const XNQueryOrientation = "queryOrientation";
pub const XNBaseFontName = "baseFontName";
pub const XNOMAutomatic = "omAutomatic";
pub const XNMissingCharSet = "missingCharSet";
pub const XNDefaultString = "defaultString";
pub const XNOrientation = "orientation";
pub const XNDirectionalDependentDrawing = "directionalDependentDrawing";
pub const XNContextualDrawing = "contextualDrawing";
pub const XNFontInfo = "fontInfo";
pub const XIMPreeditArea = @as(c_long, 0x0001);
pub const XIMPreeditCallbacks = @as(c_long, 0x0002);
pub const XIMPreeditPosition = @as(c_long, 0x0004);
pub const XIMPreeditNothing = @as(c_long, 0x0008);
pub const XIMPreeditNone = @as(c_long, 0x0010);
pub const XIMStatusArea = @as(c_long, 0x0100);
pub const XIMStatusCallbacks = @as(c_long, 0x0200);
pub const XIMStatusNothing = @as(c_long, 0x0400);
pub const XIMStatusNone = @as(c_long, 0x0800);
pub const XNVaNestedList = "XNVaNestedList";
pub const XNQueryInputStyle = "queryInputStyle";
pub const XNClientWindow = "clientWindow";
pub const XNInputStyle = "inputStyle";
pub const XNFocusWindow = "focusWindow";
pub const XNResourceName = "resourceName";
pub const XNResourceClass = "resourceClass";
pub const XNGeometryCallback = "geometryCallback";
pub const XNDestroyCallback = "destroyCallback";
pub const XNFilterEvents = "filterEvents";
pub const XNPreeditStartCallback = "preeditStartCallback";
pub const XNPreeditDoneCallback = "preeditDoneCallback";
pub const XNPreeditDrawCallback = "preeditDrawCallback";
pub const XNPreeditCaretCallback = "preeditCaretCallback";
pub const XNPreeditStateNotifyCallback = "preeditStateNotifyCallback";
pub const XNPreeditAttributes = "preeditAttributes";
pub const XNStatusStartCallback = "statusStartCallback";
pub const XNStatusDoneCallback = "statusDoneCallback";
pub const XNStatusDrawCallback = "statusDrawCallback";
pub const XNStatusAttributes = "statusAttributes";
pub const XNArea = "area";
pub const XNAreaNeeded = "areaNeeded";
pub const XNSpotLocation = "spotLocation";
pub const XNColormap = "colorMap";
pub const XNStdColormap = "stdColorMap";
pub const XNForeground = "foreground";
pub const XNBackground = "background";
pub const XNBackgroundPixmap = "backgroundPixmap";
pub const XNFontSet = "fontSet";
pub const XNLineSpace = "lineSpace";
pub const XNCursor = "cursor";
pub const XNQueryIMValuesList = "queryIMValuesList";
pub const XNQueryICValuesList = "queryICValuesList";
pub const XNVisiblePosition = "visiblePosition";
pub const XNR6PreeditCallback = "r6PreeditCallback";
pub const XNStringConversionCallback = "stringConversionCallback";
pub const XNStringConversion = "stringConversion";
pub const XNResetState = "resetState";
pub const XNHotKey = "hotKey";
pub const XNHotKeyState = "hotKeyState";
pub const XNPreeditState = "preeditState";
pub const XNSeparatorofNestedList = "separatorofNestedList";
pub const XBufferOverflow = -@as(c_int, 1);
pub const XLookupNone = @as(c_int, 1);
pub const XLookupChars = @as(c_int, 2);
pub const XLookupKeySym = @as(c_int, 3);
pub const XLookupBoth = @as(c_int, 4);
pub const XIMReverse = @as(c_long, 1);
pub const XIMUnderline = @as(c_long, 1) << @as(c_int, 1);
pub const XIMHighlight = @as(c_long, 1) << @as(c_int, 2);
pub const XIMPrimary = @as(c_long, 1) << @as(c_int, 5);
pub const XIMSecondary = @as(c_long, 1) << @as(c_int, 6);
pub const XIMTertiary = @as(c_long, 1) << @as(c_int, 7);
pub const XIMVisibleToForward = @as(c_long, 1) << @as(c_int, 8);
pub const XIMVisibleToBackword = @as(c_long, 1) << @as(c_int, 9);
pub const XIMVisibleToCenter = @as(c_long, 1) << @as(c_int, 10);
pub const XIMPreeditUnKnown = @as(c_long, 0);
pub const XIMPreeditEnable = @as(c_long, 1);
pub const XIMPreeditDisable = @as(c_long, 1) << @as(c_int, 1);
pub const XIMInitialState = @as(c_long, 1);
pub const XIMPreserveState = @as(c_long, 1) << @as(c_int, 1);
pub const XIMStringConversionLeftEdge = @as(c_int, 0x00000001);
pub const XIMStringConversionRightEdge = @as(c_int, 0x00000002);
pub const XIMStringConversionTopEdge = @as(c_int, 0x00000004);
pub const XIMStringConversionBottomEdge = @as(c_int, 0x00000008);
pub const XIMStringConversionConcealed = @as(c_int, 0x00000010);
pub const XIMStringConversionWrapped = @as(c_int, 0x00000020);
pub const XIMStringConversionBuffer = @as(c_int, 0x0001);
pub const XIMStringConversionLine = @as(c_int, 0x0002);
pub const XIMStringConversionWord = @as(c_int, 0x0003);
pub const XIMStringConversionChar = @as(c_int, 0x0004);
pub const XIMStringConversionSubstitution = @as(c_int, 0x0001);
pub const XIMStringConversionRetrieval = @as(c_int, 0x0002);
pub const XIMHotKeyStateON = @as(c_long, 0x0001);
pub const XIMHotKeyStateOFF = @as(c_long, 0x0002);
pub const _X11_XUTIL_H_ = "";
pub const XK_MISCELLANY = "";
pub const XK_XKB_KEYS = "";
pub const XK_LATIN1 = "";
pub const XK_LATIN2 = "";
pub const XK_LATIN3 = "";
pub const XK_LATIN4 = "";
pub const XK_LATIN8 = "";
pub const XK_LATIN9 = "";
pub const XK_CAUCASUS = "";
pub const XK_GREEK = "";
pub const XK_KATAKANA = "";
pub const XK_ARABIC = "";
pub const XK_CYRILLIC = "";
pub const XK_HEBREW = "";
pub const XK_THAI = "";
pub const XK_KOREAN = "";
pub const XK_ARMENIAN = "";
pub const XK_GEORGIAN = "";
pub const XK_VIETNAMESE = "";
pub const XK_CURRENCY = "";
pub const XK_MATHEMATICAL = "";
pub const XK_BRAILLE = "";
pub const XK_SINHALA = "";
pub const XK_VoidSymbol = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffffff, .hex);
pub const XK_BackSpace = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff08, .hex);
pub const XK_Tab = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff09, .hex);
pub const XK_Linefeed = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff0a, .hex);
pub const XK_Clear = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff0b, .hex);
pub const XK_Return = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff0d, .hex);
pub const XK_Pause = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff13, .hex);
pub const XK_Scroll_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff14, .hex);
pub const XK_Sys_Req = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff15, .hex);
pub const XK_Escape = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff1b, .hex);
pub const XK_Delete = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffff, .hex);
pub const XK_Multi_key = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff20, .hex);
pub const XK_Codeinput = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff37, .hex);
pub const XK_SingleCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3c, .hex);
pub const XK_MultipleCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3d, .hex);
pub const XK_PreviousCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3e, .hex);
pub const XK_Kanji = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff21, .hex);
pub const XK_Muhenkan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff22, .hex);
pub const XK_Henkan_Mode = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff23, .hex);
pub const XK_Henkan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff23, .hex);
pub const XK_Romaji = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff24, .hex);
pub const XK_Hiragana = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff25, .hex);
pub const XK_Katakana = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff26, .hex);
pub const XK_Hiragana_Katakana = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff27, .hex);
pub const XK_Zenkaku = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff28, .hex);
pub const XK_Hankaku = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff29, .hex);
pub const XK_Zenkaku_Hankaku = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2a, .hex);
pub const XK_Touroku = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2b, .hex);
pub const XK_Massyo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2c, .hex);
pub const XK_Kana_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2d, .hex);
pub const XK_Kana_Shift = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2e, .hex);
pub const XK_Eisu_Shift = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff2f, .hex);
pub const XK_Eisu_toggle = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff30, .hex);
pub const XK_Kanji_Bangou = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff37, .hex);
pub const XK_Zen_Koho = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3d, .hex);
pub const XK_Mae_Koho = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3e, .hex);
pub const XK_Home = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff50, .hex);
pub const XK_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff51, .hex);
pub const XK_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff52, .hex);
pub const XK_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff53, .hex);
pub const XK_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff54, .hex);
pub const XK_Prior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff55, .hex);
pub const XK_Page_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff55, .hex);
pub const XK_Next = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff56, .hex);
pub const XK_Page_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff56, .hex);
pub const XK_End = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff57, .hex);
pub const XK_Begin = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff58, .hex);
pub const XK_Select = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff60, .hex);
pub const XK_Print = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff61, .hex);
pub const XK_Execute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff62, .hex);
pub const XK_Insert = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff63, .hex);
pub const XK_Undo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff65, .hex);
pub const XK_Redo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff66, .hex);
pub const XK_Menu = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff67, .hex);
pub const XK_Find = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff68, .hex);
pub const XK_Cancel = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff69, .hex);
pub const XK_Help = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff6a, .hex);
pub const XK_Break = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff6b, .hex);
pub const XK_Mode_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_script_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_Num_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7f, .hex);
pub const XK_KP_Space = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff80, .hex);
pub const XK_KP_Tab = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff89, .hex);
pub const XK_KP_Enter = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff8d, .hex);
pub const XK_KP_F1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff91, .hex);
pub const XK_KP_F2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff92, .hex);
pub const XK_KP_F3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff93, .hex);
pub const XK_KP_F4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff94, .hex);
pub const XK_KP_Home = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff95, .hex);
pub const XK_KP_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff96, .hex);
pub const XK_KP_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff97, .hex);
pub const XK_KP_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff98, .hex);
pub const XK_KP_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff99, .hex);
pub const XK_KP_Prior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9a, .hex);
pub const XK_KP_Page_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9a, .hex);
pub const XK_KP_Next = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9b, .hex);
pub const XK_KP_Page_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9b, .hex);
pub const XK_KP_End = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9c, .hex);
pub const XK_KP_Begin = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9d, .hex);
pub const XK_KP_Insert = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9e, .hex);
pub const XK_KP_Delete = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff9f, .hex);
pub const XK_KP_Equal = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffbd, .hex);
pub const XK_KP_Multiply = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffaa, .hex);
pub const XK_KP_Add = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffab, .hex);
pub const XK_KP_Separator = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffac, .hex);
pub const XK_KP_Subtract = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffad, .hex);
pub const XK_KP_Decimal = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffae, .hex);
pub const XK_KP_Divide = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffaf, .hex);
pub const XK_KP_0 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb0, .hex);
pub const XK_KP_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb1, .hex);
pub const XK_KP_2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb2, .hex);
pub const XK_KP_3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb3, .hex);
pub const XK_KP_4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb4, .hex);
pub const XK_KP_5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb5, .hex);
pub const XK_KP_6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb6, .hex);
pub const XK_KP_7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb7, .hex);
pub const XK_KP_8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb8, .hex);
pub const XK_KP_9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffb9, .hex);
pub const XK_F1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffbe, .hex);
pub const XK_F2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffbf, .hex);
pub const XK_F3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc0, .hex);
pub const XK_F4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc1, .hex);
pub const XK_F5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc2, .hex);
pub const XK_F6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc3, .hex);
pub const XK_F7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc4, .hex);
pub const XK_F8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc5, .hex);
pub const XK_F9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc6, .hex);
pub const XK_F10 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc7, .hex);
pub const XK_F11 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc8, .hex);
pub const XK_L1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc8, .hex);
pub const XK_F12 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc9, .hex);
pub const XK_L2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffc9, .hex);
pub const XK_F13 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffca, .hex);
pub const XK_L3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffca, .hex);
pub const XK_F14 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcb, .hex);
pub const XK_L4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcb, .hex);
pub const XK_F15 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcc, .hex);
pub const XK_L5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcc, .hex);
pub const XK_F16 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcd, .hex);
pub const XK_L6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcd, .hex);
pub const XK_F17 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffce, .hex);
pub const XK_L7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffce, .hex);
pub const XK_F18 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcf, .hex);
pub const XK_L8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffcf, .hex);
pub const XK_F19 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd0, .hex);
pub const XK_L9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd0, .hex);
pub const XK_F20 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd1, .hex);
pub const XK_L10 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd1, .hex);
pub const XK_F21 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd2, .hex);
pub const XK_R1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd2, .hex);
pub const XK_F22 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd3, .hex);
pub const XK_R2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd3, .hex);
pub const XK_F23 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd4, .hex);
pub const XK_R3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd4, .hex);
pub const XK_F24 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd5, .hex);
pub const XK_R4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd5, .hex);
pub const XK_F25 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd6, .hex);
pub const XK_R5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd6, .hex);
pub const XK_F26 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd7, .hex);
pub const XK_R6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd7, .hex);
pub const XK_F27 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd8, .hex);
pub const XK_R7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd8, .hex);
pub const XK_F28 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd9, .hex);
pub const XK_R8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffd9, .hex);
pub const XK_F29 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffda, .hex);
pub const XK_R9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffda, .hex);
pub const XK_F30 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdb, .hex);
pub const XK_R10 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdb, .hex);
pub const XK_F31 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdc, .hex);
pub const XK_R11 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdc, .hex);
pub const XK_F32 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdd, .hex);
pub const XK_R12 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdd, .hex);
pub const XK_F33 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffde, .hex);
pub const XK_R13 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffde, .hex);
pub const XK_F34 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdf, .hex);
pub const XK_R14 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffdf, .hex);
pub const XK_F35 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe0, .hex);
pub const XK_R15 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe0, .hex);
pub const XK_Shift_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe1, .hex);
pub const XK_Shift_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe2, .hex);
pub const XK_Control_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe3, .hex);
pub const XK_Control_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe4, .hex);
pub const XK_Caps_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe5, .hex);
pub const XK_Shift_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe6, .hex);
pub const XK_Meta_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe7, .hex);
pub const XK_Meta_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe8, .hex);
pub const XK_Alt_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffe9, .hex);
pub const XK_Alt_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffea, .hex);
pub const XK_Super_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffeb, .hex);
pub const XK_Super_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffec, .hex);
pub const XK_Hyper_L = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffed, .hex);
pub const XK_Hyper_R = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xffee, .hex);
pub const XK_ISO_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe01, .hex);
pub const XK_ISO_Level2_Latch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe02, .hex);
pub const XK_ISO_Level3_Shift = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe03, .hex);
pub const XK_ISO_Level3_Latch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe04, .hex);
pub const XK_ISO_Level3_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe05, .hex);
pub const XK_ISO_Level5_Shift = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe11, .hex);
pub const XK_ISO_Level5_Latch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe12, .hex);
pub const XK_ISO_Level5_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe13, .hex);
pub const XK_ISO_Group_Shift = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_ISO_Group_Latch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe06, .hex);
pub const XK_ISO_Group_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe07, .hex);
pub const XK_ISO_Next_Group = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe08, .hex);
pub const XK_ISO_Next_Group_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe09, .hex);
pub const XK_ISO_Prev_Group = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0a, .hex);
pub const XK_ISO_Prev_Group_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0b, .hex);
pub const XK_ISO_First_Group = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0c, .hex);
pub const XK_ISO_First_Group_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0d, .hex);
pub const XK_ISO_Last_Group = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0e, .hex);
pub const XK_ISO_Last_Group_Lock = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe0f, .hex);
pub const XK_ISO_Left_Tab = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe20, .hex);
pub const XK_ISO_Move_Line_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe21, .hex);
pub const XK_ISO_Move_Line_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe22, .hex);
pub const XK_ISO_Partial_Line_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe23, .hex);
pub const XK_ISO_Partial_Line_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe24, .hex);
pub const XK_ISO_Partial_Space_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe25, .hex);
pub const XK_ISO_Partial_Space_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe26, .hex);
pub const XK_ISO_Set_Margin_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe27, .hex);
pub const XK_ISO_Set_Margin_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe28, .hex);
pub const XK_ISO_Release_Margin_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe29, .hex);
pub const XK_ISO_Release_Margin_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2a, .hex);
pub const XK_ISO_Release_Both_Margins = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2b, .hex);
pub const XK_ISO_Fast_Cursor_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2c, .hex);
pub const XK_ISO_Fast_Cursor_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2d, .hex);
pub const XK_ISO_Fast_Cursor_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2e, .hex);
pub const XK_ISO_Fast_Cursor_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe2f, .hex);
pub const XK_ISO_Continuous_Underline = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe30, .hex);
pub const XK_ISO_Discontinuous_Underline = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe31, .hex);
pub const XK_ISO_Emphasize = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe32, .hex);
pub const XK_ISO_Center_Object = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe33, .hex);
pub const XK_ISO_Enter = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe34, .hex);
pub const XK_dead_grave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe50, .hex);
pub const XK_dead_acute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe51, .hex);
pub const XK_dead_circumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe52, .hex);
pub const XK_dead_tilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe53, .hex);
pub const XK_dead_perispomeni = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe53, .hex);
pub const XK_dead_macron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe54, .hex);
pub const XK_dead_breve = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe55, .hex);
pub const XK_dead_abovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe56, .hex);
pub const XK_dead_diaeresis = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe57, .hex);
pub const XK_dead_abovering = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe58, .hex);
pub const XK_dead_doubleacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe59, .hex);
pub const XK_dead_caron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5a, .hex);
pub const XK_dead_cedilla = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5b, .hex);
pub const XK_dead_ogonek = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5c, .hex);
pub const XK_dead_iota = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5d, .hex);
pub const XK_dead_voiced_sound = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5e, .hex);
pub const XK_dead_semivoiced_sound = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe5f, .hex);
pub const XK_dead_belowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe60, .hex);
pub const XK_dead_hook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe61, .hex);
pub const XK_dead_horn = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe62, .hex);
pub const XK_dead_stroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe63, .hex);
pub const XK_dead_abovecomma = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe64, .hex);
pub const XK_dead_psili = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe64, .hex);
pub const XK_dead_abovereversedcomma = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe65, .hex);
pub const XK_dead_dasia = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe65, .hex);
pub const XK_dead_doublegrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe66, .hex);
pub const XK_dead_belowring = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe67, .hex);
pub const XK_dead_belowmacron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe68, .hex);
pub const XK_dead_belowcircumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe69, .hex);
pub const XK_dead_belowtilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6a, .hex);
pub const XK_dead_belowbreve = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6b, .hex);
pub const XK_dead_belowdiaeresis = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6c, .hex);
pub const XK_dead_invertedbreve = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6d, .hex);
pub const XK_dead_belowcomma = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6e, .hex);
pub const XK_dead_currency = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe6f, .hex);
pub const XK_dead_lowline = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe90, .hex);
pub const XK_dead_aboveverticalline = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe91, .hex);
pub const XK_dead_belowverticalline = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe92, .hex);
pub const XK_dead_longsolidusoverlay = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe93, .hex);
pub const XK_dead_a = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe80, .hex);
pub const XK_dead_A = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe81, .hex);
pub const XK_dead_e = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe82, .hex);
pub const XK_dead_E = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe83, .hex);
pub const XK_dead_i = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe84, .hex);
pub const XK_dead_I = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe85, .hex);
pub const XK_dead_o = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe86, .hex);
pub const XK_dead_O = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe87, .hex);
pub const XK_dead_u = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe88, .hex);
pub const XK_dead_U = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe89, .hex);
pub const XK_dead_small_schwa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe8a, .hex);
pub const XK_dead_capital_schwa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe8b, .hex);
pub const XK_dead_greek = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe8c, .hex);
pub const XK_First_Virtual_Screen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfed0, .hex);
pub const XK_Prev_Virtual_Screen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfed1, .hex);
pub const XK_Next_Virtual_Screen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfed2, .hex);
pub const XK_Last_Virtual_Screen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfed4, .hex);
pub const XK_Terminate_Server = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfed5, .hex);
pub const XK_AccessX_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe70, .hex);
pub const XK_AccessX_Feedback_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe71, .hex);
pub const XK_RepeatKeys_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe72, .hex);
pub const XK_SlowKeys_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe73, .hex);
pub const XK_BounceKeys_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe74, .hex);
pub const XK_StickyKeys_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe75, .hex);
pub const XK_MouseKeys_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe76, .hex);
pub const XK_MouseKeys_Accel_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe77, .hex);
pub const XK_Overlay1_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe78, .hex);
pub const XK_Overlay2_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe79, .hex);
pub const XK_AudibleBell_Enable = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfe7a, .hex);
pub const XK_Pointer_Left = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee0, .hex);
pub const XK_Pointer_Right = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee1, .hex);
pub const XK_Pointer_Up = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee2, .hex);
pub const XK_Pointer_Down = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee3, .hex);
pub const XK_Pointer_UpLeft = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee4, .hex);
pub const XK_Pointer_UpRight = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee5, .hex);
pub const XK_Pointer_DownLeft = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee6, .hex);
pub const XK_Pointer_DownRight = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee7, .hex);
pub const XK_Pointer_Button_Dflt = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee8, .hex);
pub const XK_Pointer_Button1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfee9, .hex);
pub const XK_Pointer_Button2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeea, .hex);
pub const XK_Pointer_Button3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeeb, .hex);
pub const XK_Pointer_Button4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeec, .hex);
pub const XK_Pointer_Button5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeed, .hex);
pub const XK_Pointer_DblClick_Dflt = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeee, .hex);
pub const XK_Pointer_DblClick1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfeef, .hex);
pub const XK_Pointer_DblClick2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef0, .hex);
pub const XK_Pointer_DblClick3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef1, .hex);
pub const XK_Pointer_DblClick4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef2, .hex);
pub const XK_Pointer_DblClick5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef3, .hex);
pub const XK_Pointer_Drag_Dflt = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef4, .hex);
pub const XK_Pointer_Drag1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef5, .hex);
pub const XK_Pointer_Drag2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef6, .hex);
pub const XK_Pointer_Drag3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef7, .hex);
pub const XK_Pointer_Drag4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef8, .hex);
pub const XK_Pointer_Drag5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfefd, .hex);
pub const XK_Pointer_EnableKeys = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfef9, .hex);
pub const XK_Pointer_Accelerate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfefa, .hex);
pub const XK_Pointer_DfltBtnNext = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfefb, .hex);
pub const XK_Pointer_DfltBtnPrev = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfefc, .hex);
pub const XK_ch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea0, .hex);
pub const XK_Ch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea1, .hex);
pub const XK_CH = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea2, .hex);
pub const XK_c_h = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea3, .hex);
pub const XK_C_h = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea4, .hex);
pub const XK_C_H = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfea5, .hex);
pub const XK_space = @as(c_int, 0x0020);
pub const XK_exclam = @as(c_int, 0x0021);
pub const XK_quotedbl = @as(c_int, 0x0022);
pub const XK_numbersign = @as(c_int, 0x0023);
pub const XK_dollar = @as(c_int, 0x0024);
pub const XK_percent = @as(c_int, 0x0025);
pub const XK_ampersand = @as(c_int, 0x0026);
pub const XK_apostrophe = @as(c_int, 0x0027);
pub const XK_quoteright = @as(c_int, 0x0027);
pub const XK_parenleft = @as(c_int, 0x0028);
pub const XK_parenright = @as(c_int, 0x0029);
pub const XK_asterisk = @as(c_int, 0x002a);
pub const XK_plus = @as(c_int, 0x002b);
pub const XK_comma = @as(c_int, 0x002c);
pub const XK_minus = @as(c_int, 0x002d);
pub const XK_period = @as(c_int, 0x002e);
pub const XK_slash = @as(c_int, 0x002f);
pub const XK_0 = @as(c_int, 0x0030);
pub const XK_1 = @as(c_int, 0x0031);
pub const XK_2 = @as(c_int, 0x0032);
pub const XK_3 = @as(c_int, 0x0033);
pub const XK_4 = @as(c_int, 0x0034);
pub const XK_5 = @as(c_int, 0x0035);
pub const XK_6 = @as(c_int, 0x0036);
pub const XK_7 = @as(c_int, 0x0037);
pub const XK_8 = @as(c_int, 0x0038);
pub const XK_9 = @as(c_int, 0x0039);
pub const XK_colon = @as(c_int, 0x003a);
pub const XK_semicolon = @as(c_int, 0x003b);
pub const XK_less = @as(c_int, 0x003c);
pub const XK_equal = @as(c_int, 0x003d);
pub const XK_greater = @as(c_int, 0x003e);
pub const XK_question = @as(c_int, 0x003f);
pub const XK_at = @as(c_int, 0x0040);
pub const XK_A = @as(c_int, 0x0041);
pub const XK_B = @as(c_int, 0x0042);
pub const XK_C = @as(c_int, 0x0043);
pub const XK_D = @as(c_int, 0x0044);
pub const XK_E = @as(c_int, 0x0045);
pub const XK_F = @as(c_int, 0x0046);
pub const XK_G = @as(c_int, 0x0047);
pub const XK_H = @as(c_int, 0x0048);
pub const XK_I = @as(c_int, 0x0049);
pub const XK_J = @as(c_int, 0x004a);
pub const XK_K = @as(c_int, 0x004b);
pub const XK_L = @as(c_int, 0x004c);
pub const XK_M = @as(c_int, 0x004d);
pub const XK_N = @as(c_int, 0x004e);
pub const XK_O = @as(c_int, 0x004f);
pub const XK_P = @as(c_int, 0x0050);
pub const XK_Q = @as(c_int, 0x0051);
pub const XK_R = @as(c_int, 0x0052);
pub const XK_S = @as(c_int, 0x0053);
pub const XK_T = @as(c_int, 0x0054);
pub const XK_U = @as(c_int, 0x0055);
pub const XK_V = @as(c_int, 0x0056);
pub const XK_W = @as(c_int, 0x0057);
pub const XK_X = @as(c_int, 0x0058);
pub const XK_Y = @as(c_int, 0x0059);
pub const XK_Z = @as(c_int, 0x005a);
pub const XK_bracketleft = @as(c_int, 0x005b);
pub const XK_backslash = @as(c_int, 0x005c);
pub const XK_bracketright = @as(c_int, 0x005d);
pub const XK_asciicircum = @as(c_int, 0x005e);
pub const XK_underscore = @as(c_int, 0x005f);
pub const XK_grave = @as(c_int, 0x0060);
pub const XK_quoteleft = @as(c_int, 0x0060);
pub const XK_a = @as(c_int, 0x0061);
pub const XK_b = @as(c_int, 0x0062);
pub const XK_c = @as(c_int, 0x0063);
pub const XK_d = @as(c_int, 0x0064);
pub const XK_e = @as(c_int, 0x0065);
pub const XK_f = @as(c_int, 0x0066);
pub const XK_g = @as(c_int, 0x0067);
pub const XK_h = @as(c_int, 0x0068);
pub const XK_i = @as(c_int, 0x0069);
pub const XK_j = @as(c_int, 0x006a);
pub const XK_k = @as(c_int, 0x006b);
pub const XK_l = @as(c_int, 0x006c);
pub const XK_m = @as(c_int, 0x006d);
pub const XK_n = @as(c_int, 0x006e);
pub const XK_o = @as(c_int, 0x006f);
pub const XK_p = @as(c_int, 0x0070);
pub const XK_q = @as(c_int, 0x0071);
pub const XK_r = @as(c_int, 0x0072);
pub const XK_s = @as(c_int, 0x0073);
pub const XK_t = @as(c_int, 0x0074);
pub const XK_u = @as(c_int, 0x0075);
pub const XK_v = @as(c_int, 0x0076);
pub const XK_w = @as(c_int, 0x0077);
pub const XK_x = @as(c_int, 0x0078);
pub const XK_y = @as(c_int, 0x0079);
pub const XK_z = @as(c_int, 0x007a);
pub const XK_braceleft = @as(c_int, 0x007b);
pub const XK_bar = @as(c_int, 0x007c);
pub const XK_braceright = @as(c_int, 0x007d);
pub const XK_asciitilde = @as(c_int, 0x007e);
pub const XK_nobreakspace = @as(c_int, 0x00a0);
pub const XK_exclamdown = @as(c_int, 0x00a1);
pub const XK_cent = @as(c_int, 0x00a2);
pub const XK_sterling = @as(c_int, 0x00a3);
pub const XK_currency = @as(c_int, 0x00a4);
pub const XK_yen = @as(c_int, 0x00a5);
pub const XK_brokenbar = @as(c_int, 0x00a6);
pub const XK_section = @as(c_int, 0x00a7);
pub const XK_diaeresis = @as(c_int, 0x00a8);
pub const XK_copyright = @as(c_int, 0x00a9);
pub const XK_ordfeminine = @as(c_int, 0x00aa);
pub const XK_guillemotleft = @as(c_int, 0x00ab);
pub const XK_notsign = @as(c_int, 0x00ac);
pub const XK_hyphen = @as(c_int, 0x00ad);
pub const XK_registered = @as(c_int, 0x00ae);
pub const XK_macron = @as(c_int, 0x00af);
pub const XK_degree = @as(c_int, 0x00b0);
pub const XK_plusminus = @as(c_int, 0x00b1);
pub const XK_twosuperior = @as(c_int, 0x00b2);
pub const XK_threesuperior = @as(c_int, 0x00b3);
pub const XK_acute = @as(c_int, 0x00b4);
pub const XK_mu = @as(c_int, 0x00b5);
pub const XK_paragraph = @as(c_int, 0x00b6);
pub const XK_periodcentered = @as(c_int, 0x00b7);
pub const XK_cedilla = @as(c_int, 0x00b8);
pub const XK_onesuperior = @as(c_int, 0x00b9);
pub const XK_masculine = @as(c_int, 0x00ba);
pub const XK_guillemotright = @as(c_int, 0x00bb);
pub const XK_onequarter = @as(c_int, 0x00bc);
pub const XK_onehalf = @as(c_int, 0x00bd);
pub const XK_threequarters = @as(c_int, 0x00be);
pub const XK_questiondown = @as(c_int, 0x00bf);
pub const XK_Agrave = @as(c_int, 0x00c0);
pub const XK_Aacute = @as(c_int, 0x00c1);
pub const XK_Acircumflex = @as(c_int, 0x00c2);
pub const XK_Atilde = @as(c_int, 0x00c3);
pub const XK_Adiaeresis = @as(c_int, 0x00c4);
pub const XK_Aring = @as(c_int, 0x00c5);
pub const XK_AE = @as(c_int, 0x00c6);
pub const XK_Ccedilla = @as(c_int, 0x00c7);
pub const XK_Egrave = @as(c_int, 0x00c8);
pub const XK_Eacute = @as(c_int, 0x00c9);
pub const XK_Ecircumflex = @as(c_int, 0x00ca);
pub const XK_Ediaeresis = @as(c_int, 0x00cb);
pub const XK_Igrave = @as(c_int, 0x00cc);
pub const XK_Iacute = @as(c_int, 0x00cd);
pub const XK_Icircumflex = @as(c_int, 0x00ce);
pub const XK_Idiaeresis = @as(c_int, 0x00cf);
pub const XK_ETH = @as(c_int, 0x00d0);
pub const XK_Eth = @as(c_int, 0x00d0);
pub const XK_Ntilde = @as(c_int, 0x00d1);
pub const XK_Ograve = @as(c_int, 0x00d2);
pub const XK_Oacute = @as(c_int, 0x00d3);
pub const XK_Ocircumflex = @as(c_int, 0x00d4);
pub const XK_Otilde = @as(c_int, 0x00d5);
pub const XK_Odiaeresis = @as(c_int, 0x00d6);
pub const XK_multiply = @as(c_int, 0x00d7);
pub const XK_Oslash = @as(c_int, 0x00d8);
pub const XK_Ooblique = @as(c_int, 0x00d8);
pub const XK_Ugrave = @as(c_int, 0x00d9);
pub const XK_Uacute = @as(c_int, 0x00da);
pub const XK_Ucircumflex = @as(c_int, 0x00db);
pub const XK_Udiaeresis = @as(c_int, 0x00dc);
pub const XK_Yacute = @as(c_int, 0x00dd);
pub const XK_THORN = @as(c_int, 0x00de);
pub const XK_Thorn = @as(c_int, 0x00de);
pub const XK_ssharp = @as(c_int, 0x00df);
pub const XK_agrave = @as(c_int, 0x00e0);
pub const XK_aacute = @as(c_int, 0x00e1);
pub const XK_acircumflex = @as(c_int, 0x00e2);
pub const XK_atilde = @as(c_int, 0x00e3);
pub const XK_adiaeresis = @as(c_int, 0x00e4);
pub const XK_aring = @as(c_int, 0x00e5);
pub const XK_ae = @as(c_int, 0x00e6);
pub const XK_ccedilla = @as(c_int, 0x00e7);
pub const XK_egrave = @as(c_int, 0x00e8);
pub const XK_eacute = @as(c_int, 0x00e9);
pub const XK_ecircumflex = @as(c_int, 0x00ea);
pub const XK_ediaeresis = @as(c_int, 0x00eb);
pub const XK_igrave = @as(c_int, 0x00ec);
pub const XK_iacute = @as(c_int, 0x00ed);
pub const XK_icircumflex = @as(c_int, 0x00ee);
pub const XK_idiaeresis = @as(c_int, 0x00ef);
pub const XK_eth = @as(c_int, 0x00f0);
pub const XK_ntilde = @as(c_int, 0x00f1);
pub const XK_ograve = @as(c_int, 0x00f2);
pub const XK_oacute = @as(c_int, 0x00f3);
pub const XK_ocircumflex = @as(c_int, 0x00f4);
pub const XK_otilde = @as(c_int, 0x00f5);
pub const XK_odiaeresis = @as(c_int, 0x00f6);
pub const XK_division = @as(c_int, 0x00f7);
pub const XK_oslash = @as(c_int, 0x00f8);
pub const XK_ooblique = @as(c_int, 0x00f8);
pub const XK_ugrave = @as(c_int, 0x00f9);
pub const XK_uacute = @as(c_int, 0x00fa);
pub const XK_ucircumflex = @as(c_int, 0x00fb);
pub const XK_udiaeresis = @as(c_int, 0x00fc);
pub const XK_yacute = @as(c_int, 0x00fd);
pub const XK_thorn = @as(c_int, 0x00fe);
pub const XK_ydiaeresis = @as(c_int, 0x00ff);
pub const XK_Aogonek = @as(c_int, 0x01a1);
pub const XK_breve = @as(c_int, 0x01a2);
pub const XK_Lstroke = @as(c_int, 0x01a3);
pub const XK_Lcaron = @as(c_int, 0x01a5);
pub const XK_Sacute = @as(c_int, 0x01a6);
pub const XK_Scaron = @as(c_int, 0x01a9);
pub const XK_Scedilla = @as(c_int, 0x01aa);
pub const XK_Tcaron = @as(c_int, 0x01ab);
pub const XK_Zacute = @as(c_int, 0x01ac);
pub const XK_Zcaron = @as(c_int, 0x01ae);
pub const XK_Zabovedot = @as(c_int, 0x01af);
pub const XK_aogonek = @as(c_int, 0x01b1);
pub const XK_ogonek = @as(c_int, 0x01b2);
pub const XK_lstroke = @as(c_int, 0x01b3);
pub const XK_lcaron = @as(c_int, 0x01b5);
pub const XK_sacute = @as(c_int, 0x01b6);
pub const XK_caron = @as(c_int, 0x01b7);
pub const XK_scaron = @as(c_int, 0x01b9);
pub const XK_scedilla = @as(c_int, 0x01ba);
pub const XK_tcaron = @as(c_int, 0x01bb);
pub const XK_zacute = @as(c_int, 0x01bc);
pub const XK_doubleacute = @as(c_int, 0x01bd);
pub const XK_zcaron = @as(c_int, 0x01be);
pub const XK_zabovedot = @as(c_int, 0x01bf);
pub const XK_Racute = @as(c_int, 0x01c0);
pub const XK_Abreve = @as(c_int, 0x01c3);
pub const XK_Lacute = @as(c_int, 0x01c5);
pub const XK_Cacute = @as(c_int, 0x01c6);
pub const XK_Ccaron = @as(c_int, 0x01c8);
pub const XK_Eogonek = @as(c_int, 0x01ca);
pub const XK_Ecaron = @as(c_int, 0x01cc);
pub const XK_Dcaron = @as(c_int, 0x01cf);
pub const XK_Dstroke = @as(c_int, 0x01d0);
pub const XK_Nacute = @as(c_int, 0x01d1);
pub const XK_Ncaron = @as(c_int, 0x01d2);
pub const XK_Odoubleacute = @as(c_int, 0x01d5);
pub const XK_Rcaron = @as(c_int, 0x01d8);
pub const XK_Uring = @as(c_int, 0x01d9);
pub const XK_Udoubleacute = @as(c_int, 0x01db);
pub const XK_Tcedilla = @as(c_int, 0x01de);
pub const XK_racute = @as(c_int, 0x01e0);
pub const XK_abreve = @as(c_int, 0x01e3);
pub const XK_lacute = @as(c_int, 0x01e5);
pub const XK_cacute = @as(c_int, 0x01e6);
pub const XK_ccaron = @as(c_int, 0x01e8);
pub const XK_eogonek = @as(c_int, 0x01ea);
pub const XK_ecaron = @as(c_int, 0x01ec);
pub const XK_dcaron = @as(c_int, 0x01ef);
pub const XK_dstroke = @as(c_int, 0x01f0);
pub const XK_nacute = @as(c_int, 0x01f1);
pub const XK_ncaron = @as(c_int, 0x01f2);
pub const XK_odoubleacute = @as(c_int, 0x01f5);
pub const XK_rcaron = @as(c_int, 0x01f8);
pub const XK_uring = @as(c_int, 0x01f9);
pub const XK_udoubleacute = @as(c_int, 0x01fb);
pub const XK_tcedilla = @as(c_int, 0x01fe);
pub const XK_abovedot = @as(c_int, 0x01ff);
pub const XK_Hstroke = @as(c_int, 0x02a1);
pub const XK_Hcircumflex = @as(c_int, 0x02a6);
pub const XK_Iabovedot = @as(c_int, 0x02a9);
pub const XK_Gbreve = @as(c_int, 0x02ab);
pub const XK_Jcircumflex = @as(c_int, 0x02ac);
pub const XK_hstroke = @as(c_int, 0x02b1);
pub const XK_hcircumflex = @as(c_int, 0x02b6);
pub const XK_idotless = @as(c_int, 0x02b9);
pub const XK_gbreve = @as(c_int, 0x02bb);
pub const XK_jcircumflex = @as(c_int, 0x02bc);
pub const XK_Cabovedot = @as(c_int, 0x02c5);
pub const XK_Ccircumflex = @as(c_int, 0x02c6);
pub const XK_Gabovedot = @as(c_int, 0x02d5);
pub const XK_Gcircumflex = @as(c_int, 0x02d8);
pub const XK_Ubreve = @as(c_int, 0x02dd);
pub const XK_Scircumflex = @as(c_int, 0x02de);
pub const XK_cabovedot = @as(c_int, 0x02e5);
pub const XK_ccircumflex = @as(c_int, 0x02e6);
pub const XK_gabovedot = @as(c_int, 0x02f5);
pub const XK_gcircumflex = @as(c_int, 0x02f8);
pub const XK_ubreve = @as(c_int, 0x02fd);
pub const XK_scircumflex = @as(c_int, 0x02fe);
pub const XK_kra = @as(c_int, 0x03a2);
pub const XK_kappa = @as(c_int, 0x03a2);
pub const XK_Rcedilla = @as(c_int, 0x03a3);
pub const XK_Itilde = @as(c_int, 0x03a5);
pub const XK_Lcedilla = @as(c_int, 0x03a6);
pub const XK_Emacron = @as(c_int, 0x03aa);
pub const XK_Gcedilla = @as(c_int, 0x03ab);
pub const XK_Tslash = @as(c_int, 0x03ac);
pub const XK_rcedilla = @as(c_int, 0x03b3);
pub const XK_itilde = @as(c_int, 0x03b5);
pub const XK_lcedilla = @as(c_int, 0x03b6);
pub const XK_emacron = @as(c_int, 0x03ba);
pub const XK_gcedilla = @as(c_int, 0x03bb);
pub const XK_tslash = @as(c_int, 0x03bc);
pub const XK_ENG = @as(c_int, 0x03bd);
pub const XK_eng = @as(c_int, 0x03bf);
pub const XK_Amacron = @as(c_int, 0x03c0);
pub const XK_Iogonek = @as(c_int, 0x03c7);
pub const XK_Eabovedot = @as(c_int, 0x03cc);
pub const XK_Imacron = @as(c_int, 0x03cf);
pub const XK_Ncedilla = @as(c_int, 0x03d1);
pub const XK_Omacron = @as(c_int, 0x03d2);
pub const XK_Kcedilla = @as(c_int, 0x03d3);
pub const XK_Uogonek = @as(c_int, 0x03d9);
pub const XK_Utilde = @as(c_int, 0x03dd);
pub const XK_Umacron = @as(c_int, 0x03de);
pub const XK_amacron = @as(c_int, 0x03e0);
pub const XK_iogonek = @as(c_int, 0x03e7);
pub const XK_eabovedot = @as(c_int, 0x03ec);
pub const XK_imacron = @as(c_int, 0x03ef);
pub const XK_ncedilla = @as(c_int, 0x03f1);
pub const XK_omacron = @as(c_int, 0x03f2);
pub const XK_kcedilla = @as(c_int, 0x03f3);
pub const XK_uogonek = @as(c_int, 0x03f9);
pub const XK_utilde = @as(c_int, 0x03fd);
pub const XK_umacron = @as(c_int, 0x03fe);
pub const XK_Wcircumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000174, .hex);
pub const XK_wcircumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000175, .hex);
pub const XK_Ycircumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000176, .hex);
pub const XK_ycircumflex = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000177, .hex);
pub const XK_Babovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e02, .hex);
pub const XK_babovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e03, .hex);
pub const XK_Dabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e0a, .hex);
pub const XK_dabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e0b, .hex);
pub const XK_Fabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e1e, .hex);
pub const XK_fabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e1f, .hex);
pub const XK_Mabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e40, .hex);
pub const XK_mabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e41, .hex);
pub const XK_Pabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e56, .hex);
pub const XK_pabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e57, .hex);
pub const XK_Sabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e60, .hex);
pub const XK_sabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e61, .hex);
pub const XK_Tabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e6a, .hex);
pub const XK_tabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e6b, .hex);
pub const XK_Wgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e80, .hex);
pub const XK_wgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e81, .hex);
pub const XK_Wacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e82, .hex);
pub const XK_wacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e83, .hex);
pub const XK_Wdiaeresis = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e84, .hex);
pub const XK_wdiaeresis = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e85, .hex);
pub const XK_Ygrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef2, .hex);
pub const XK_ygrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef3, .hex);
pub const XK_OE = @as(c_int, 0x13bc);
pub const XK_oe = @as(c_int, 0x13bd);
pub const XK_Ydiaeresis = @as(c_int, 0x13be);
pub const XK_overline = @as(c_int, 0x047e);
pub const XK_kana_fullstop = @as(c_int, 0x04a1);
pub const XK_kana_openingbracket = @as(c_int, 0x04a2);
pub const XK_kana_closingbracket = @as(c_int, 0x04a3);
pub const XK_kana_comma = @as(c_int, 0x04a4);
pub const XK_kana_conjunctive = @as(c_int, 0x04a5);
pub const XK_kana_middledot = @as(c_int, 0x04a5);
pub const XK_kana_WO = @as(c_int, 0x04a6);
pub const XK_kana_a = @as(c_int, 0x04a7);
pub const XK_kana_i = @as(c_int, 0x04a8);
pub const XK_kana_u = @as(c_int, 0x04a9);
pub const XK_kana_e = @as(c_int, 0x04aa);
pub const XK_kana_o = @as(c_int, 0x04ab);
pub const XK_kana_ya = @as(c_int, 0x04ac);
pub const XK_kana_yu = @as(c_int, 0x04ad);
pub const XK_kana_yo = @as(c_int, 0x04ae);
pub const XK_kana_tsu = @as(c_int, 0x04af);
pub const XK_kana_tu = @as(c_int, 0x04af);
pub const XK_prolongedsound = @as(c_int, 0x04b0);
pub const XK_kana_A = @as(c_int, 0x04b1);
pub const XK_kana_I = @as(c_int, 0x04b2);
pub const XK_kana_U = @as(c_int, 0x04b3);
pub const XK_kana_E = @as(c_int, 0x04b4);
pub const XK_kana_O = @as(c_int, 0x04b5);
pub const XK_kana_KA = @as(c_int, 0x04b6);
pub const XK_kana_KI = @as(c_int, 0x04b7);
pub const XK_kana_KU = @as(c_int, 0x04b8);
pub const XK_kana_KE = @as(c_int, 0x04b9);
pub const XK_kana_KO = @as(c_int, 0x04ba);
pub const XK_kana_SA = @as(c_int, 0x04bb);
pub const XK_kana_SHI = @as(c_int, 0x04bc);
pub const XK_kana_SU = @as(c_int, 0x04bd);
pub const XK_kana_SE = @as(c_int, 0x04be);
pub const XK_kana_SO = @as(c_int, 0x04bf);
pub const XK_kana_TA = @as(c_int, 0x04c0);
pub const XK_kana_CHI = @as(c_int, 0x04c1);
pub const XK_kana_TI = @as(c_int, 0x04c1);
pub const XK_kana_TSU = @as(c_int, 0x04c2);
pub const XK_kana_TU = @as(c_int, 0x04c2);
pub const XK_kana_TE = @as(c_int, 0x04c3);
pub const XK_kana_TO = @as(c_int, 0x04c4);
pub const XK_kana_NA = @as(c_int, 0x04c5);
pub const XK_kana_NI = @as(c_int, 0x04c6);
pub const XK_kana_NU = @as(c_int, 0x04c7);
pub const XK_kana_NE = @as(c_int, 0x04c8);
pub const XK_kana_NO = @as(c_int, 0x04c9);
pub const XK_kana_HA = @as(c_int, 0x04ca);
pub const XK_kana_HI = @as(c_int, 0x04cb);
pub const XK_kana_FU = @as(c_int, 0x04cc);
pub const XK_kana_HU = @as(c_int, 0x04cc);
pub const XK_kana_HE = @as(c_int, 0x04cd);
pub const XK_kana_HO = @as(c_int, 0x04ce);
pub const XK_kana_MA = @as(c_int, 0x04cf);
pub const XK_kana_MI = @as(c_int, 0x04d0);
pub const XK_kana_MU = @as(c_int, 0x04d1);
pub const XK_kana_ME = @as(c_int, 0x04d2);
pub const XK_kana_MO = @as(c_int, 0x04d3);
pub const XK_kana_YA = @as(c_int, 0x04d4);
pub const XK_kana_YU = @as(c_int, 0x04d5);
pub const XK_kana_YO = @as(c_int, 0x04d6);
pub const XK_kana_RA = @as(c_int, 0x04d7);
pub const XK_kana_RI = @as(c_int, 0x04d8);
pub const XK_kana_RU = @as(c_int, 0x04d9);
pub const XK_kana_RE = @as(c_int, 0x04da);
pub const XK_kana_RO = @as(c_int, 0x04db);
pub const XK_kana_WA = @as(c_int, 0x04dc);
pub const XK_kana_N = @as(c_int, 0x04dd);
pub const XK_voicedsound = @as(c_int, 0x04de);
pub const XK_semivoicedsound = @as(c_int, 0x04df);
pub const XK_kana_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_Farsi_0 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f0, .hex);
pub const XK_Farsi_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f1, .hex);
pub const XK_Farsi_2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f2, .hex);
pub const XK_Farsi_3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f3, .hex);
pub const XK_Farsi_4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f4, .hex);
pub const XK_Farsi_5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f5, .hex);
pub const XK_Farsi_6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f6, .hex);
pub const XK_Farsi_7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f7, .hex);
pub const XK_Farsi_8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f8, .hex);
pub const XK_Farsi_9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006f9, .hex);
pub const XK_Arabic_percent = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100066a, .hex);
pub const XK_Arabic_superscript_alef = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000670, .hex);
pub const XK_Arabic_tteh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000679, .hex);
pub const XK_Arabic_peh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100067e, .hex);
pub const XK_Arabic_tcheh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000686, .hex);
pub const XK_Arabic_ddal = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000688, .hex);
pub const XK_Arabic_rreh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000691, .hex);
pub const XK_Arabic_comma = @as(c_int, 0x05ac);
pub const XK_Arabic_fullstop = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006d4, .hex);
pub const XK_Arabic_0 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000660, .hex);
pub const XK_Arabic_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000661, .hex);
pub const XK_Arabic_2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000662, .hex);
pub const XK_Arabic_3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000663, .hex);
pub const XK_Arabic_4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000664, .hex);
pub const XK_Arabic_5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000665, .hex);
pub const XK_Arabic_6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000666, .hex);
pub const XK_Arabic_7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000667, .hex);
pub const XK_Arabic_8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000668, .hex);
pub const XK_Arabic_9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000669, .hex);
pub const XK_Arabic_semicolon = @as(c_int, 0x05bb);
pub const XK_Arabic_question_mark = @as(c_int, 0x05bf);
pub const XK_Arabic_hamza = @as(c_int, 0x05c1);
pub const XK_Arabic_maddaonalef = @as(c_int, 0x05c2);
pub const XK_Arabic_hamzaonalef = @as(c_int, 0x05c3);
pub const XK_Arabic_hamzaonwaw = @as(c_int, 0x05c4);
pub const XK_Arabic_hamzaunderalef = @as(c_int, 0x05c5);
pub const XK_Arabic_hamzaonyeh = @as(c_int, 0x05c6);
pub const XK_Arabic_alef = @as(c_int, 0x05c7);
pub const XK_Arabic_beh = @as(c_int, 0x05c8);
pub const XK_Arabic_tehmarbuta = @as(c_int, 0x05c9);
pub const XK_Arabic_teh = @as(c_int, 0x05ca);
pub const XK_Arabic_theh = @as(c_int, 0x05cb);
pub const XK_Arabic_jeem = @as(c_int, 0x05cc);
pub const XK_Arabic_hah = @as(c_int, 0x05cd);
pub const XK_Arabic_khah = @as(c_int, 0x05ce);
pub const XK_Arabic_dal = @as(c_int, 0x05cf);
pub const XK_Arabic_thal = @as(c_int, 0x05d0);
pub const XK_Arabic_ra = @as(c_int, 0x05d1);
pub const XK_Arabic_zain = @as(c_int, 0x05d2);
pub const XK_Arabic_seen = @as(c_int, 0x05d3);
pub const XK_Arabic_sheen = @as(c_int, 0x05d4);
pub const XK_Arabic_sad = @as(c_int, 0x05d5);
pub const XK_Arabic_dad = @as(c_int, 0x05d6);
pub const XK_Arabic_tah = @as(c_int, 0x05d7);
pub const XK_Arabic_zah = @as(c_int, 0x05d8);
pub const XK_Arabic_ain = @as(c_int, 0x05d9);
pub const XK_Arabic_ghain = @as(c_int, 0x05da);
pub const XK_Arabic_tatweel = @as(c_int, 0x05e0);
pub const XK_Arabic_feh = @as(c_int, 0x05e1);
pub const XK_Arabic_qaf = @as(c_int, 0x05e2);
pub const XK_Arabic_kaf = @as(c_int, 0x05e3);
pub const XK_Arabic_lam = @as(c_int, 0x05e4);
pub const XK_Arabic_meem = @as(c_int, 0x05e5);
pub const XK_Arabic_noon = @as(c_int, 0x05e6);
pub const XK_Arabic_ha = @as(c_int, 0x05e7);
pub const XK_Arabic_heh = @as(c_int, 0x05e7);
pub const XK_Arabic_waw = @as(c_int, 0x05e8);
pub const XK_Arabic_alefmaksura = @as(c_int, 0x05e9);
pub const XK_Arabic_yeh = @as(c_int, 0x05ea);
pub const XK_Arabic_fathatan = @as(c_int, 0x05eb);
pub const XK_Arabic_dammatan = @as(c_int, 0x05ec);
pub const XK_Arabic_kasratan = @as(c_int, 0x05ed);
pub const XK_Arabic_fatha = @as(c_int, 0x05ee);
pub const XK_Arabic_damma = @as(c_int, 0x05ef);
pub const XK_Arabic_kasra = @as(c_int, 0x05f0);
pub const XK_Arabic_shadda = @as(c_int, 0x05f1);
pub const XK_Arabic_sukun = @as(c_int, 0x05f2);
pub const XK_Arabic_madda_above = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000653, .hex);
pub const XK_Arabic_hamza_above = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000654, .hex);
pub const XK_Arabic_hamza_below = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000655, .hex);
pub const XK_Arabic_jeh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000698, .hex);
pub const XK_Arabic_veh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006a4, .hex);
pub const XK_Arabic_keheh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006a9, .hex);
pub const XK_Arabic_gaf = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006af, .hex);
pub const XK_Arabic_noon_ghunna = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006ba, .hex);
pub const XK_Arabic_heh_doachashmee = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006be, .hex);
pub const XK_Farsi_yeh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006cc, .hex);
pub const XK_Arabic_farsi_yeh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006cc, .hex);
pub const XK_Arabic_yeh_baree = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006d2, .hex);
pub const XK_Arabic_heh_goal = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10006c1, .hex);
pub const XK_Arabic_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_Cyrillic_GHE_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000492, .hex);
pub const XK_Cyrillic_ghe_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000493, .hex);
pub const XK_Cyrillic_ZHE_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000496, .hex);
pub const XK_Cyrillic_zhe_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000497, .hex);
pub const XK_Cyrillic_KA_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100049a, .hex);
pub const XK_Cyrillic_ka_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100049b, .hex);
pub const XK_Cyrillic_KA_vertstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100049c, .hex);
pub const XK_Cyrillic_ka_vertstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100049d, .hex);
pub const XK_Cyrillic_EN_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004a2, .hex);
pub const XK_Cyrillic_en_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004a3, .hex);
pub const XK_Cyrillic_U_straight = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004ae, .hex);
pub const XK_Cyrillic_u_straight = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004af, .hex);
pub const XK_Cyrillic_U_straight_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b0, .hex);
pub const XK_Cyrillic_u_straight_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b1, .hex);
pub const XK_Cyrillic_HA_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b2, .hex);
pub const XK_Cyrillic_ha_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b3, .hex);
pub const XK_Cyrillic_CHE_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b6, .hex);
pub const XK_Cyrillic_che_descender = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b7, .hex);
pub const XK_Cyrillic_CHE_vertstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b8, .hex);
pub const XK_Cyrillic_che_vertstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004b9, .hex);
pub const XK_Cyrillic_SHHA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004ba, .hex);
pub const XK_Cyrillic_shha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004bb, .hex);
pub const XK_Cyrillic_SCHWA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004d8, .hex);
pub const XK_Cyrillic_schwa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004d9, .hex);
pub const XK_Cyrillic_I_macron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004e2, .hex);
pub const XK_Cyrillic_i_macron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004e3, .hex);
pub const XK_Cyrillic_O_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004e8, .hex);
pub const XK_Cyrillic_o_bar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004e9, .hex);
pub const XK_Cyrillic_U_macron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004ee, .hex);
pub const XK_Cyrillic_u_macron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10004ef, .hex);
pub const XK_Serbian_dje = @as(c_int, 0x06a1);
pub const XK_Macedonia_gje = @as(c_int, 0x06a2);
pub const XK_Cyrillic_io = @as(c_int, 0x06a3);
pub const XK_Ukrainian_ie = @as(c_int, 0x06a4);
pub const XK_Ukranian_je = @as(c_int, 0x06a4);
pub const XK_Macedonia_dse = @as(c_int, 0x06a5);
pub const XK_Ukrainian_i = @as(c_int, 0x06a6);
pub const XK_Ukranian_i = @as(c_int, 0x06a6);
pub const XK_Ukrainian_yi = @as(c_int, 0x06a7);
pub const XK_Ukranian_yi = @as(c_int, 0x06a7);
pub const XK_Cyrillic_je = @as(c_int, 0x06a8);
pub const XK_Serbian_je = @as(c_int, 0x06a8);
pub const XK_Cyrillic_lje = @as(c_int, 0x06a9);
pub const XK_Serbian_lje = @as(c_int, 0x06a9);
pub const XK_Cyrillic_nje = @as(c_int, 0x06aa);
pub const XK_Serbian_nje = @as(c_int, 0x06aa);
pub const XK_Serbian_tshe = @as(c_int, 0x06ab);
pub const XK_Macedonia_kje = @as(c_int, 0x06ac);
pub const XK_Ukrainian_ghe_with_upturn = @as(c_int, 0x06ad);
pub const XK_Byelorussian_shortu = @as(c_int, 0x06ae);
pub const XK_Cyrillic_dzhe = @as(c_int, 0x06af);
pub const XK_Serbian_dze = @as(c_int, 0x06af);
pub const XK_numerosign = @as(c_int, 0x06b0);
pub const XK_Serbian_DJE = @as(c_int, 0x06b1);
pub const XK_Macedonia_GJE = @as(c_int, 0x06b2);
pub const XK_Cyrillic_IO = @as(c_int, 0x06b3);
pub const XK_Ukrainian_IE = @as(c_int, 0x06b4);
pub const XK_Ukranian_JE = @as(c_int, 0x06b4);
pub const XK_Macedonia_DSE = @as(c_int, 0x06b5);
pub const XK_Ukrainian_I = @as(c_int, 0x06b6);
pub const XK_Ukranian_I = @as(c_int, 0x06b6);
pub const XK_Ukrainian_YI = @as(c_int, 0x06b7);
pub const XK_Ukranian_YI = @as(c_int, 0x06b7);
pub const XK_Cyrillic_JE = @as(c_int, 0x06b8);
pub const XK_Serbian_JE = @as(c_int, 0x06b8);
pub const XK_Cyrillic_LJE = @as(c_int, 0x06b9);
pub const XK_Serbian_LJE = @as(c_int, 0x06b9);
pub const XK_Cyrillic_NJE = @as(c_int, 0x06ba);
pub const XK_Serbian_NJE = @as(c_int, 0x06ba);
pub const XK_Serbian_TSHE = @as(c_int, 0x06bb);
pub const XK_Macedonia_KJE = @as(c_int, 0x06bc);
pub const XK_Ukrainian_GHE_WITH_UPTURN = @as(c_int, 0x06bd);
pub const XK_Byelorussian_SHORTU = @as(c_int, 0x06be);
pub const XK_Cyrillic_DZHE = @as(c_int, 0x06bf);
pub const XK_Serbian_DZE = @as(c_int, 0x06bf);
pub const XK_Cyrillic_yu = @as(c_int, 0x06c0);
pub const XK_Cyrillic_a = @as(c_int, 0x06c1);
pub const XK_Cyrillic_be = @as(c_int, 0x06c2);
pub const XK_Cyrillic_tse = @as(c_int, 0x06c3);
pub const XK_Cyrillic_de = @as(c_int, 0x06c4);
pub const XK_Cyrillic_ie = @as(c_int, 0x06c5);
pub const XK_Cyrillic_ef = @as(c_int, 0x06c6);
pub const XK_Cyrillic_ghe = @as(c_int, 0x06c7);
pub const XK_Cyrillic_ha = @as(c_int, 0x06c8);
pub const XK_Cyrillic_i = @as(c_int, 0x06c9);
pub const XK_Cyrillic_shorti = @as(c_int, 0x06ca);
pub const XK_Cyrillic_ka = @as(c_int, 0x06cb);
pub const XK_Cyrillic_el = @as(c_int, 0x06cc);
pub const XK_Cyrillic_em = @as(c_int, 0x06cd);
pub const XK_Cyrillic_en = @as(c_int, 0x06ce);
pub const XK_Cyrillic_o = @as(c_int, 0x06cf);
pub const XK_Cyrillic_pe = @as(c_int, 0x06d0);
pub const XK_Cyrillic_ya = @as(c_int, 0x06d1);
pub const XK_Cyrillic_er = @as(c_int, 0x06d2);
pub const XK_Cyrillic_es = @as(c_int, 0x06d3);
pub const XK_Cyrillic_te = @as(c_int, 0x06d4);
pub const XK_Cyrillic_u = @as(c_int, 0x06d5);
pub const XK_Cyrillic_zhe = @as(c_int, 0x06d6);
pub const XK_Cyrillic_ve = @as(c_int, 0x06d7);
pub const XK_Cyrillic_softsign = @as(c_int, 0x06d8);
pub const XK_Cyrillic_yeru = @as(c_int, 0x06d9);
pub const XK_Cyrillic_ze = @as(c_int, 0x06da);
pub const XK_Cyrillic_sha = @as(c_int, 0x06db);
pub const XK_Cyrillic_e = @as(c_int, 0x06dc);
pub const XK_Cyrillic_shcha = @as(c_int, 0x06dd);
pub const XK_Cyrillic_che = @as(c_int, 0x06de);
pub const XK_Cyrillic_hardsign = @as(c_int, 0x06df);
pub const XK_Cyrillic_YU = @as(c_int, 0x06e0);
pub const XK_Cyrillic_A = @as(c_int, 0x06e1);
pub const XK_Cyrillic_BE = @as(c_int, 0x06e2);
pub const XK_Cyrillic_TSE = @as(c_int, 0x06e3);
pub const XK_Cyrillic_DE = @as(c_int, 0x06e4);
pub const XK_Cyrillic_IE = @as(c_int, 0x06e5);
pub const XK_Cyrillic_EF = @as(c_int, 0x06e6);
pub const XK_Cyrillic_GHE = @as(c_int, 0x06e7);
pub const XK_Cyrillic_HA = @as(c_int, 0x06e8);
pub const XK_Cyrillic_I = @as(c_int, 0x06e9);
pub const XK_Cyrillic_SHORTI = @as(c_int, 0x06ea);
pub const XK_Cyrillic_KA = @as(c_int, 0x06eb);
pub const XK_Cyrillic_EL = @as(c_int, 0x06ec);
pub const XK_Cyrillic_EM = @as(c_int, 0x06ed);
pub const XK_Cyrillic_EN = @as(c_int, 0x06ee);
pub const XK_Cyrillic_O = @as(c_int, 0x06ef);
pub const XK_Cyrillic_PE = @as(c_int, 0x06f0);
pub const XK_Cyrillic_YA = @as(c_int, 0x06f1);
pub const XK_Cyrillic_ER = @as(c_int, 0x06f2);
pub const XK_Cyrillic_ES = @as(c_int, 0x06f3);
pub const XK_Cyrillic_TE = @as(c_int, 0x06f4);
pub const XK_Cyrillic_U = @as(c_int, 0x06f5);
pub const XK_Cyrillic_ZHE = @as(c_int, 0x06f6);
pub const XK_Cyrillic_VE = @as(c_int, 0x06f7);
pub const XK_Cyrillic_SOFTSIGN = @as(c_int, 0x06f8);
pub const XK_Cyrillic_YERU = @as(c_int, 0x06f9);
pub const XK_Cyrillic_ZE = @as(c_int, 0x06fa);
pub const XK_Cyrillic_SHA = @as(c_int, 0x06fb);
pub const XK_Cyrillic_E = @as(c_int, 0x06fc);
pub const XK_Cyrillic_SHCHA = @as(c_int, 0x06fd);
pub const XK_Cyrillic_CHE = @as(c_int, 0x06fe);
pub const XK_Cyrillic_HARDSIGN = @as(c_int, 0x06ff);
pub const XK_Greek_ALPHAaccent = @as(c_int, 0x07a1);
pub const XK_Greek_EPSILONaccent = @as(c_int, 0x07a2);
pub const XK_Greek_ETAaccent = @as(c_int, 0x07a3);
pub const XK_Greek_IOTAaccent = @as(c_int, 0x07a4);
pub const XK_Greek_IOTAdieresis = @as(c_int, 0x07a5);
pub const XK_Greek_IOTAdiaeresis = @as(c_int, 0x07a5);
pub const XK_Greek_OMICRONaccent = @as(c_int, 0x07a7);
pub const XK_Greek_UPSILONaccent = @as(c_int, 0x07a8);
pub const XK_Greek_UPSILONdieresis = @as(c_int, 0x07a9);
pub const XK_Greek_OMEGAaccent = @as(c_int, 0x07ab);
pub const XK_Greek_accentdieresis = @as(c_int, 0x07ae);
pub const XK_Greek_horizbar = @as(c_int, 0x07af);
pub const XK_Greek_alphaaccent = @as(c_int, 0x07b1);
pub const XK_Greek_epsilonaccent = @as(c_int, 0x07b2);
pub const XK_Greek_etaaccent = @as(c_int, 0x07b3);
pub const XK_Greek_iotaaccent = @as(c_int, 0x07b4);
pub const XK_Greek_iotadieresis = @as(c_int, 0x07b5);
pub const XK_Greek_iotaaccentdieresis = @as(c_int, 0x07b6);
pub const XK_Greek_omicronaccent = @as(c_int, 0x07b7);
pub const XK_Greek_upsilonaccent = @as(c_int, 0x07b8);
pub const XK_Greek_upsilondieresis = @as(c_int, 0x07b9);
pub const XK_Greek_upsilonaccentdieresis = @as(c_int, 0x07ba);
pub const XK_Greek_omegaaccent = @as(c_int, 0x07bb);
pub const XK_Greek_ALPHA = @as(c_int, 0x07c1);
pub const XK_Greek_BETA = @as(c_int, 0x07c2);
pub const XK_Greek_GAMMA = @as(c_int, 0x07c3);
pub const XK_Greek_DELTA = @as(c_int, 0x07c4);
pub const XK_Greek_EPSILON = @as(c_int, 0x07c5);
pub const XK_Greek_ZETA = @as(c_int, 0x07c6);
pub const XK_Greek_ETA = @as(c_int, 0x07c7);
pub const XK_Greek_THETA = @as(c_int, 0x07c8);
pub const XK_Greek_IOTA = @as(c_int, 0x07c9);
pub const XK_Greek_KAPPA = @as(c_int, 0x07ca);
pub const XK_Greek_LAMDA = @as(c_int, 0x07cb);
pub const XK_Greek_LAMBDA = @as(c_int, 0x07cb);
pub const XK_Greek_MU = @as(c_int, 0x07cc);
pub const XK_Greek_NU = @as(c_int, 0x07cd);
pub const XK_Greek_XI = @as(c_int, 0x07ce);
pub const XK_Greek_OMICRON = @as(c_int, 0x07cf);
pub const XK_Greek_PI = @as(c_int, 0x07d0);
pub const XK_Greek_RHO = @as(c_int, 0x07d1);
pub const XK_Greek_SIGMA = @as(c_int, 0x07d2);
pub const XK_Greek_TAU = @as(c_int, 0x07d4);
pub const XK_Greek_UPSILON = @as(c_int, 0x07d5);
pub const XK_Greek_PHI = @as(c_int, 0x07d6);
pub const XK_Greek_CHI = @as(c_int, 0x07d7);
pub const XK_Greek_PSI = @as(c_int, 0x07d8);
pub const XK_Greek_OMEGA = @as(c_int, 0x07d9);
pub const XK_Greek_alpha = @as(c_int, 0x07e1);
pub const XK_Greek_beta = @as(c_int, 0x07e2);
pub const XK_Greek_gamma = @as(c_int, 0x07e3);
pub const XK_Greek_delta = @as(c_int, 0x07e4);
pub const XK_Greek_epsilon = @as(c_int, 0x07e5);
pub const XK_Greek_zeta = @as(c_int, 0x07e6);
pub const XK_Greek_eta = @as(c_int, 0x07e7);
pub const XK_Greek_theta = @as(c_int, 0x07e8);
pub const XK_Greek_iota = @as(c_int, 0x07e9);
pub const XK_Greek_kappa = @as(c_int, 0x07ea);
pub const XK_Greek_lamda = @as(c_int, 0x07eb);
pub const XK_Greek_lambda = @as(c_int, 0x07eb);
pub const XK_Greek_mu = @as(c_int, 0x07ec);
pub const XK_Greek_nu = @as(c_int, 0x07ed);
pub const XK_Greek_xi = @as(c_int, 0x07ee);
pub const XK_Greek_omicron = @as(c_int, 0x07ef);
pub const XK_Greek_pi = @as(c_int, 0x07f0);
pub const XK_Greek_rho = @as(c_int, 0x07f1);
pub const XK_Greek_sigma = @as(c_int, 0x07f2);
pub const XK_Greek_finalsmallsigma = @as(c_int, 0x07f3);
pub const XK_Greek_tau = @as(c_int, 0x07f4);
pub const XK_Greek_upsilon = @as(c_int, 0x07f5);
pub const XK_Greek_phi = @as(c_int, 0x07f6);
pub const XK_Greek_chi = @as(c_int, 0x07f7);
pub const XK_Greek_psi = @as(c_int, 0x07f8);
pub const XK_Greek_omega = @as(c_int, 0x07f9);
pub const XK_Greek_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_hebrew_doublelowline = @as(c_int, 0x0cdf);
pub const XK_hebrew_aleph = @as(c_int, 0x0ce0);
pub const XK_hebrew_bet = @as(c_int, 0x0ce1);
pub const XK_hebrew_beth = @as(c_int, 0x0ce1);
pub const XK_hebrew_gimel = @as(c_int, 0x0ce2);
pub const XK_hebrew_gimmel = @as(c_int, 0x0ce2);
pub const XK_hebrew_dalet = @as(c_int, 0x0ce3);
pub const XK_hebrew_daleth = @as(c_int, 0x0ce3);
pub const XK_hebrew_he = @as(c_int, 0x0ce4);
pub const XK_hebrew_waw = @as(c_int, 0x0ce5);
pub const XK_hebrew_zain = @as(c_int, 0x0ce6);
pub const XK_hebrew_zayin = @as(c_int, 0x0ce6);
pub const XK_hebrew_chet = @as(c_int, 0x0ce7);
pub const XK_hebrew_het = @as(c_int, 0x0ce7);
pub const XK_hebrew_tet = @as(c_int, 0x0ce8);
pub const XK_hebrew_teth = @as(c_int, 0x0ce8);
pub const XK_hebrew_yod = @as(c_int, 0x0ce9);
pub const XK_hebrew_finalkaph = @as(c_int, 0x0cea);
pub const XK_hebrew_kaph = @as(c_int, 0x0ceb);
pub const XK_hebrew_lamed = @as(c_int, 0x0cec);
pub const XK_hebrew_finalmem = @as(c_int, 0x0ced);
pub const XK_hebrew_mem = @as(c_int, 0x0cee);
pub const XK_hebrew_finalnun = @as(c_int, 0x0cef);
pub const XK_hebrew_nun = @as(c_int, 0x0cf0);
pub const XK_hebrew_samech = @as(c_int, 0x0cf1);
pub const XK_hebrew_samekh = @as(c_int, 0x0cf1);
pub const XK_hebrew_ayin = @as(c_int, 0x0cf2);
pub const XK_hebrew_finalpe = @as(c_int, 0x0cf3);
pub const XK_hebrew_pe = @as(c_int, 0x0cf4);
pub const XK_hebrew_finalzade = @as(c_int, 0x0cf5);
pub const XK_hebrew_finalzadi = @as(c_int, 0x0cf5);
pub const XK_hebrew_zade = @as(c_int, 0x0cf6);
pub const XK_hebrew_zadi = @as(c_int, 0x0cf6);
pub const XK_hebrew_qoph = @as(c_int, 0x0cf7);
pub const XK_hebrew_kuf = @as(c_int, 0x0cf7);
pub const XK_hebrew_resh = @as(c_int, 0x0cf8);
pub const XK_hebrew_shin = @as(c_int, 0x0cf9);
pub const XK_hebrew_taw = @as(c_int, 0x0cfa);
pub const XK_hebrew_taf = @as(c_int, 0x0cfa);
pub const XK_Hebrew_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_Thai_kokai = @as(c_int, 0x0da1);
pub const XK_Thai_khokhai = @as(c_int, 0x0da2);
pub const XK_Thai_khokhuat = @as(c_int, 0x0da3);
pub const XK_Thai_khokhwai = @as(c_int, 0x0da4);
pub const XK_Thai_khokhon = @as(c_int, 0x0da5);
pub const XK_Thai_khorakhang = @as(c_int, 0x0da6);
pub const XK_Thai_ngongu = @as(c_int, 0x0da7);
pub const XK_Thai_chochan = @as(c_int, 0x0da8);
pub const XK_Thai_choching = @as(c_int, 0x0da9);
pub const XK_Thai_chochang = @as(c_int, 0x0daa);
pub const XK_Thai_soso = @as(c_int, 0x0dab);
pub const XK_Thai_chochoe = @as(c_int, 0x0dac);
pub const XK_Thai_yoying = @as(c_int, 0x0dad);
pub const XK_Thai_dochada = @as(c_int, 0x0dae);
pub const XK_Thai_topatak = @as(c_int, 0x0daf);
pub const XK_Thai_thothan = @as(c_int, 0x0db0);
pub const XK_Thai_thonangmontho = @as(c_int, 0x0db1);
pub const XK_Thai_thophuthao = @as(c_int, 0x0db2);
pub const XK_Thai_nonen = @as(c_int, 0x0db3);
pub const XK_Thai_dodek = @as(c_int, 0x0db4);
pub const XK_Thai_totao = @as(c_int, 0x0db5);
pub const XK_Thai_thothung = @as(c_int, 0x0db6);
pub const XK_Thai_thothahan = @as(c_int, 0x0db7);
pub const XK_Thai_thothong = @as(c_int, 0x0db8);
pub const XK_Thai_nonu = @as(c_int, 0x0db9);
pub const XK_Thai_bobaimai = @as(c_int, 0x0dba);
pub const XK_Thai_popla = @as(c_int, 0x0dbb);
pub const XK_Thai_phophung = @as(c_int, 0x0dbc);
pub const XK_Thai_fofa = @as(c_int, 0x0dbd);
pub const XK_Thai_phophan = @as(c_int, 0x0dbe);
pub const XK_Thai_fofan = @as(c_int, 0x0dbf);
pub const XK_Thai_phosamphao = @as(c_int, 0x0dc0);
pub const XK_Thai_moma = @as(c_int, 0x0dc1);
pub const XK_Thai_yoyak = @as(c_int, 0x0dc2);
pub const XK_Thai_rorua = @as(c_int, 0x0dc3);
pub const XK_Thai_ru = @as(c_int, 0x0dc4);
pub const XK_Thai_loling = @as(c_int, 0x0dc5);
pub const XK_Thai_lu = @as(c_int, 0x0dc6);
pub const XK_Thai_wowaen = @as(c_int, 0x0dc7);
pub const XK_Thai_sosala = @as(c_int, 0x0dc8);
pub const XK_Thai_sorusi = @as(c_int, 0x0dc9);
pub const XK_Thai_sosua = @as(c_int, 0x0dca);
pub const XK_Thai_hohip = @as(c_int, 0x0dcb);
pub const XK_Thai_lochula = @as(c_int, 0x0dcc);
pub const XK_Thai_oang = @as(c_int, 0x0dcd);
pub const XK_Thai_honokhuk = @as(c_int, 0x0dce);
pub const XK_Thai_paiyannoi = @as(c_int, 0x0dcf);
pub const XK_Thai_saraa = @as(c_int, 0x0dd0);
pub const XK_Thai_maihanakat = @as(c_int, 0x0dd1);
pub const XK_Thai_saraaa = @as(c_int, 0x0dd2);
pub const XK_Thai_saraam = @as(c_int, 0x0dd3);
pub const XK_Thai_sarai = @as(c_int, 0x0dd4);
pub const XK_Thai_saraii = @as(c_int, 0x0dd5);
pub const XK_Thai_saraue = @as(c_int, 0x0dd6);
pub const XK_Thai_sarauee = @as(c_int, 0x0dd7);
pub const XK_Thai_sarau = @as(c_int, 0x0dd8);
pub const XK_Thai_sarauu = @as(c_int, 0x0dd9);
pub const XK_Thai_phinthu = @as(c_int, 0x0dda);
pub const XK_Thai_maihanakat_maitho = @as(c_int, 0x0dde);
pub const XK_Thai_baht = @as(c_int, 0x0ddf);
pub const XK_Thai_sarae = @as(c_int, 0x0de0);
pub const XK_Thai_saraae = @as(c_int, 0x0de1);
pub const XK_Thai_sarao = @as(c_int, 0x0de2);
pub const XK_Thai_saraaimaimuan = @as(c_int, 0x0de3);
pub const XK_Thai_saraaimaimalai = @as(c_int, 0x0de4);
pub const XK_Thai_lakkhangyao = @as(c_int, 0x0de5);
pub const XK_Thai_maiyamok = @as(c_int, 0x0de6);
pub const XK_Thai_maitaikhu = @as(c_int, 0x0de7);
pub const XK_Thai_maiek = @as(c_int, 0x0de8);
pub const XK_Thai_maitho = @as(c_int, 0x0de9);
pub const XK_Thai_maitri = @as(c_int, 0x0dea);
pub const XK_Thai_maichattawa = @as(c_int, 0x0deb);
pub const XK_Thai_thanthakhat = @as(c_int, 0x0dec);
pub const XK_Thai_nikhahit = @as(c_int, 0x0ded);
pub const XK_Thai_leksun = @as(c_int, 0x0df0);
pub const XK_Thai_leknung = @as(c_int, 0x0df1);
pub const XK_Thai_leksong = @as(c_int, 0x0df2);
pub const XK_Thai_leksam = @as(c_int, 0x0df3);
pub const XK_Thai_leksi = @as(c_int, 0x0df4);
pub const XK_Thai_lekha = @as(c_int, 0x0df5);
pub const XK_Thai_lekhok = @as(c_int, 0x0df6);
pub const XK_Thai_lekchet = @as(c_int, 0x0df7);
pub const XK_Thai_lekpaet = @as(c_int, 0x0df8);
pub const XK_Thai_lekkao = @as(c_int, 0x0df9);
pub const XK_Hangul = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff31, .hex);
pub const XK_Hangul_Start = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff32, .hex);
pub const XK_Hangul_End = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff33, .hex);
pub const XK_Hangul_Hanja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff34, .hex);
pub const XK_Hangul_Jamo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff35, .hex);
pub const XK_Hangul_Romaja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff36, .hex);
pub const XK_Hangul_Codeinput = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff37, .hex);
pub const XK_Hangul_Jeonja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff38, .hex);
pub const XK_Hangul_Banja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff39, .hex);
pub const XK_Hangul_PreHanja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3a, .hex);
pub const XK_Hangul_PostHanja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3b, .hex);
pub const XK_Hangul_SingleCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3c, .hex);
pub const XK_Hangul_MultipleCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3d, .hex);
pub const XK_Hangul_PreviousCandidate = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3e, .hex);
pub const XK_Hangul_Special = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff3f, .hex);
pub const XK_Hangul_switch = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xff7e, .hex);
pub const XK_Hangul_Kiyeog = @as(c_int, 0x0ea1);
pub const XK_Hangul_SsangKiyeog = @as(c_int, 0x0ea2);
pub const XK_Hangul_KiyeogSios = @as(c_int, 0x0ea3);
pub const XK_Hangul_Nieun = @as(c_int, 0x0ea4);
pub const XK_Hangul_NieunJieuj = @as(c_int, 0x0ea5);
pub const XK_Hangul_NieunHieuh = @as(c_int, 0x0ea6);
pub const XK_Hangul_Dikeud = @as(c_int, 0x0ea7);
pub const XK_Hangul_SsangDikeud = @as(c_int, 0x0ea8);
pub const XK_Hangul_Rieul = @as(c_int, 0x0ea9);
pub const XK_Hangul_RieulKiyeog = @as(c_int, 0x0eaa);
pub const XK_Hangul_RieulMieum = @as(c_int, 0x0eab);
pub const XK_Hangul_RieulPieub = @as(c_int, 0x0eac);
pub const XK_Hangul_RieulSios = @as(c_int, 0x0ead);
pub const XK_Hangul_RieulTieut = @as(c_int, 0x0eae);
pub const XK_Hangul_RieulPhieuf = @as(c_int, 0x0eaf);
pub const XK_Hangul_RieulHieuh = @as(c_int, 0x0eb0);
pub const XK_Hangul_Mieum = @as(c_int, 0x0eb1);
pub const XK_Hangul_Pieub = @as(c_int, 0x0eb2);
pub const XK_Hangul_SsangPieub = @as(c_int, 0x0eb3);
pub const XK_Hangul_PieubSios = @as(c_int, 0x0eb4);
pub const XK_Hangul_Sios = @as(c_int, 0x0eb5);
pub const XK_Hangul_SsangSios = @as(c_int, 0x0eb6);
pub const XK_Hangul_Ieung = @as(c_int, 0x0eb7);
pub const XK_Hangul_Jieuj = @as(c_int, 0x0eb8);
pub const XK_Hangul_SsangJieuj = @as(c_int, 0x0eb9);
pub const XK_Hangul_Cieuc = @as(c_int, 0x0eba);
pub const XK_Hangul_Khieuq = @as(c_int, 0x0ebb);
pub const XK_Hangul_Tieut = @as(c_int, 0x0ebc);
pub const XK_Hangul_Phieuf = @as(c_int, 0x0ebd);
pub const XK_Hangul_Hieuh = @as(c_int, 0x0ebe);
pub const XK_Hangul_A = @as(c_int, 0x0ebf);
pub const XK_Hangul_AE = @as(c_int, 0x0ec0);
pub const XK_Hangul_YA = @as(c_int, 0x0ec1);
pub const XK_Hangul_YAE = @as(c_int, 0x0ec2);
pub const XK_Hangul_EO = @as(c_int, 0x0ec3);
pub const XK_Hangul_E = @as(c_int, 0x0ec4);
pub const XK_Hangul_YEO = @as(c_int, 0x0ec5);
pub const XK_Hangul_YE = @as(c_int, 0x0ec6);
pub const XK_Hangul_O = @as(c_int, 0x0ec7);
pub const XK_Hangul_WA = @as(c_int, 0x0ec8);
pub const XK_Hangul_WAE = @as(c_int, 0x0ec9);
pub const XK_Hangul_OE = @as(c_int, 0x0eca);
pub const XK_Hangul_YO = @as(c_int, 0x0ecb);
pub const XK_Hangul_U = @as(c_int, 0x0ecc);
pub const XK_Hangul_WEO = @as(c_int, 0x0ecd);
pub const XK_Hangul_WE = @as(c_int, 0x0ece);
pub const XK_Hangul_WI = @as(c_int, 0x0ecf);
pub const XK_Hangul_YU = @as(c_int, 0x0ed0);
pub const XK_Hangul_EU = @as(c_int, 0x0ed1);
pub const XK_Hangul_YI = @as(c_int, 0x0ed2);
pub const XK_Hangul_I = @as(c_int, 0x0ed3);
pub const XK_Hangul_J_Kiyeog = @as(c_int, 0x0ed4);
pub const XK_Hangul_J_SsangKiyeog = @as(c_int, 0x0ed5);
pub const XK_Hangul_J_KiyeogSios = @as(c_int, 0x0ed6);
pub const XK_Hangul_J_Nieun = @as(c_int, 0x0ed7);
pub const XK_Hangul_J_NieunJieuj = @as(c_int, 0x0ed8);
pub const XK_Hangul_J_NieunHieuh = @as(c_int, 0x0ed9);
pub const XK_Hangul_J_Dikeud = @as(c_int, 0x0eda);
pub const XK_Hangul_J_Rieul = @as(c_int, 0x0edb);
pub const XK_Hangul_J_RieulKiyeog = @as(c_int, 0x0edc);
pub const XK_Hangul_J_RieulMieum = @as(c_int, 0x0edd);
pub const XK_Hangul_J_RieulPieub = @as(c_int, 0x0ede);
pub const XK_Hangul_J_RieulSios = @as(c_int, 0x0edf);
pub const XK_Hangul_J_RieulTieut = @as(c_int, 0x0ee0);
pub const XK_Hangul_J_RieulPhieuf = @as(c_int, 0x0ee1);
pub const XK_Hangul_J_RieulHieuh = @as(c_int, 0x0ee2);
pub const XK_Hangul_J_Mieum = @as(c_int, 0x0ee3);
pub const XK_Hangul_J_Pieub = @as(c_int, 0x0ee4);
pub const XK_Hangul_J_PieubSios = @as(c_int, 0x0ee5);
pub const XK_Hangul_J_Sios = @as(c_int, 0x0ee6);
pub const XK_Hangul_J_SsangSios = @as(c_int, 0x0ee7);
pub const XK_Hangul_J_Ieung = @as(c_int, 0x0ee8);
pub const XK_Hangul_J_Jieuj = @as(c_int, 0x0ee9);
pub const XK_Hangul_J_Cieuc = @as(c_int, 0x0eea);
pub const XK_Hangul_J_Khieuq = @as(c_int, 0x0eeb);
pub const XK_Hangul_J_Tieut = @as(c_int, 0x0eec);
pub const XK_Hangul_J_Phieuf = @as(c_int, 0x0eed);
pub const XK_Hangul_J_Hieuh = @as(c_int, 0x0eee);
pub const XK_Hangul_RieulYeorinHieuh = @as(c_int, 0x0eef);
pub const XK_Hangul_SunkyeongeumMieum = @as(c_int, 0x0ef0);
pub const XK_Hangul_SunkyeongeumPieub = @as(c_int, 0x0ef1);
pub const XK_Hangul_PanSios = @as(c_int, 0x0ef2);
pub const XK_Hangul_KkogjiDalrinIeung = @as(c_int, 0x0ef3);
pub const XK_Hangul_SunkyeongeumPhieuf = @as(c_int, 0x0ef4);
pub const XK_Hangul_YeorinHieuh = @as(c_int, 0x0ef5);
pub const XK_Hangul_AraeA = @as(c_int, 0x0ef6);
pub const XK_Hangul_AraeAE = @as(c_int, 0x0ef7);
pub const XK_Hangul_J_PanSios = @as(c_int, 0x0ef8);
pub const XK_Hangul_J_KkogjiDalrinIeung = @as(c_int, 0x0ef9);
pub const XK_Hangul_J_YeorinHieuh = @as(c_int, 0x0efa);
pub const XK_Korean_Won = @as(c_int, 0x0eff);
pub const XK_Armenian_ligature_ew = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000587, .hex);
pub const XK_Armenian_full_stop = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000589, .hex);
pub const XK_Armenian_verjaket = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000589, .hex);
pub const XK_Armenian_separation_mark = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055d, .hex);
pub const XK_Armenian_but = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055d, .hex);
pub const XK_Armenian_hyphen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100058a, .hex);
pub const XK_Armenian_yentamna = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100058a, .hex);
pub const XK_Armenian_exclam = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055c, .hex);
pub const XK_Armenian_amanak = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055c, .hex);
pub const XK_Armenian_accent = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055b, .hex);
pub const XK_Armenian_shesht = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055b, .hex);
pub const XK_Armenian_question = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055e, .hex);
pub const XK_Armenian_paruyk = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055e, .hex);
pub const XK_Armenian_AYB = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000531, .hex);
pub const XK_Armenian_ayb = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000561, .hex);
pub const XK_Armenian_BEN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000532, .hex);
pub const XK_Armenian_ben = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000562, .hex);
pub const XK_Armenian_GIM = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000533, .hex);
pub const XK_Armenian_gim = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000563, .hex);
pub const XK_Armenian_DA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000534, .hex);
pub const XK_Armenian_da = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000564, .hex);
pub const XK_Armenian_YECH = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000535, .hex);
pub const XK_Armenian_yech = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000565, .hex);
pub const XK_Armenian_ZA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000536, .hex);
pub const XK_Armenian_za = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000566, .hex);
pub const XK_Armenian_E = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000537, .hex);
pub const XK_Armenian_e = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000567, .hex);
pub const XK_Armenian_AT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000538, .hex);
pub const XK_Armenian_at = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000568, .hex);
pub const XK_Armenian_TO = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000539, .hex);
pub const XK_Armenian_to = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000569, .hex);
pub const XK_Armenian_ZHE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053a, .hex);
pub const XK_Armenian_zhe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056a, .hex);
pub const XK_Armenian_INI = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053b, .hex);
pub const XK_Armenian_ini = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056b, .hex);
pub const XK_Armenian_LYUN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053c, .hex);
pub const XK_Armenian_lyun = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056c, .hex);
pub const XK_Armenian_KHE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053d, .hex);
pub const XK_Armenian_khe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056d, .hex);
pub const XK_Armenian_TSA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053e, .hex);
pub const XK_Armenian_tsa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056e, .hex);
pub const XK_Armenian_KEN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100053f, .hex);
pub const XK_Armenian_ken = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100056f, .hex);
pub const XK_Armenian_HO = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000540, .hex);
pub const XK_Armenian_ho = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000570, .hex);
pub const XK_Armenian_DZA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000541, .hex);
pub const XK_Armenian_dza = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000571, .hex);
pub const XK_Armenian_GHAT = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000542, .hex);
pub const XK_Armenian_ghat = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000572, .hex);
pub const XK_Armenian_TCHE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000543, .hex);
pub const XK_Armenian_tche = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000573, .hex);
pub const XK_Armenian_MEN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000544, .hex);
pub const XK_Armenian_men = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000574, .hex);
pub const XK_Armenian_HI = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000545, .hex);
pub const XK_Armenian_hi = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000575, .hex);
pub const XK_Armenian_NU = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000546, .hex);
pub const XK_Armenian_nu = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000576, .hex);
pub const XK_Armenian_SHA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000547, .hex);
pub const XK_Armenian_sha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000577, .hex);
pub const XK_Armenian_VO = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000548, .hex);
pub const XK_Armenian_vo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000578, .hex);
pub const XK_Armenian_CHA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000549, .hex);
pub const XK_Armenian_cha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000579, .hex);
pub const XK_Armenian_PE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054a, .hex);
pub const XK_Armenian_pe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057a, .hex);
pub const XK_Armenian_JE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054b, .hex);
pub const XK_Armenian_je = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057b, .hex);
pub const XK_Armenian_RA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054c, .hex);
pub const XK_Armenian_ra = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057c, .hex);
pub const XK_Armenian_SE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054d, .hex);
pub const XK_Armenian_se = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057d, .hex);
pub const XK_Armenian_VEV = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054e, .hex);
pub const XK_Armenian_vev = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057e, .hex);
pub const XK_Armenian_TYUN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100054f, .hex);
pub const XK_Armenian_tyun = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100057f, .hex);
pub const XK_Armenian_RE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000550, .hex);
pub const XK_Armenian_re = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000580, .hex);
pub const XK_Armenian_TSO = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000551, .hex);
pub const XK_Armenian_tso = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000581, .hex);
pub const XK_Armenian_VYUN = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000552, .hex);
pub const XK_Armenian_vyun = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000582, .hex);
pub const XK_Armenian_PYUR = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000553, .hex);
pub const XK_Armenian_pyur = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000583, .hex);
pub const XK_Armenian_KE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000554, .hex);
pub const XK_Armenian_ke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000584, .hex);
pub const XK_Armenian_O = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000555, .hex);
pub const XK_Armenian_o = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000585, .hex);
pub const XK_Armenian_FE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000556, .hex);
pub const XK_Armenian_fe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000586, .hex);
pub const XK_Armenian_apostrophe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100055a, .hex);
pub const XK_Georgian_an = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d0, .hex);
pub const XK_Georgian_ban = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d1, .hex);
pub const XK_Georgian_gan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d2, .hex);
pub const XK_Georgian_don = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d3, .hex);
pub const XK_Georgian_en = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d4, .hex);
pub const XK_Georgian_vin = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d5, .hex);
pub const XK_Georgian_zen = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d6, .hex);
pub const XK_Georgian_tan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d7, .hex);
pub const XK_Georgian_in = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d8, .hex);
pub const XK_Georgian_kan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010d9, .hex);
pub const XK_Georgian_las = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010da, .hex);
pub const XK_Georgian_man = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010db, .hex);
pub const XK_Georgian_nar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010dc, .hex);
pub const XK_Georgian_on = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010dd, .hex);
pub const XK_Georgian_par = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010de, .hex);
pub const XK_Georgian_zhar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010df, .hex);
pub const XK_Georgian_rae = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e0, .hex);
pub const XK_Georgian_san = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e1, .hex);
pub const XK_Georgian_tar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e2, .hex);
pub const XK_Georgian_un = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e3, .hex);
pub const XK_Georgian_phar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e4, .hex);
pub const XK_Georgian_khar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e5, .hex);
pub const XK_Georgian_ghan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e6, .hex);
pub const XK_Georgian_qar = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e7, .hex);
pub const XK_Georgian_shin = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e8, .hex);
pub const XK_Georgian_chin = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010e9, .hex);
pub const XK_Georgian_can = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010ea, .hex);
pub const XK_Georgian_jil = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010eb, .hex);
pub const XK_Georgian_cil = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010ec, .hex);
pub const XK_Georgian_char = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010ed, .hex);
pub const XK_Georgian_xan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010ee, .hex);
pub const XK_Georgian_jhan = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010ef, .hex);
pub const XK_Georgian_hae = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f0, .hex);
pub const XK_Georgian_he = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f1, .hex);
pub const XK_Georgian_hie = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f2, .hex);
pub const XK_Georgian_we = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f3, .hex);
pub const XK_Georgian_har = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f4, .hex);
pub const XK_Georgian_hoe = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f5, .hex);
pub const XK_Georgian_fi = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10010f6, .hex);
pub const XK_Xabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e8a, .hex);
pub const XK_Ibreve = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100012c, .hex);
pub const XK_Zstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001b5, .hex);
pub const XK_Gcaron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001e6, .hex);
pub const XK_Ocaron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001d1, .hex);
pub const XK_Obarred = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100019f, .hex);
pub const XK_xabovedot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e8b, .hex);
pub const XK_ibreve = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100012d, .hex);
pub const XK_zstroke = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001b6, .hex);
pub const XK_gcaron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001e7, .hex);
pub const XK_ocaron = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001d2, .hex);
pub const XK_obarred = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000275, .hex);
pub const XK_SCHWA = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100018f, .hex);
pub const XK_schwa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000259, .hex);
pub const XK_EZH = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001b7, .hex);
pub const XK_ezh = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000292, .hex);
pub const XK_Lbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e36, .hex);
pub const XK_lbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001e37, .hex);
pub const XK_Abelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea0, .hex);
pub const XK_abelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea1, .hex);
pub const XK_Ahook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea2, .hex);
pub const XK_ahook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea3, .hex);
pub const XK_Acircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea4, .hex);
pub const XK_acircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea5, .hex);
pub const XK_Acircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea6, .hex);
pub const XK_acircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea7, .hex);
pub const XK_Acircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea8, .hex);
pub const XK_acircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ea9, .hex);
pub const XK_Acircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eaa, .hex);
pub const XK_acircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eab, .hex);
pub const XK_Acircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eac, .hex);
pub const XK_acircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ead, .hex);
pub const XK_Abreveacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eae, .hex);
pub const XK_abreveacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eaf, .hex);
pub const XK_Abrevegrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb0, .hex);
pub const XK_abrevegrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb1, .hex);
pub const XK_Abrevehook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb2, .hex);
pub const XK_abrevehook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb3, .hex);
pub const XK_Abrevetilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb4, .hex);
pub const XK_abrevetilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb5, .hex);
pub const XK_Abrevebelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb6, .hex);
pub const XK_abrevebelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb7, .hex);
pub const XK_Ebelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb8, .hex);
pub const XK_ebelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eb9, .hex);
pub const XK_Ehook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eba, .hex);
pub const XK_ehook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ebb, .hex);
pub const XK_Etilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ebc, .hex);
pub const XK_etilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ebd, .hex);
pub const XK_Ecircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ebe, .hex);
pub const XK_ecircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ebf, .hex);
pub const XK_Ecircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec0, .hex);
pub const XK_ecircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec1, .hex);
pub const XK_Ecircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec2, .hex);
pub const XK_ecircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec3, .hex);
pub const XK_Ecircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec4, .hex);
pub const XK_ecircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec5, .hex);
pub const XK_Ecircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec6, .hex);
pub const XK_ecircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec7, .hex);
pub const XK_Ihook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec8, .hex);
pub const XK_ihook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ec9, .hex);
pub const XK_Ibelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eca, .hex);
pub const XK_ibelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ecb, .hex);
pub const XK_Obelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ecc, .hex);
pub const XK_obelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ecd, .hex);
pub const XK_Ohook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ece, .hex);
pub const XK_ohook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ecf, .hex);
pub const XK_Ocircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed0, .hex);
pub const XK_ocircumflexacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed1, .hex);
pub const XK_Ocircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed2, .hex);
pub const XK_ocircumflexgrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed3, .hex);
pub const XK_Ocircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed4, .hex);
pub const XK_ocircumflexhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed5, .hex);
pub const XK_Ocircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed6, .hex);
pub const XK_ocircumflextilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed7, .hex);
pub const XK_Ocircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed8, .hex);
pub const XK_ocircumflexbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ed9, .hex);
pub const XK_Ohornacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eda, .hex);
pub const XK_ohornacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001edb, .hex);
pub const XK_Ohorngrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001edc, .hex);
pub const XK_ohorngrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001edd, .hex);
pub const XK_Ohornhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ede, .hex);
pub const XK_ohornhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001edf, .hex);
pub const XK_Ohorntilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee0, .hex);
pub const XK_ohorntilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee1, .hex);
pub const XK_Ohornbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee2, .hex);
pub const XK_ohornbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee3, .hex);
pub const XK_Ubelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee4, .hex);
pub const XK_ubelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee5, .hex);
pub const XK_Uhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee6, .hex);
pub const XK_uhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee7, .hex);
pub const XK_Uhornacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee8, .hex);
pub const XK_uhornacute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ee9, .hex);
pub const XK_Uhorngrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eea, .hex);
pub const XK_uhorngrave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eeb, .hex);
pub const XK_Uhornhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eec, .hex);
pub const XK_uhornhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eed, .hex);
pub const XK_Uhorntilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eee, .hex);
pub const XK_uhorntilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001eef, .hex);
pub const XK_Uhornbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef0, .hex);
pub const XK_uhornbelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef1, .hex);
pub const XK_Ybelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef4, .hex);
pub const XK_ybelowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef5, .hex);
pub const XK_Yhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef6, .hex);
pub const XK_yhook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef7, .hex);
pub const XK_Ytilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef8, .hex);
pub const XK_ytilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1001ef9, .hex);
pub const XK_Ohorn = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001a0, .hex);
pub const XK_ohorn = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001a1, .hex);
pub const XK_Uhorn = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001af, .hex);
pub const XK_uhorn = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10001b0, .hex);
pub const XK_combining_tilde = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000303, .hex);
pub const XK_combining_grave = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000300, .hex);
pub const XK_combining_acute = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000301, .hex);
pub const XK_combining_hook = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000309, .hex);
pub const XK_combining_belowdot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000323, .hex);
pub const XK_EcuSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a0, .hex);
pub const XK_ColonSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a1, .hex);
pub const XK_CruzeiroSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a2, .hex);
pub const XK_FFrancSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a3, .hex);
pub const XK_LiraSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a4, .hex);
pub const XK_MillSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a5, .hex);
pub const XK_NairaSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a6, .hex);
pub const XK_PesetaSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a7, .hex);
pub const XK_RupeeSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a8, .hex);
pub const XK_WonSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020a9, .hex);
pub const XK_NewSheqelSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020aa, .hex);
pub const XK_DongSign = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10020ab, .hex);
pub const XK_EuroSign = @as(c_int, 0x20ac);
pub const XK_zerosuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002070, .hex);
pub const XK_foursuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002074, .hex);
pub const XK_fivesuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002075, .hex);
pub const XK_sixsuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002076, .hex);
pub const XK_sevensuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002077, .hex);
pub const XK_eightsuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002078, .hex);
pub const XK_ninesuperior = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002079, .hex);
pub const XK_zerosubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002080, .hex);
pub const XK_onesubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002081, .hex);
pub const XK_twosubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002082, .hex);
pub const XK_threesubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002083, .hex);
pub const XK_foursubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002084, .hex);
pub const XK_fivesubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002085, .hex);
pub const XK_sixsubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002086, .hex);
pub const XK_sevensubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002087, .hex);
pub const XK_eightsubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002088, .hex);
pub const XK_ninesubscript = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002089, .hex);
pub const XK_partdifferential = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002202, .hex);
pub const XK_emptyset = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002205, .hex);
pub const XK_elementof = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002208, .hex);
pub const XK_notelementof = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002209, .hex);
pub const XK_containsas = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100220B, .hex);
pub const XK_squareroot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100221A, .hex);
pub const XK_cuberoot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100221B, .hex);
pub const XK_fourthroot = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100221C, .hex);
pub const XK_dintegral = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100222C, .hex);
pub const XK_tintegral = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100222D, .hex);
pub const XK_because = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002235, .hex);
pub const XK_approxeq = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002248, .hex);
pub const XK_notapproxeq = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002247, .hex);
pub const XK_notidentical = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002262, .hex);
pub const XK_stricteq = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002263, .hex);
pub const XK_braille_dot_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff1, .hex);
pub const XK_braille_dot_2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff2, .hex);
pub const XK_braille_dot_3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff3, .hex);
pub const XK_braille_dot_4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff4, .hex);
pub const XK_braille_dot_5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff5, .hex);
pub const XK_braille_dot_6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff6, .hex);
pub const XK_braille_dot_7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff7, .hex);
pub const XK_braille_dot_8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff8, .hex);
pub const XK_braille_dot_9 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfff9, .hex);
pub const XK_braille_dot_10 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0xfffa, .hex);
pub const XK_braille_blank = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002800, .hex);
pub const XK_braille_dots_1 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002801, .hex);
pub const XK_braille_dots_2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002802, .hex);
pub const XK_braille_dots_12 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002803, .hex);
pub const XK_braille_dots_3 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002804, .hex);
pub const XK_braille_dots_13 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002805, .hex);
pub const XK_braille_dots_23 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002806, .hex);
pub const XK_braille_dots_123 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002807, .hex);
pub const XK_braille_dots_4 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002808, .hex);
pub const XK_braille_dots_14 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002809, .hex);
pub const XK_braille_dots_24 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280a, .hex);
pub const XK_braille_dots_124 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280b, .hex);
pub const XK_braille_dots_34 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280c, .hex);
pub const XK_braille_dots_134 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280d, .hex);
pub const XK_braille_dots_234 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280e, .hex);
pub const XK_braille_dots_1234 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100280f, .hex);
pub const XK_braille_dots_5 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002810, .hex);
pub const XK_braille_dots_15 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002811, .hex);
pub const XK_braille_dots_25 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002812, .hex);
pub const XK_braille_dots_125 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002813, .hex);
pub const XK_braille_dots_35 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002814, .hex);
pub const XK_braille_dots_135 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002815, .hex);
pub const XK_braille_dots_235 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002816, .hex);
pub const XK_braille_dots_1235 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002817, .hex);
pub const XK_braille_dots_45 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002818, .hex);
pub const XK_braille_dots_145 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002819, .hex);
pub const XK_braille_dots_245 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281a, .hex);
pub const XK_braille_dots_1245 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281b, .hex);
pub const XK_braille_dots_345 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281c, .hex);
pub const XK_braille_dots_1345 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281d, .hex);
pub const XK_braille_dots_2345 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281e, .hex);
pub const XK_braille_dots_12345 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100281f, .hex);
pub const XK_braille_dots_6 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002820, .hex);
pub const XK_braille_dots_16 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002821, .hex);
pub const XK_braille_dots_26 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002822, .hex);
pub const XK_braille_dots_126 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002823, .hex);
pub const XK_braille_dots_36 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002824, .hex);
pub const XK_braille_dots_136 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002825, .hex);
pub const XK_braille_dots_236 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002826, .hex);
pub const XK_braille_dots_1236 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002827, .hex);
pub const XK_braille_dots_46 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002828, .hex);
pub const XK_braille_dots_146 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002829, .hex);
pub const XK_braille_dots_246 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282a, .hex);
pub const XK_braille_dots_1246 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282b, .hex);
pub const XK_braille_dots_346 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282c, .hex);
pub const XK_braille_dots_1346 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282d, .hex);
pub const XK_braille_dots_2346 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282e, .hex);
pub const XK_braille_dots_12346 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100282f, .hex);
pub const XK_braille_dots_56 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002830, .hex);
pub const XK_braille_dots_156 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002831, .hex);
pub const XK_braille_dots_256 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002832, .hex);
pub const XK_braille_dots_1256 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002833, .hex);
pub const XK_braille_dots_356 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002834, .hex);
pub const XK_braille_dots_1356 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002835, .hex);
pub const XK_braille_dots_2356 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002836, .hex);
pub const XK_braille_dots_12356 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002837, .hex);
pub const XK_braille_dots_456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002838, .hex);
pub const XK_braille_dots_1456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002839, .hex);
pub const XK_braille_dots_2456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283a, .hex);
pub const XK_braille_dots_12456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283b, .hex);
pub const XK_braille_dots_3456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283c, .hex);
pub const XK_braille_dots_13456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283d, .hex);
pub const XK_braille_dots_23456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283e, .hex);
pub const XK_braille_dots_123456 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100283f, .hex);
pub const XK_braille_dots_7 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002840, .hex);
pub const XK_braille_dots_17 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002841, .hex);
pub const XK_braille_dots_27 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002842, .hex);
pub const XK_braille_dots_127 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002843, .hex);
pub const XK_braille_dots_37 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002844, .hex);
pub const XK_braille_dots_137 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002845, .hex);
pub const XK_braille_dots_237 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002846, .hex);
pub const XK_braille_dots_1237 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002847, .hex);
pub const XK_braille_dots_47 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002848, .hex);
pub const XK_braille_dots_147 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002849, .hex);
pub const XK_braille_dots_247 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284a, .hex);
pub const XK_braille_dots_1247 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284b, .hex);
pub const XK_braille_dots_347 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284c, .hex);
pub const XK_braille_dots_1347 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284d, .hex);
pub const XK_braille_dots_2347 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284e, .hex);
pub const XK_braille_dots_12347 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100284f, .hex);
pub const XK_braille_dots_57 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002850, .hex);
pub const XK_braille_dots_157 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002851, .hex);
pub const XK_braille_dots_257 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002852, .hex);
pub const XK_braille_dots_1257 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002853, .hex);
pub const XK_braille_dots_357 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002854, .hex);
pub const XK_braille_dots_1357 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002855, .hex);
pub const XK_braille_dots_2357 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002856, .hex);
pub const XK_braille_dots_12357 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002857, .hex);
pub const XK_braille_dots_457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002858, .hex);
pub const XK_braille_dots_1457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002859, .hex);
pub const XK_braille_dots_2457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285a, .hex);
pub const XK_braille_dots_12457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285b, .hex);
pub const XK_braille_dots_3457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285c, .hex);
pub const XK_braille_dots_13457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285d, .hex);
pub const XK_braille_dots_23457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285e, .hex);
pub const XK_braille_dots_123457 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100285f, .hex);
pub const XK_braille_dots_67 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002860, .hex);
pub const XK_braille_dots_167 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002861, .hex);
pub const XK_braille_dots_267 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002862, .hex);
pub const XK_braille_dots_1267 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002863, .hex);
pub const XK_braille_dots_367 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002864, .hex);
pub const XK_braille_dots_1367 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002865, .hex);
pub const XK_braille_dots_2367 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002866, .hex);
pub const XK_braille_dots_12367 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002867, .hex);
pub const XK_braille_dots_467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002868, .hex);
pub const XK_braille_dots_1467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002869, .hex);
pub const XK_braille_dots_2467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286a, .hex);
pub const XK_braille_dots_12467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286b, .hex);
pub const XK_braille_dots_3467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286c, .hex);
pub const XK_braille_dots_13467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286d, .hex);
pub const XK_braille_dots_23467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286e, .hex);
pub const XK_braille_dots_123467 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100286f, .hex);
pub const XK_braille_dots_567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002870, .hex);
pub const XK_braille_dots_1567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002871, .hex);
pub const XK_braille_dots_2567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002872, .hex);
pub const XK_braille_dots_12567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002873, .hex);
pub const XK_braille_dots_3567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002874, .hex);
pub const XK_braille_dots_13567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002875, .hex);
pub const XK_braille_dots_23567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002876, .hex);
pub const XK_braille_dots_123567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002877, .hex);
pub const XK_braille_dots_4567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002878, .hex);
pub const XK_braille_dots_14567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002879, .hex);
pub const XK_braille_dots_24567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287a, .hex);
pub const XK_braille_dots_124567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287b, .hex);
pub const XK_braille_dots_34567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287c, .hex);
pub const XK_braille_dots_134567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287d, .hex);
pub const XK_braille_dots_234567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287e, .hex);
pub const XK_braille_dots_1234567 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100287f, .hex);
pub const XK_braille_dots_8 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002880, .hex);
pub const XK_braille_dots_18 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002881, .hex);
pub const XK_braille_dots_28 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002882, .hex);
pub const XK_braille_dots_128 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002883, .hex);
pub const XK_braille_dots_38 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002884, .hex);
pub const XK_braille_dots_138 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002885, .hex);
pub const XK_braille_dots_238 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002886, .hex);
pub const XK_braille_dots_1238 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002887, .hex);
pub const XK_braille_dots_48 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002888, .hex);
pub const XK_braille_dots_148 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002889, .hex);
pub const XK_braille_dots_248 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288a, .hex);
pub const XK_braille_dots_1248 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288b, .hex);
pub const XK_braille_dots_348 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288c, .hex);
pub const XK_braille_dots_1348 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288d, .hex);
pub const XK_braille_dots_2348 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288e, .hex);
pub const XK_braille_dots_12348 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100288f, .hex);
pub const XK_braille_dots_58 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002890, .hex);
pub const XK_braille_dots_158 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002891, .hex);
pub const XK_braille_dots_258 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002892, .hex);
pub const XK_braille_dots_1258 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002893, .hex);
pub const XK_braille_dots_358 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002894, .hex);
pub const XK_braille_dots_1358 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002895, .hex);
pub const XK_braille_dots_2358 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002896, .hex);
pub const XK_braille_dots_12358 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002897, .hex);
pub const XK_braille_dots_458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002898, .hex);
pub const XK_braille_dots_1458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1002899, .hex);
pub const XK_braille_dots_2458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289a, .hex);
pub const XK_braille_dots_12458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289b, .hex);
pub const XK_braille_dots_3458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289c, .hex);
pub const XK_braille_dots_13458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289d, .hex);
pub const XK_braille_dots_23458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289e, .hex);
pub const XK_braille_dots_123458 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x100289f, .hex);
pub const XK_braille_dots_68 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a0, .hex);
pub const XK_braille_dots_168 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a1, .hex);
pub const XK_braille_dots_268 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a2, .hex);
pub const XK_braille_dots_1268 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a3, .hex);
pub const XK_braille_dots_368 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a4, .hex);
pub const XK_braille_dots_1368 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a5, .hex);
pub const XK_braille_dots_2368 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a6, .hex);
pub const XK_braille_dots_12368 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a7, .hex);
pub const XK_braille_dots_468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a8, .hex);
pub const XK_braille_dots_1468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028a9, .hex);
pub const XK_braille_dots_2468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028aa, .hex);
pub const XK_braille_dots_12468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ab, .hex);
pub const XK_braille_dots_3468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ac, .hex);
pub const XK_braille_dots_13468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ad, .hex);
pub const XK_braille_dots_23468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ae, .hex);
pub const XK_braille_dots_123468 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028af, .hex);
pub const XK_braille_dots_568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b0, .hex);
pub const XK_braille_dots_1568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b1, .hex);
pub const XK_braille_dots_2568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b2, .hex);
pub const XK_braille_dots_12568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b3, .hex);
pub const XK_braille_dots_3568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b4, .hex);
pub const XK_braille_dots_13568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b5, .hex);
pub const XK_braille_dots_23568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b6, .hex);
pub const XK_braille_dots_123568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b7, .hex);
pub const XK_braille_dots_4568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b8, .hex);
pub const XK_braille_dots_14568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028b9, .hex);
pub const XK_braille_dots_24568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ba, .hex);
pub const XK_braille_dots_124568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028bb, .hex);
pub const XK_braille_dots_34568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028bc, .hex);
pub const XK_braille_dots_134568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028bd, .hex);
pub const XK_braille_dots_234568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028be, .hex);
pub const XK_braille_dots_1234568 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028bf, .hex);
pub const XK_braille_dots_78 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c0, .hex);
pub const XK_braille_dots_178 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c1, .hex);
pub const XK_braille_dots_278 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c2, .hex);
pub const XK_braille_dots_1278 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c3, .hex);
pub const XK_braille_dots_378 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c4, .hex);
pub const XK_braille_dots_1378 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c5, .hex);
pub const XK_braille_dots_2378 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c6, .hex);
pub const XK_braille_dots_12378 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c7, .hex);
pub const XK_braille_dots_478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c8, .hex);
pub const XK_braille_dots_1478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028c9, .hex);
pub const XK_braille_dots_2478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ca, .hex);
pub const XK_braille_dots_12478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028cb, .hex);
pub const XK_braille_dots_3478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028cc, .hex);
pub const XK_braille_dots_13478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028cd, .hex);
pub const XK_braille_dots_23478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ce, .hex);
pub const XK_braille_dots_123478 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028cf, .hex);
pub const XK_braille_dots_578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d0, .hex);
pub const XK_braille_dots_1578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d1, .hex);
pub const XK_braille_dots_2578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d2, .hex);
pub const XK_braille_dots_12578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d3, .hex);
pub const XK_braille_dots_3578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d4, .hex);
pub const XK_braille_dots_13578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d5, .hex);
pub const XK_braille_dots_23578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d6, .hex);
pub const XK_braille_dots_123578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d7, .hex);
pub const XK_braille_dots_4578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d8, .hex);
pub const XK_braille_dots_14578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028d9, .hex);
pub const XK_braille_dots_24578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028da, .hex);
pub const XK_braille_dots_124578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028db, .hex);
pub const XK_braille_dots_34578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028dc, .hex);
pub const XK_braille_dots_134578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028dd, .hex);
pub const XK_braille_dots_234578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028de, .hex);
pub const XK_braille_dots_1234578 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028df, .hex);
pub const XK_braille_dots_678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e0, .hex);
pub const XK_braille_dots_1678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e1, .hex);
pub const XK_braille_dots_2678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e2, .hex);
pub const XK_braille_dots_12678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e3, .hex);
pub const XK_braille_dots_3678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e4, .hex);
pub const XK_braille_dots_13678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e5, .hex);
pub const XK_braille_dots_23678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e6, .hex);
pub const XK_braille_dots_123678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e7, .hex);
pub const XK_braille_dots_4678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e8, .hex);
pub const XK_braille_dots_14678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028e9, .hex);
pub const XK_braille_dots_24678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ea, .hex);
pub const XK_braille_dots_124678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028eb, .hex);
pub const XK_braille_dots_34678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ec, .hex);
pub const XK_braille_dots_134678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ed, .hex);
pub const XK_braille_dots_234678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ee, .hex);
pub const XK_braille_dots_1234678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ef, .hex);
pub const XK_braille_dots_5678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f0, .hex);
pub const XK_braille_dots_15678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f1, .hex);
pub const XK_braille_dots_25678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f2, .hex);
pub const XK_braille_dots_125678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f3, .hex);
pub const XK_braille_dots_35678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f4, .hex);
pub const XK_braille_dots_135678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f5, .hex);
pub const XK_braille_dots_235678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f6, .hex);
pub const XK_braille_dots_1235678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f7, .hex);
pub const XK_braille_dots_45678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f8, .hex);
pub const XK_braille_dots_145678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028f9, .hex);
pub const XK_braille_dots_245678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028fa, .hex);
pub const XK_braille_dots_1245678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028fb, .hex);
pub const XK_braille_dots_345678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028fc, .hex);
pub const XK_braille_dots_1345678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028fd, .hex);
pub const XK_braille_dots_2345678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028fe, .hex);
pub const XK_braille_dots_12345678 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x10028ff, .hex);
pub const XK_Sinh_ng = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d82, .hex);
pub const XK_Sinh_h2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d83, .hex);
pub const XK_Sinh_a = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d85, .hex);
pub const XK_Sinh_aa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d86, .hex);
pub const XK_Sinh_ae = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d87, .hex);
pub const XK_Sinh_aee = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d88, .hex);
pub const XK_Sinh_i = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d89, .hex);
pub const XK_Sinh_ii = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8a, .hex);
pub const XK_Sinh_u = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8b, .hex);
pub const XK_Sinh_uu = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8c, .hex);
pub const XK_Sinh_ri = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8d, .hex);
pub const XK_Sinh_rii = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8e, .hex);
pub const XK_Sinh_lu = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d8f, .hex);
pub const XK_Sinh_luu = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d90, .hex);
pub const XK_Sinh_e = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d91, .hex);
pub const XK_Sinh_ee = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d92, .hex);
pub const XK_Sinh_ai = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d93, .hex);
pub const XK_Sinh_o = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d94, .hex);
pub const XK_Sinh_oo = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d95, .hex);
pub const XK_Sinh_au = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d96, .hex);
pub const XK_Sinh_ka = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9a, .hex);
pub const XK_Sinh_kha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9b, .hex);
pub const XK_Sinh_ga = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9c, .hex);
pub const XK_Sinh_gha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9d, .hex);
pub const XK_Sinh_ng2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9e, .hex);
pub const XK_Sinh_nga = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000d9f, .hex);
pub const XK_Sinh_ca = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da0, .hex);
pub const XK_Sinh_cha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da1, .hex);
pub const XK_Sinh_ja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da2, .hex);
pub const XK_Sinh_jha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da3, .hex);
pub const XK_Sinh_nya = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da4, .hex);
pub const XK_Sinh_jnya = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da5, .hex);
pub const XK_Sinh_nja = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da6, .hex);
pub const XK_Sinh_tta = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da7, .hex);
pub const XK_Sinh_ttha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da8, .hex);
pub const XK_Sinh_dda = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000da9, .hex);
pub const XK_Sinh_ddha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000daa, .hex);
pub const XK_Sinh_nna = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dab, .hex);
pub const XK_Sinh_ndda = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dac, .hex);
pub const XK_Sinh_tha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dad, .hex);
pub const XK_Sinh_thha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dae, .hex);
pub const XK_Sinh_dha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000daf, .hex);
pub const XK_Sinh_dhha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db0, .hex);
pub const XK_Sinh_na = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db1, .hex);
pub const XK_Sinh_ndha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db3, .hex);
pub const XK_Sinh_pa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db4, .hex);
pub const XK_Sinh_pha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db5, .hex);
pub const XK_Sinh_ba = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db6, .hex);
pub const XK_Sinh_bha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db7, .hex);
pub const XK_Sinh_ma = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db8, .hex);
pub const XK_Sinh_mba = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000db9, .hex);
pub const XK_Sinh_ya = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dba, .hex);
pub const XK_Sinh_ra = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dbb, .hex);
pub const XK_Sinh_la = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dbd, .hex);
pub const XK_Sinh_va = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc0, .hex);
pub const XK_Sinh_sha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc1, .hex);
pub const XK_Sinh_ssha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc2, .hex);
pub const XK_Sinh_sa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc3, .hex);
pub const XK_Sinh_ha = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc4, .hex);
pub const XK_Sinh_lla = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc5, .hex);
pub const XK_Sinh_fa = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dc6, .hex);
pub const XK_Sinh_al = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dca, .hex);
pub const XK_Sinh_aa2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dcf, .hex);
pub const XK_Sinh_ae2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd0, .hex);
pub const XK_Sinh_aee2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd1, .hex);
pub const XK_Sinh_i2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd2, .hex);
pub const XK_Sinh_ii2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd3, .hex);
pub const XK_Sinh_u2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd4, .hex);
pub const XK_Sinh_uu2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd6, .hex);
pub const XK_Sinh_ru2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd8, .hex);
pub const XK_Sinh_e2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dd9, .hex);
pub const XK_Sinh_ee2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dda, .hex);
pub const XK_Sinh_ai2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000ddb, .hex);
pub const XK_Sinh_o2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000ddc, .hex);
pub const XK_Sinh_oo2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000ddd, .hex);
pub const XK_Sinh_au2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000dde, .hex);
pub const XK_Sinh_lu2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000ddf, .hex);
pub const XK_Sinh_ruu2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000df2, .hex);
pub const XK_Sinh_luu2 = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000df3, .hex);
pub const XK_Sinh_kunddaliya = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1000df4, .hex);
pub const NoValue = @as(c_int, 0x0000);
pub const XValue = @as(c_int, 0x0001);
pub const YValue = @as(c_int, 0x0002);
pub const WidthValue = @as(c_int, 0x0004);
pub const HeightValue = @as(c_int, 0x0008);
pub const AllValues = @as(c_int, 0x000F);
pub const XNegative = @as(c_int, 0x0010);
pub const YNegative = @as(c_int, 0x0020);
pub const USPosition = @as(c_long, 1) << @as(c_int, 0);
pub const USSize = @as(c_long, 1) << @as(c_int, 1);
pub const PPosition = @as(c_long, 1) << @as(c_int, 2);
pub const PSize = @as(c_long, 1) << @as(c_int, 3);
pub const PMinSize = @as(c_long, 1) << @as(c_int, 4);
pub const PMaxSize = @as(c_long, 1) << @as(c_int, 5);
pub const PResizeInc = @as(c_long, 1) << @as(c_int, 6);
pub const PAspect = @as(c_long, 1) << @as(c_int, 7);
pub const PBaseSize = @as(c_long, 1) << @as(c_int, 8);
pub const PWinGravity = @as(c_long, 1) << @as(c_int, 9);
pub const PAllHints = ((((PPosition | PSize) | PMinSize) | PMaxSize) | PResizeInc) | PAspect;
pub const InputHint = @as(c_long, 1) << @as(c_int, 0);
pub const StateHint = @as(c_long, 1) << @as(c_int, 1);
pub const IconPixmapHint = @as(c_long, 1) << @as(c_int, 2);
pub const IconWindowHint = @as(c_long, 1) << @as(c_int, 3);
pub const IconPositionHint = @as(c_long, 1) << @as(c_int, 4);
pub const IconMaskHint = @as(c_long, 1) << @as(c_int, 5);
pub const WindowGroupHint = @as(c_long, 1) << @as(c_int, 6);
pub const AllHints = (((((InputHint | StateHint) | IconPixmapHint) | IconWindowHint) | IconPositionHint) | IconMaskHint) | WindowGroupHint;
pub const XUrgencyHint = @as(c_long, 1) << @as(c_int, 8);
pub const WithdrawnState = @as(c_int, 0);
pub const NormalState = @as(c_int, 1);
pub const IconicState = @as(c_int, 3);
pub const DontCareState = @as(c_int, 0);
pub const ZoomState = @as(c_int, 2);
pub const InactiveState = @as(c_int, 4);
pub const XNoMemory = -@as(c_int, 1);
pub const XLocaleNotSupported = -@as(c_int, 2);
pub const XConverterNotFound = -@as(c_int, 3);
pub inline fn XDestroyImage(ximage: anytype) @TypeOf(ximage.*.f.destroy_image.*(ximage)) {
    _ = &ximage;
    return ximage.*.f.destroy_image.*(ximage);
}
pub inline fn XGetPixel(ximage: anytype, x: anytype, y: anytype) @TypeOf(ximage.*.f.get_pixel.*(ximage, x, y)) {
    _ = &ximage;
    _ = &x;
    _ = &y;
    return ximage.*.f.get_pixel.*(ximage, x, y);
}
pub inline fn XPutPixel(ximage: anytype, x: anytype, y: anytype, pixel: anytype) @TypeOf(ximage.*.f.put_pixel.*(ximage, x, y, pixel)) {
    _ = &ximage;
    _ = &x;
    _ = &y;
    _ = &pixel;
    return ximage.*.f.put_pixel.*(ximage, x, y, pixel);
}
pub inline fn XSubImage(ximage: anytype, x: anytype, y: anytype, width: anytype, height: anytype) @TypeOf(ximage.*.f.sub_image.*(ximage, x, y, width, height)) {
    _ = &ximage;
    _ = &x;
    _ = &y;
    _ = &width;
    _ = &height;
    return ximage.*.f.sub_image.*(ximage, x, y, width, height);
}
pub inline fn XAddPixel(ximage: anytype, value: anytype) @TypeOf(ximage.*.f.add_pixel.*(ximage, value)) {
    _ = &ximage;
    _ = &value;
    return ximage.*.f.add_pixel.*(ximage, value);
}
pub inline fn IsKeypadKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_KP_Space) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_KP_Equal)) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_KP_Space) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_KP_Equal);
}
pub inline fn IsPrivateKeypadKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x11000000, .hex)) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1100FFFF, .hex))) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x11000000, .hex)) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x1100FFFF, .hex));
}
pub inline fn IsCursorKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Home) and (@import("std").zig.c_translation.cast(KeySym, keysym) < XK_Select)) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Home) and (@import("std").zig.c_translation.cast(KeySym, keysym) < XK_Select);
}
pub inline fn IsPFKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_KP_F1) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_KP_F4)) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_KP_F1) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_KP_F4);
}
pub inline fn IsFunctionKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_F1) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_F35)) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_F1) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_F35);
}
pub inline fn IsMiscFunctionKey(keysym: anytype) @TypeOf((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Select) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_Break)) {
    _ = &keysym;
    return (@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Select) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_Break);
}
pub inline fn IsModifierKey(keysym: anytype) @TypeOf(((((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Shift_L) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_Hyper_R)) or ((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_ISO_Lock) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_ISO_Level5_Lock))) or (@import("std").zig.c_translation.cast(KeySym, keysym) == XK_Mode_switch)) or (@import("std").zig.c_translation.cast(KeySym, keysym) == XK_Num_Lock)) {
    _ = &keysym;
    return ((((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_Shift_L) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_Hyper_R)) or ((@import("std").zig.c_translation.cast(KeySym, keysym) >= XK_ISO_Lock) and (@import("std").zig.c_translation.cast(KeySym, keysym) <= XK_ISO_Level5_Lock))) or (@import("std").zig.c_translation.cast(KeySym, keysym) == XK_Mode_switch)) or (@import("std").zig.c_translation.cast(KeySym, keysym) == XK_Num_Lock);
}
pub const RectangleOut = @as(c_int, 0);
pub const RectangleIn = @as(c_int, 1);
pub const RectanglePart = @as(c_int, 2);
pub const VisualNoMask = @as(c_int, 0x0);
pub const VisualIDMask = @as(c_int, 0x1);
pub const VisualScreenMask = @as(c_int, 0x2);
pub const VisualDepthMask = @as(c_int, 0x4);
pub const VisualClassMask = @as(c_int, 0x8);
pub const VisualRedMaskMask = @as(c_int, 0x10);
pub const VisualGreenMaskMask = @as(c_int, 0x20);
pub const VisualBlueMaskMask = @as(c_int, 0x40);
pub const VisualColormapSizeMask = @as(c_int, 0x80);
pub const VisualBitsPerRGBMask = @as(c_int, 0x100);
pub const VisualAllMask = @as(c_int, 0x1FF);
pub const ReleaseByFreeingColormap = @import("std").zig.c_translation.cast(XID, @as(c_long, 1));
pub const BitmapSuccess = @as(c_int, 0);
pub const BitmapOpenFailed = @as(c_int, 1);
pub const BitmapFileInvalid = @as(c_int, 2);
pub const BitmapNoMemory = @as(c_int, 3);
pub const XCSUCCESS = @as(c_int, 0);
pub const XCNOMEM = @as(c_int, 1);
pub const XCNOENT = @as(c_int, 2);
pub const XUniqueContext = @compileError("unable to translate macro: undefined identifier `XrmUniqueQuark`");
// /usr/include/X11/Xutil.h:359:9
pub const XStringToContext = @compileError("unable to translate macro: undefined identifier `XrmStringToQuark`");
// /usr/include/X11/Xutil.h:360:9
pub const timeval = struct_timeval;
pub const timespec = struct_timespec;
pub const __pthread_internal_list = struct___pthread_internal_list;
pub const __pthread_internal_slist = struct___pthread_internal_slist;
pub const __pthread_mutex_s = struct___pthread_mutex_s;
pub const __pthread_rwlock_arch_t = struct___pthread_rwlock_arch_t;
pub const __pthread_cond_s = struct___pthread_cond_s;
pub const _XExtData = struct__XExtData;
pub const _XGC = struct__XGC;
pub const _XDisplay = struct__XDisplay;
pub const _XImage = struct__XImage;
pub const _XPrivate = struct__XPrivate;
pub const _XrmHashBucketRec = struct__XrmHashBucketRec;
pub const _XEvent = union__XEvent;
pub const _XOM = struct__XOM;
pub const _XOC = struct__XOC;
pub const _XIM = struct__XIM;
pub const _XIC = struct__XIC;
pub const _XIMText = struct__XIMText;
pub const _XIMPreeditStateNotifyCallbackStruct = struct__XIMPreeditStateNotifyCallbackStruct;
pub const _XIMStringConversionText = struct__XIMStringConversionText;
pub const _XIMStringConversionCallbackStruct = struct__XIMStringConversionCallbackStruct;
pub const _XIMPreeditDrawCallbackStruct = struct__XIMPreeditDrawCallbackStruct;
pub const _XIMPreeditCaretCallbackStruct = struct__XIMPreeditCaretCallbackStruct;
pub const _XIMStatusDrawCallbackStruct = struct__XIMStatusDrawCallbackStruct;
pub const _XIMHotKeyTrigger = struct__XIMHotKeyTrigger;
pub const _XIMHotKeyTriggers = struct__XIMHotKeyTriggers;
pub const _XComposeStatus = struct__XComposeStatus;
pub const _XRegion = struct__XRegion;
