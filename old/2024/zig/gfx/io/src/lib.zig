pub const cpu = @import("linux/cpu.zig");
pub const ctx = @import("linux/ctx.zig");
pub const file = @import("linux/file.zig");
pub const io = @import("linux/io.zig");
pub const iou = @import("linux/io_uring.zig");
pub const socket = @import("linux/socket.zig");

pub const cpuBufferCreate = cpu.create;
pub const cpuBufferWrap = cpu.wrap;
pub const cpuBufferRelease = cpu.release;

pub const ctxCurrent = ctx.current;
pub const ctxInit = ctx.init;
pub const ctxShutdown = ctx.shutdown;
pub const ctxSubmit = ctx.submit;
pub const ctxPoll = ctx.poll;
pub const ctxLastError = ctx.lastError;

pub const File = file.File;
pub const fileCreate = file.create;
pub const fileOpen = file.open;
pub const fileRead = file.read;
pub const fileWrite = file.write;
pub const fileSeek = file.seek;
pub const fileFlush = file.flush;
pub const fileClose = file.close;
pub const fileRelease = file.release;
pub const fileSize = file.size;

pub const Socket = socket.Socket;
pub const IpAddress = socket.IpAddress;
pub const Option = socket.Option;

pub const socketCreate = socket.create;
pub const socketBind = socket.bind;
pub const socketListen = socket.listen;
pub const socketAccept = socket.accept;
pub const socketConnect = socket.connect;
pub const socketRecv = socket.recv;
pub const socketSend = socket.send;
pub const socketClose = socket.close;
pub const socketRelease = socket.release;
pub const socketSetOption = socket.setOption;
