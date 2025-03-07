pub mod cpu;
pub mod ctx;
pub mod err;
pub mod file;
pub mod io;
pub mod socket;

// Re-exports for API compatibility
pub use cpu::Buffer as CpuBuffer;
pub use cpu::create as cpu_buffer_create;
pub use cpu::wrap as cpu_buffer_wrap;
pub use cpu::release as cpu_buffer_release;

pub use ctx::current as ctx_current;
pub use ctx::init as ctx_init;
pub use ctx::shutdown as ctx_shutdown;
pub use ctx::submit as ctx_submit;
pub use ctx::poll as ctx_poll;
pub use ctx::last_error as ctx_last_error;

pub use file::File as File;
pub use file::create as file_create;
pub use file::open as file_open;
pub use file::read as file_read;
pub use file::write as file_write;
pub use file::seek as file_seek;
pub use file::flush as file_flush;
pub use file::close as file_close;
pub use file::release as file_release;
pub use file::size as file_size;

pub use io::OperationType as IoOperationType;
pub use io::Operation as IoOperation;
pub use io::Complete as IoComplete;
pub use io::SeekOrigin as IoSeekOrigin;
pub use io::ModeFlags as IoModeFlags;
pub use io::SockType as IoSockType;
pub use io::HandleType as IoHandleType;
pub use io::handle_type as io_handle_type;
pub use io::last_operation_id as io_last_operation_id;

pub use socket::Socket as Socket;
pub use socket::IpAddress as IpAddress;
pub use socket::Option as SocketOption;
pub use socket::create as socket_create;
pub use socket::bind as socket_bind;
pub use socket::listen as socket_listen;
pub use socket::accept as socket_accept;
pub use socket::connect as socket_connect;
pub use socket::recv as socket_recv;
pub use socket::send as socket_send;
pub use socket::close as socket_close;
pub use socket::release as socket_release;
pub use socket::set_option as socket_set_option;