const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Method = enum {
    GET,
    HEAD,
    POST,
    PUT,
    DELETE,
    CONNECT,
    OPTIONS,
    TRACE,
    PATCH,
};

pub const StatusCode = enum(u16) {
    // 1xx Informational
    Continue = 100,
    SwitchingProtocols = 101,
    Processing = 102,
    EarlyHints = 103,

    // 2xx Success
    Ok = 200,
    Created = 201,
    Accepted = 202,
    NonAuthoritativeInformation = 203,
    NoContent = 204,
    ResetContent = 205,
    PartialContent = 206,
    MultiStatus = 207,
    AlreadyReported = 208,
    IMUsed = 226,

    // 3xx Redirection
    MultipleChoices = 300,
    MovedPermanently = 301,
    Found = 302,
    SeeOther = 303,
    NotModified = 304,
    UseProxy = 305,
    TemporaryRedirect = 307,
    PermanentRedirect = 308,

    // 4xx Client Error
    BadRequest = 400,
    Unauthorized = 401,
    PaymentRequired = 402,
    Forbidden = 403,
    NotFound = 404,
    MethodNotAllowed = 405,
    NotAcceptable = 406,
    ProxyAuthenticationRequired = 407,
    RequestTimeout = 408,
    Conflict = 409,
    Gone = 410,
    LengthRequired = 411,
    PreconditionFailed = 412,
    PayloadTooLarge = 413,
    UriTooLong = 414,
    UnsupportedMediaType = 415,
    RangeNotSatisfiable = 416,
    ExpectationFailed = 417,
    MisdirectedRequest = 421,
    UnprocessableEntity = 422,
    Locked = 423,
    FailedDependency = 424,
    TooEarly = 425,
    UpgradeRequired = 426,
    PreconditionRequired = 428,
    TooManyRequests = 429,
    RequestHeaderFieldsTooLarge = 431,
    UnavailableForLegalReasons = 451,

    // 5xx Server Error
    InternalServerError = 500,
    NotImplemented = 501,
    BadGateway = 502,
    ServiceUnavailable = 503,
    GatewayTimeout = 504,
    HttpVersionNotSupported = 505,
    VariantAlsoNegotiates = 506,
    InsufficientStorage = 507,
    LoopDetected = 508,
    NotExtended = 510,
    NetworkAuthenticationRequired = 511,
};

pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

pub const Headers = struct {
    allocator: Allocator,
    headers_list: std.ArrayList(Header),

    pub fn init(allocator: Allocator) Headers {
        return .{
            .allocator = allocator,
            .headers_list = std.ArrayList(Header).init(allocator),
        };
    }

    pub fn deinit(self: *Headers) void {
        self.headers_list.deinit();
    }

    pub fn add(self: *Headers, name: []const u8, value: []const u8) !void {
        try self.headers_list.append(.{ .name = name, .value = value });
    }

    pub fn get(self: *const Headers, name: []const u8) ?[]const u8 {
        for (self.headers_list.items) |header| {
            if (std.mem.eql(u8, header.name, name)) {
                return header.value;
            }
        }
        return null;
    }

    // TODO: Add more methods like remove, get_all, etc.
};

pub const BodyPayload = union(enum) {
    empty: void,
    slice: []const u8,
    reader: std.io.AnyReader,
    writer: std.io.AnyWriter,
};

pub const Protocol = enum {
    http1_1,
    http2,
    http3,
};

pub const Request = struct {
    method: Method,
    path: []const u8,
    protocol: Protocol,
    headers: Headers,
    body: BodyPayload,
};

pub const Response = struct {
    status_code: StatusCode,
    protocol: Protocol,
    headers: Headers,
    body: BodyPayload,
};

// This is a placeholder for the protocol-agnostic interface.
// We will define how different HTTP versions (H1, H2, H3) can implement this.
// This could be a struct with function pointers or a more complex setup
// depending on the desired level of abstraction and performance trade-offs.
pub const HttpProtocol = struct {
    // Opaque context for the specific implementation (e.g., HTTP/1.1 connection, HTTP/2 stream)
    context: *anyopaque,

    // Function to send a request and receive a response.
    // The implementation will handle the specifics of the protocol.
    send_receive: *const fn (
        protocol_context: *anyopaque,
        allocator: Allocator,
        request: Request,
    ) anyerror!Response,

    // Function to close the connection or release resources.
    close: *const fn (protocol_context: *anyopaque) void,

    // Other common operations can be added here, e.g.:
    // - connect: *const fn (...) anyerror!*anyopaque,
    // - specific functions for streaming, server push (for H2/H3), etc.

    pub fn init(
        impl_context: *anyopaque,
        impl_send_receive: *const fn (*anyopaque, Allocator, Request) anyerror!Response,
        impl_close: *const fn (*anyopaque) void,
    ) HttpProtocol {
        return .{
            .context = impl_context,
            .send_receive = impl_send_receive,
            .close = impl_close,
        };
    }

    pub fn deinit(self: *HttpProtocol) void {
        self.close(self.context);
    }

    pub fn sendRequest(
        self: *const HttpProtocol,
        allocator: Allocator,
        request: Request,
    ) anyerror!Response {
        return self.send_receive(self.context, allocator, request);
    }
};

// Example of how an HTTP/1.1 implementation might use this.
// This would live in a separate file, e.g., src/http/h1.zig

// pub const H1Client = struct {
//     // ... H1 specific fields, e.g., a TCP connection
//     connection: std.net.Stream,
//     allocator: Allocator,

//     pub fn init(allocator: Allocator, stream: std.net.Stream) H1Client {
//         return .{ .allocator = allocator, .connection = stream };
//     }

//     pub fn deinit(self: *H1Client) void {
//         self.connection.close();
//     }

//     fn h1_send_receive(
//         protocol_context: *anyopaque,
//         allocator: Allocator,
//         request: Request,
//     ) anyerror!Response {
//         const self: *H1Client = @ptrCast(@alignCast(protocol_context));
//         // ... actual HTTP/1.1 implementation ...
//         // 1. Serialize request to HTTP/1.1 format
//         // 2. Send over self.connection
//         // 3. Receive response from self.connection
//         // 4. Parse HTTP/1.1 response into Response struct
//         _ = self;
//         _ = allocator;
//         _ = request;
//         return error.NotImplemented; // Placeholder
//     }

//     fn h1_close(protocol_context: *anyopaque) void {
//         const self: *H1Client = @ptrCast(@alignCast(protocol_context));
//         self.deinit();
//     }

//     pub fn getProtocol(self: *H1Client) HttpProtocol {
//         return HttpProtocol.init(
//             self,
//             h1_send_receive,
//             h1_close,
//         );
//     }
// };

// TODO:
// - Refine Headers: Consider a hash map for faster lookups if header count is large.
//   For now, ArrayList is simple and "concise".
// - Body Handling: `?[]const u8` is simple for small bodies. For larger bodies or streaming,
//   we'll need `std.io.Reader` and `std.io.Writer` interfaces.
// - Error Handling: Use specific error sets for more granular error reporting.
// - Client vs Server: This interface is more client-oriented with send_receive.
//   A server would need a `handle_request: *const fn (...) anyerror!void` or similar.
// - Protocol Version: Decide how to handle/store protocol version string ("HTTP/1.1")
//   in Request/Response if needed for logic outside the specific protocol implementation.
//   Currently commented out.
