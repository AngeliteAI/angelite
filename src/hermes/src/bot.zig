const std = @import("std");
const json = std.json;
const net = std.net;
const mem = std.mem;
const Thread = std.Thread;
const Mutex = std.Thread.Mutex;
const AutoHashMap = std.AutoHashMap;
const crypto = std.crypto;
const base64 = std.base64;
const time = std.time;
// Import Hmac explicitly as it's organized differently in Zig 0.14.0
const Hmac = std.crypto.auth.hmac.sha2.HmacSha256;

const Ticker = struct {
    ticker: []const u8,
};

const Pair = struct {
    base: []const u8,
    quote: []const u8,
};

const Price = struct {
    price: f64,
    size: f64,
    time: std.time.Instant,
};

const OrderBookEntry = struct {
    price: f64,
    size: f64,
};

const OrderBook = struct {
    asks: []OrderBookEntry,
    bids: []OrderBookEntry,
    mutex: Mutex = .{},
    limited_data: bool = false, // Flag indicating we only have ticker data, not full depth
    last_update_time: i64 = 0, // Track last update time for rate limiting

    pub fn init(allocator: std.mem.Allocator) !OrderBook {
        return OrderBook{
            .asks = try allocator.alloc(OrderBookEntry, 0),
            .bids = try allocator.alloc(OrderBookEntry, 0),
            .limited_data = false,
            .last_update_time = std.time.milliTimestamp(),
        };
    }

    pub fn deinit(self: *OrderBook, allocator: std.mem.Allocator) void {
        allocator.free(self.asks);
        allocator.free(self.bids);
    }

    pub fn update(self: *OrderBook, allocator: std.mem.Allocator, updates: []const Level2Update) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const now = std.time.milliTimestamp();
        const time_since_last_update = now - self.last_update_time;

        // Rate limit: minimum 50ms between updates
        if (time_since_last_update < 50) {
            std.time.sleep(@intCast((50 - time_since_last_update) * std.time.ns_per_ms));
        }

        // Limit batch size to 100 updates at a time
        const max_updates = @min(updates.len, 100);
        std.debug.print("Processing {d} order book updates (rate limited from {d})\n", .{ max_updates, updates.len });

        // Process each update to modify the order book
        for (updates[0..max_updates]) |level2_update| {
            const is_bid = mem.eql(u8, level2_update.side, "buy");
            const price_level = try std.fmt.parseFloat(f64, level2_update.price_level);
            const new_quantity = try std.fmt.parseFloat(f64, level2_update.new_quantity);

            std.debug.print("Update: {s} {d:.8} @ {d:.8}\n", .{ level2_update.side, new_quantity, price_level });

            if (is_bid) {
                try updatePriceLevel(allocator, &self.bids, price_level, new_quantity);
            } else {
                try updatePriceLevel(allocator, &self.asks, price_level, new_quantity);
            }
        }

        // Sort asks ascending, bids descending
        sortOrderBook(self.asks, true);
        sortOrderBook(self.bids, false);

        self.last_update_time = std.time.milliTimestamp();

        std.debug.print("Order book after update - Bids: {d}, Asks: {d}\n", .{ self.bids.len, self.asks.len });
        if (self.bids.len > 0) {
            std.debug.print("Best bid: {d:.8} @ {d:.8}\n", .{ self.bids[0].price, self.bids[0].size });
        }
        if (self.asks.len > 0) {
            std.debug.print("Best ask: {d:.8} @ {d:.8}\n", .{ self.asks[0].price, self.asks[0].size });
        }
    }
};

// Helper function to update a price level in an order book
fn updatePriceLevel(allocator: std.mem.Allocator, book: *[]OrderBookEntry, price: f64, quantity: f64) !void {
    // Check if the price level already exists
    for (book.*) |*entry| {
        if (std.math.approxEqAbs(f64, entry.price, price, 0.000001)) {
            if (quantity == 0) {
                // Remove this price level
                entry.size = 0;
            } else {
                // Update quantity
                entry.size = quantity;
            }

            // Clean up zero entries
            var non_zero_count: usize = 0;
            for (book.*) |e| {
                if (e.size > 0) non_zero_count += 1;
            }

            if (non_zero_count == 0) {
                // If all entries are zero, just free the array
                allocator.free(book.*);
                book.* = try allocator.alloc(OrderBookEntry, 0);
                return;
            }

            var new_side = try allocator.alloc(OrderBookEntry, non_zero_count);
            var idx: usize = 0;

            for (book.*) |e| {
                if (e.size > 0) {
                    new_side[idx] = e;
                    idx += 1;
                }
            }

            allocator.free(book.*);
            book.* = new_side;
            return;
        }
    }

    // Price level not found and size > 0, add a new entry
    if (quantity > 0) {
        const new_side = try allocator.alloc(OrderBookEntry, book.len + 1);
        if (book.len > 0) {
            @memcpy(new_side[0..book.len], book.*);
        }
        new_side[book.len] = .{ .price = price, .size = quantity };

        if (book.len > 0) {
            allocator.free(book.*);
        }
        book.* = new_side;
    }
}

// Helper function to count non-zero entries
fn countNonZeroEntries(book: []const OrderBookEntry) usize {
    var count: usize = 0;
    for (book) |entry| {
        if (entry.size > 0) {
            count += 1;
        }
    }
    return count;
}

// Sort order book entries
fn sortOrderBook(book: []OrderBookEntry, ascending: bool) void {
    const SortContext = struct {
        ascending: bool,

        pub fn lessThan(ctx: @This(), a: OrderBookEntry, b: OrderBookEntry) bool {
            if (ctx.ascending) {
                return a.price < b.price;
            } else {
                return a.price > b.price;
            }
        }
    };

    std.sort.heap(OrderBookEntry, book, SortContext{ .ascending = ascending }, SortContext.lessThan);
}

const Status = struct {
    price: f64,
    order_book: *OrderBook,
    best_bid: f64,
    best_bid_size: f64,
    best_ask: f64,
    best_ask_size: f64,
    last_update_time: []const u8,
    mutex: Mutex = .{},

    fn updatePrice(self: *Status, price: f64) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.price = price;
    }

    fn updateBestBidAsk(self: *Status, best_bid: f64, best_bid_size: f64, best_ask: f64, best_ask_size: f64, update_time: []const u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.best_bid = best_bid;
        self.best_bid_size = best_bid_size;
        self.best_ask = best_ask;
        self.best_ask_size = best_ask_size;
        self.last_update_time = update_time;
    }
};

// Level2Update represents a single price level update from the level2 channel
const Level2Update = struct {
    side: []const u8,
    event_time: []const u8,
    price_level: []const u8,
    new_quantity: []const u8,
};

// Add a new struct for batched level2 updates
const Level2BatchEvent = struct {
    product_id: []const u8,
    updates: []Level2Update,
};

// WebSocketEvent represents the events in a WebSocket message
const WebSocketEvent = struct {
    type: []const u8,
    product_id: ?[]const u8 = null, // For single product messages like ticker
    updates: ?[]Level2Update = null, // For legacy l2update (single product)
    tickers: ?[]WebSocketTicker = null,
    // Add field for batched level2 updates
    events: ?[]Level2BatchEvent = null, // For level2_batch (can contain multiple products)
};

// WebSocketTicker represents ticker data
const WebSocketTicker = struct {
    type: []const u8,
    product_id: []const u8,
    price: []const u8,
    best_bid: []const u8,
    best_bid_size: []const u8,
    best_ask: []const u8,
    best_ask_size: []const u8,
    time: []const u8,
    side: ?[]const u8 = null,
    open_24h: ?[]const u8 = null,
    volume_24h: ?[]const u8 = null,
    low_24h: ?[]const u8 = null,
    high_24h: ?[]const u8 = null,
    volume_30d: ?[]const u8 = null,
    trade_id: ?u64 = null,
    last_size: ?[]const u8 = null,
};

// WebSocketMessage represents the structure of Coinbase WebSocket messages
const WebSocketMessage = struct {
    channel: []const u8,
    client_id: []const u8,
    timestamp: []const u8,
    sequence_num: u64,
    events: []WebSocketEvent,
};

// CoinbaseMessage represents the general structure of different Coinbase message types
const CoinbaseMessage = struct {
    type: []const u8, // e.g., "ticker", "snapshot", "l2update", "level2_batch", "open", "done", etc.
    product_id: ?[]const u8 = null,
    time: ?[]const u8 = null,
    sequence: ?u64 = null,

    // Ticker specific fields
    price: ?[]const u8 = null,
    best_bid: ?[]const u8 = null,
    best_ask: ?[]const u8 = null,
    best_bid_size: ?[]const u8 = null,
    best_ask_size: ?[]const u8 = null,

    // Order book specific fields (used in both snapshot and non-batch l2update)
    bids: ?[][]const []const u8 = null,
    asks: ?[][]const []const u8 = null,
    changes: ?[][]const []const u8 = null,

    // Fields for individual order lifecycle events (open, done, match, change)
    // These might appear at the top level if not part of a batch
    order_id: ?[]const u8 = null,
    order_type: ?[]const u8 = null, // e.g. "limit", "market"
    side: ?[]const u8 = null, // "buy" or "sell"
    size: ?[]const u8 = null, // Original size of the order
    remaining_size: ?[]const u8 = null, // Remaining size for open/change messages
    reason: ?[]const u8 = null, // For "done" messages
    trade_id: ?u64 = null, // For "match" messages
    maker_order_id: ?[]const u8 = null, // For "match" messages
    taker_order_id: ?[]const u8 = null, // For "match" messages

    // Field for level2_batch messages
    events: ?[]Level2BatchEvent = null,

    // Subscription response fields
    channels: ?json.Value = null,

    // Error fields
    message: ?[]const u8 = null, // This is for error messages from Coinbase, not signature message
};

// WebSocketRequest represents a subscription request to Coinbase WebSocket
const WebSocketRequest = struct {
    type: []const u8,
    product_ids: []const []const u8,
    channels: ?[]const Channel = null,
    // Authentication fields
    signature: ?[]const u8 = null,
    key: ?[]const u8 = null,
    passphrase: []const u8, // Always required, but can be empty string
    timestamp: ?[]const u8 = null,
};

const Channel = struct {
    name: []const u8,
    product_ids: ?[]const []const u8 = null,
};

const CoinbaseResponse = struct {
    data: struct {
        amount: []const u8,
        currency: []const u8,
    },
};

const SubscriptionStatus = enum {
    NotSubscribed,
    Pending,
    Subscribed,
};

// Define a custom hasher for pair keys
pub fn PairHasher(p: Pair) u64 {
    var h = std.hash.Wyhash.init(0);
    _ = h.update(p.base);
    _ = h.update("-");
    _ = h.update(p.quote);
    return h.final();
}

const PairMap = struct {
    // Store actual pairs and their corresponding hash keys
    pairs: std.ArrayList(Pair),
    keys: std.ArrayList(u64),

    fn init(allocator: std.mem.Allocator) PairMap {
        return .{
            .pairs = std.ArrayList(Pair).init(allocator),
            .keys = std.ArrayList(u64).init(allocator),
        };
    }

    fn deinit(self: *PairMap) void {
        self.pairs.deinit();
        self.keys.deinit();
    }

    fn put(self: *PairMap, pair: Pair) !u64 {
        const key = PairHasher(pair);
        const items = self.keys.items;
        var i: usize = 0;
        while (i < items.len) : (i += 1) {
            if (items[i] == key) {
                return key;
            }
        }
        try self.pairs.append(pair);
        try self.keys.append(key);
        return key;
    }

    fn get(self: *PairMap, key: u64) ?Pair {
        for (self.keys.items, 0..) |existing_key, i| {
            if (existing_key == key) {
                return self.pairs.items[i];
            }
        }
        return null;
    }

    // Corrected function to get the u64 key from a product_id string
    fn getPairKeyByProductId(self: *PairMap, allocator: std.mem.Allocator, product_id_str: []const u8) !u64 {
        for (self.pairs.items, 0..) |pair_item, i| {
            const pair_item_str = std.fmt.allocPrint(allocator, "{s}-{s}", .{ pair_item.base, pair_item.quote }) catch |err| {
                std.debug.print("Failed to allocate for pair string comparison in getPairKeyByProductId: {any}\n", .{err});
                return error.PairNotFound;
            };
            defer allocator.free(pair_item_str);

            if (mem.eql(u8, pair_item_str, product_id_str)) {
                return self.keys.items[i];
            }
        }
        return error.PairNotFound;
    }

    fn getPairByKey(self: *PairMap, key: u64) ?Pair {
        return self.get(key);
    }
};

// Add Coinbase API credentials struct
const CoinbaseCredentials = struct {
    api_key: []const u8,
    secret_key: []const u8,
    passphrase: []const u8,
};

pub const Coinbase = struct {
    allocator: std.mem.Allocator,
    credentials: CoinbaseCredentials,
    ws_thread: ?Thread = null,
    stop_ws_thread: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    status_map: AutoHashMap(u64, *Status),
    orderbooks_map: AutoHashMap(u64, *OrderBook),
    subscription_status: AutoHashMap(u64, SubscriptionStatus),
    pair_map: PairMap,
    mutex: Mutex = .{},
    message_buffer: std.ArrayList(u8),
    client: ?std.crypto.tls.Client = null,
    stream: ?std.net.Stream = null,
    last_ping_time: i64,
    order_book: OrderBook,

    fn init(allocator: std.mem.Allocator, credentials: CoinbaseCredentials) !*Coinbase {
        const coinbase = try allocator.create(Coinbase);
        coinbase.* = .{
            .allocator = allocator,
            .credentials = credentials,
            .status_map = AutoHashMap(u64, *Status).init(allocator),
            .orderbooks_map = AutoHashMap(u64, *OrderBook).init(allocator),
            .subscription_status = AutoHashMap(u64, SubscriptionStatus).init(allocator),
            .pair_map = PairMap.init(allocator),
            .message_buffer = std.ArrayList(u8).init(allocator),
            .client = null,
            .stream = null,
            .last_ping_time = 0,
            .order_book = try OrderBook.init(allocator),
        };
        return coinbase;
    }

    fn deinit(self: *Coinbase) void {
        self.stop_ws_thread.store(true, .seq_cst);
        if (self.ws_thread) |thread| {
            thread.join();
        }

        var it = self.orderbooks_map.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit(self.allocator);
            self.allocator.destroy(entry.value_ptr.*);
        }

        var status_it = self.status_map.iterator();
        while (status_it.next()) |entry| {
            self.allocator.destroy(entry.value_ptr.*);
        }

        self.pair_map.deinit();
        self.status_map.deinit();
        self.orderbooks_map.deinit();
        self.subscription_status.deinit();
        self.message_buffer.deinit();
        self.allocator.destroy(self);
    }

    fn get_buy_price(self: @This(), pair: Pair) !Price {
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();

        // Allocate a buffer for server headers
        var buf: [4096]u8 = undefined;

        const url_str = try std.fmt.allocPrint(self.allocator, "https://api.coinbase.com/v2/prices/{s}-{s}/buy", .{ pair.base, pair.quote });
        defer self.allocator.free(url_str);

        const url = try std.Uri.parse(url_str);

        // Start the HTTP request
        var req = try client.open(.GET, url, .{ .server_header_buffer = &buf });
        defer req.deinit();

        // Add authorization header
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.credentials.api_key});
        defer self.allocator.free(auth_header);

        req.headers.authorization = .{ .override = auth_header };

        // Send the HTTP request headers
        try req.send();
        // Finish the body of a request
        try req.finish();

        // Waits for a response from the server and parses any headers that are sent
        try req.wait();

        // Read the response body
        var response_body = std.ArrayList(u8).init(self.allocator);
        defer response_body.deinit();

        try req.reader().readAllArrayList(&response_body, 1024 * 1024);

        // Parse the JSON response
        const response = try json.parseFromSlice(CoinbaseResponse, self.allocator, response_body.items, .{ .ignore_unknown_fields = true });
        defer response.deinit();

        // Convert the amount string to a float
        const price = try std.fmt.parseFloat(f64, response.value.data.amount);

        return Price{
            .price = price,
            .size = 0, // Size is not provided in the response
            .time = std.time.Instant.now() catch unreachable,
        };
    }

    pub fn registerPair(self: *Coinbase, pair: Pair) !*Status {
        const hash_key = try self.pair_map.put(pair);

        self.mutex.lock();
        defer self.mutex.unlock();

        // Check if already registered
        if (self.status_map.get(hash_key)) |status| {
            return status;
        }

        // Create and initialize OrderBook
        const order_book = try self.allocator.create(OrderBook);
        order_book.* = try OrderBook.init(self.allocator);
        try self.orderbooks_map.put(hash_key, order_book);

        // Create Status with default values
        const status = try self.allocator.create(Status);
        status.* = .{
            .price = 0.0,
            .order_book = order_book,
            .best_bid = 0.0,
            .best_bid_size = 0.0,
            .best_ask = 0.0,
            .best_ask_size = 0.0,
            .last_update_time = "",
        };
        try self.status_map.put(hash_key, status);

        // Set subscription status
        try self.subscription_status.put(hash_key, .NotSubscribed);

        // Get initial price
        const price = try self.get_buy_price(pair);
        status.updatePrice(price.price);

        // Start WebSocket thread if not already running
        if (self.ws_thread == null) {
            self.ws_thread = try Thread.spawn(.{}, websocketThread, .{self});
        }

        return status;
    }

    pub fn getStatus(self: *Coinbase, pair: Pair) ?*Status {
        if (self.pair_map.put(pair)) |hash_key| {
            return self.status_map.get(hash_key);
        } else {
            return null;
        }
    }

    // Static variable for tracking last price update time
    var last_price_update_time: i64 = 0;

    fn websocketThread(coinbase: *Coinbase) !void {
        var tcp_client = try std.net.tcpConnectToHost(coinbase.allocator, "ws-feed.exchange.coinbase.com", 443);
        defer tcp_client.close();

        coinbase.stream = tcp_client;
        coinbase.client = try std.crypto.tls.Client.init(tcp_client, .{
            .host = .{ .explicit = "ws-feed.exchange.coinbase.com" },
            .ca = .{ .no_verification = {} },
            .ssl_key_log_file = null,
        });

        try performWebSocketHandshake(&coinbase.client.?, coinbase.stream.?);
        try subscribeToWebSocketChannels(coinbase, &coinbase.client.?, tcp_client);
        std.time.sleep(500 * std.time.ns_per_ms);

        var reassembly_buffer = std.ArrayList(u8).init(coinbase.allocator);
        defer reassembly_buffer.deinit();

        var full_frame_buffer = std.ArrayList(u8).init(coinbase.allocator);
        defer full_frame_buffer.deinit();

        var header_buf: [32]u8 = undefined;
        var initial_bytes_read: usize = 0;
        var remaining_payload_to_read_for_this_frame: usize = 0;

        var read_buf: [1024 * 1024]u8 = undefined;
        var expecting_continuation: bool = false;
        var current_message_opcode: WebSocketOpcode = .text;

        main_read_loop: while (!coinbase.stop_ws_thread.load(.seq_cst)) {
            var new_pairs_added = false;
            coinbase.mutex.lock();
            var sub_it = coinbase.subscription_status.iterator();
            while (sub_it.next()) |entry| {
                if (entry.value_ptr.* == .NotSubscribed) {
                    entry.value_ptr.* = .Pending;
                    new_pairs_added = true;
                }
            }
            coinbase.mutex.unlock();

            if (new_pairs_added) {
                try subscribeToWebSocketChannels(coinbase, &coinbase.client.?, tcp_client);
            }

            const now_ts = std.time.milliTimestamp();
            if (now_ts - coinbase.last_ping_time > 30000) {
                sendWebSocketPing(&coinbase.client.?, tcp_client) catch {
                    try reconnectWebSocket(coinbase, &tcp_client);
                    continue;
                };
                coinbase.last_ping_time = now_ts;
            }

            const bytes_read = coinbase.client.?.read(tcp_client, &read_buf) catch {
                std.time.sleep(100 * std.time.ns_per_ms);
                continue;
            };
            if (bytes_read == 0) {
                try reconnectWebSocket(coinbase, &tcp_client);
                continue;
            }

            const data_chunk = read_buf[0..bytes_read];
            var offset: usize = 0;

            while (offset < data_chunk.len) {
                const remaining_chunk = data_chunk[offset..];

                const frame_header = parseWebSocketFrameHeader(remaining_chunk) catch {
                    offset += 1;
                    reassembly_buffer.clearRetainingCapacity();
                    expecting_continuation = false;
                    continue;
                };

                const declared_payload_len_u64 = frame_header.payload_length;
                const declared_payload_len = @as(usize, @intCast(declared_payload_len_u64));
                const header_size = frame_header.header_size;
                const total_frame_on_wire_size = header_size + declared_payload_len;

                if (remaining_chunk.len >= total_frame_on_wire_size) {
                    @memcpy(header_buf[0..header_size], remaining_chunk[0..header_size]);
                    initial_bytes_read = header_size;
                    full_frame_buffer.clearRetainingCapacity();
                    try full_frame_buffer.appendSlice(remaining_chunk[0..total_frame_on_wire_size]);
                } else {
                    @memcpy(header_buf[0..header_size], remaining_chunk[0..header_size]);
                    initial_bytes_read = header_size;
                    full_frame_buffer.clearRetainingCapacity();
                    try full_frame_buffer.appendSlice(header_buf[0..initial_bytes_read]);

                    var bytes_of_payload_already_in_header_buf: usize = 0;
                    if (initial_bytes_read > header_size) {
                        bytes_of_payload_already_in_header_buf = initial_bytes_read - header_size;
                        try full_frame_buffer.appendSlice(header_buf[header_size..initial_bytes_read]);
                    }

                    remaining_payload_to_read_for_this_frame = total_frame_on_wire_size - full_frame_buffer.items.len;

                    if (remaining_payload_to_read_for_this_frame > 0) {
                        try full_frame_buffer.ensureTotalCapacity(total_frame_on_wire_size);
                        var temp_read_chunk: [8192]u8 = undefined;
                        var read_attempts: usize = 0;
                        const max_read_attempts: usize = 10;

                        while (remaining_payload_to_read_for_this_frame > 0) {
                            const to_read_now = @min(remaining_payload_to_read_for_this_frame, temp_read_chunk.len);

                            const n = coinbase.client.?.read(tcp_client, temp_read_chunk[0..to_read_now]) catch |r_err| {
                                if (r_err == error.WouldBlock) {
                                    read_attempts += 1;
                                    if (read_attempts >= max_read_attempts) {
                                        break;
                                    }
                                    std.time.sleep(50 * std.time.ns_per_ms);
                                    if (coinbase.stop_ws_thread.load(.seq_cst)) {
                                        break :main_read_loop;
                                    }
                                    continue;
                                }
                                if (r_err == error.ConnectionTimedOut or r_err == error.BrokenPipe) {
                                    try reconnectWebSocket(coinbase, &tcp_client);
                                    break :main_read_loop;
                                }
                                break :main_read_loop;
                            };

                            if (n == 0) {
                                break;
                            }

                            try full_frame_buffer.appendSlice(temp_read_chunk[0..n]);
                            remaining_payload_to_read_for_this_frame -= n;
                            read_attempts = 0;
                        }
                    }
                }

                const complete_frame_data = full_frame_buffer.items;
                if (complete_frame_data.len != total_frame_on_wire_size) {
                    continue;
                }

                var unmasked_payload_storage: [1024 * 768]u8 = undefined;
                var final_payload_to_process: []const u8 = undefined;
                const actual_payload_offset = frame_header.header_size;

                if (remaining_chunk.len >= actual_payload_offset + declared_payload_len) {
                    if (frame_header.mask and frame_header.mask_key != null) {
                        if (declared_payload_len > unmasked_payload_storage.len) {
                            continue;
                        }
                        const key = frame_header.mask_key.?;
                        const raw_payload_in_frame = remaining_chunk[actual_payload_offset .. actual_payload_offset + declared_payload_len];
                        for (raw_payload_in_frame, 0..) |byte, i| {
                            unmasked_payload_storage[i] = byte ^ key[i % 4];
                        }
                        final_payload_to_process = unmasked_payload_storage[0..declared_payload_len];
                    } else {
                        final_payload_to_process = remaining_chunk[actual_payload_offset .. actual_payload_offset + declared_payload_len];
                    }
                } else {
                    if (frame_header.mask and frame_header.mask_key != null) {
                        if (declared_payload_len > unmasked_payload_storage.len) {
                            continue;
                        }
                        const key = frame_header.mask_key.?;
                        const raw_payload_in_frame = complete_frame_data[actual_payload_offset .. actual_payload_offset + declared_payload_len];
                        for (raw_payload_in_frame, 0..) |byte, i| {
                            unmasked_payload_storage[i] = byte ^ key[i % 4];
                        }
                        final_payload_to_process = unmasked_payload_storage[0..declared_payload_len];
                    } else {
                        final_payload_to_process = complete_frame_data[actual_payload_offset .. actual_payload_offset + declared_payload_len];
                    }
                }

                switch (frame_header.opcode) {
                    .ping => {
                        if (frame_header.payload_length > 0) {
                            sendWebSocketPong(&coinbase.client.?, tcp_client, final_payload_to_process) catch {
                                try reconnectWebSocket(coinbase, &tcp_client);
                                break :main_read_loop;
                            };
                        }
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                    .pong => {
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                    .close => {
                        try reconnectWebSocket(coinbase, &tcp_client);
                        break :main_read_loop;
                    },
                    .continuation => {
                        if (!expecting_continuation) {
                            offset += total_frame_on_wire_size;
                            continue;
                        }
                        try reassembly_buffer.appendSlice(final_payload_to_process);

                        if (frame_header.fin) {
                            try processCompleteMessage(reassembly_buffer.items, current_message_opcode, coinbase, &tcp_client);
                            reassembly_buffer.clearRetainingCapacity();
                            expecting_continuation = false;
                        }
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                    .text, .binary => {
                        if (expecting_continuation) {
                            try processCompleteMessage(reassembly_buffer.items, current_message_opcode, coinbase, &tcp_client);
                            reassembly_buffer.clearRetainingCapacity();
                            expecting_continuation = false;
                        }

                        reassembly_buffer.clearRetainingCapacity();
                        try reassembly_buffer.appendSlice(final_payload_to_process);
                        current_message_opcode = frame_header.opcode;

                        if (frame_header.fin) {
                            try processCompleteMessage(reassembly_buffer.items, current_message_opcode, coinbase, &tcp_client);
                            reassembly_buffer.clearRetainingCapacity();
                        } else {
                            expecting_continuation = true;
                        }
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                    .control_frame_b, .control_frame_c, .control_frame_d, .control_frame_e => {
                        if (frame_header.opcode == .control_frame_c or frame_header.opcode == .control_frame_d) {
                            if (frame_header.payload_length > 0) {
                                sendWebSocketPong(&coinbase.client.?, tcp_client, final_payload_to_process) catch {
                                    try reconnectWebSocket(coinbase, &tcp_client);
                                    break :main_read_loop;
                                };
                            }
                        }
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                    else => {
                        offset += total_frame_on_wire_size;
                        continue;
                    },
                }

                offset += total_frame_on_wire_size;
            }
        }
    }

    fn reconnectWebSocket(coinbase: *Coinbase, tcp_client: *std.net.Stream) !void {
        std.debug.print("Attempting to reconnect WebSocket...\n", .{});

        // Close existing connection
        tcp_client.close();

        // Wait a bit before reconnecting
        std.time.sleep(1000 * std.time.ns_per_ms);

        // Create new connection
        tcp_client.* = try std.net.tcpConnectToHost(coinbase.allocator, "ws-feed.exchange.coinbase.com", 443);

        // Set TCP options

        // Update stream and client
        coinbase.stream = tcp_client.*;
        coinbase.client = try std.crypto.tls.Client.init(tcp_client.*, .{
            .host = .{ .explicit = "ws-feed.exchange.coinbase.com" },
            .ca = .{ .no_verification = {} },
            .ssl_key_log_file = null,
        });

        // Perform handshake
        try performWebSocketHandshake(&coinbase.client.?, coinbase.stream.?);

        // Resubscribe to channels
        try subscribeToWebSocketChannels(coinbase, &coinbase.client.?, tcp_client.*);

        std.debug.print("WebSocket reconnected successfully\n", .{});
    }

    fn processCompleteMessage(payload: []const u8, original_opcode: WebSocketOpcode, coinbase: *Coinbase, stream: anytype) !void {
        // Handle control frames first
        switch (original_opcode) {
            .close => {
                std.debug.print("CLOSE frame. Payload: {s}\n", .{payload});
                return;
            },
            .ping => {
                try sendWebSocketPong(&coinbase.client.?, stream, payload);
                std.debug.print("Sent PONG\n", .{});
                return;
            },
            .pong => {
                std.debug.print("PONG received\n", .{});
                return;
            },
            .text, .binary => {
                // Process both text and binary messages in the same format ["buy", "1300.0", "0.1"]
                std.debug.print("Processing message of length {d}\n", .{payload.len});

                // Skip if payload is too short to be valid
                if (payload.len < 3) {
                    std.debug.print("Payload too short\n", .{});
                    return;
                }

                // Find opening bracket
                var i: usize = 0;
                while (i < payload.len and payload[i] != '[') : (i += 1) {}
                if (i == payload.len) {
                    std.debug.print("No opening bracket found\n", .{});
                    return;
                }
                i += 1; // Skip the opening bracket

                // Parse side (buy/sell)
                while (i < payload.len and payload[i] == ' ') : (i += 1) {} // Skip spaces
                if (i == payload.len or payload[i] != '"') {
                    std.debug.print("Expected quote for side\n", .{});
                    return;
                }
                i += 1; // Skip opening quote
                const side_start = i;
                while (i < payload.len and payload[i] != '"') : (i += 1) {}
                if (i == payload.len) {
                    std.debug.print("No closing quote for side\n", .{});
                    return;
                }
                const side = payload[side_start..i];
                i += 1; // Skip closing quote

                // Skip to next value
                while (i < payload.len and (payload[i] == ' ' or payload[i] == ',')) : (i += 1) {}

                // Parse price
                if (i == payload.len or payload[i] != '"') {
                    std.debug.print("Expected quote for price\n", .{});
                    return;
                }
                i += 1; // Skip opening quote
                const price_start = i;
                while (i < payload.len and payload[i] != '"') : (i += 1) {}
                if (i == payload.len) {
                    std.debug.print("No closing quote for price\n", .{});
                    return;
                }
                const price_str = payload[price_start..i];
                i += 1; // Skip closing quote

                // Skip to next value
                while (i < payload.len and (payload[i] == ' ' or payload[i] == ',')) : (i += 1) {}

                // Parse size
                if (i == payload.len or payload[i] != '"') {
                    std.debug.print("Expected quote for size\n", .{});
                    return;
                }
                i += 1; // Skip opening quote
                const size_start = i;
                while (i < payload.len and payload[i] != '"') : (i += 1) {}
                if (i == payload.len) {
                    std.debug.print("No closing quote for size\n", .{});
                    return;
                }
                const size_str = payload[size_start..i];
                i += 1; // Skip closing quote

                // Skip to closing bracket
                while (i < payload.len and payload[i] != ']') : (i += 1) {}
                if (i == payload.len) {
                    std.debug.print("No closing bracket found\n", .{});
                    return;
                }

                // Parse the values
                const price = std.fmt.parseFloat(f64, price_str) catch {
                    std.debug.print("Invalid price format: {s}\n", .{price_str});
                    return;
                };
                const size = std.fmt.parseFloat(f64, size_str) catch {
                    std.debug.print("Invalid size format: {s}\n", .{size_str});
                    return;
                };

                std.debug.print("Parsed order: {s} {d} @ {d}\n", .{ side, size, price });

                // Update the order book
                // Get the pair key for ETH-USD (hardcoded for now since we know we're only handling ETH-USD)
                const pair_key = try coinbase.pair_map.getPairKeyByProductId(coinbase.allocator, "ETH-USD");
                if (coinbase.orderbooks_map.get(pair_key)) |order_book| {
                    var updates = std.ArrayList(Level2Update).init(coinbase.allocator);
                    defer updates.deinit();

                    try updates.append(Level2Update{
                        .side = side,
                        .event_time = "",
                        .price_level = price_str,
                        .new_quantity = size_str,
                    });

                    try order_book.update(coinbase.allocator, updates.items);
                    std.debug.print("Updated order book with {s} order: {s} @ {s}\n", .{ side, size_str, price_str });
                } else {
                    std.debug.print("No order book found for pair key {d}\n", .{pair_key});
                }
            },
            else => {
                std.debug.print("Unhandled opcode: {any}\n", .{original_opcode});
            },
        }
    }

    fn sendWebSocketPong(client: *std.crypto.tls.Client, stream: anytype, payload: []const u8) !void {
        var frame_buffer: [14 + 125]u8 = undefined; // Max header size + max control frame payload

        // Create WebSocket frame header
        frame_buffer[0] = 0x8A; // FIN + Pong opcode

        const payload_len = @min(payload.len, 125);
        frame_buffer[1] = @as(u8, @intCast(payload_len));

        // Copy payload
        @memcpy(frame_buffer[2..][0..payload_len], payload[0..payload_len]);

        // Send the frame
        try client.writeAll(stream, frame_buffer[0 .. 2 + payload_len]);
    }

    fn performWebSocketHandshake(client: *std.crypto.tls.Client, stream: anytype) !void {
        // Generate a random WebSocket key
        var random_key: [16]u8 = undefined;
        std.crypto.random.bytes(&random_key);

        // Create a buffer to hold the base64 encoded key
        var base64_key_buffer: [24]u8 = undefined; // Base64 encoding of 16 bytes requires 24 bytes
        const base64_key = std.base64.standard.Encoder.encode(&base64_key_buffer, &random_key);

        // Prepare handshake request using runtime formatting
        var handshake_buffer: [512]u8 = undefined;
        const handshake_request = try std.fmt.bufPrint(&handshake_buffer, "GET /ws HTTP/1.1\r\n" ++
            "Host: ws-feed.exchange.coinbase.com\r\n" ++
            "Upgrade: websocket\r\n" ++
            "Connection: Upgrade\r\n" ++
            "Sec-WebSocket-Key: {s}\r\n" ++
            "Sec-WebSocket-Version: 13\r\n" ++
            "\r\n", .{base64_key});

        try client.writeAll(stream, handshake_request);

        // Read the server's handshake response
        var response_buffer: [2048]u8 = undefined;
        const bytes_read = try client.read(stream, &response_buffer);
        const response = response_buffer[0..bytes_read];

        // Check for successful upgrade
        if (!std.mem.startsWith(u8, response, "HTTP/1.1 101")) {
            std.debug.print("WebSocket handshake failed: {s}\n", .{response});
            return error.WebSocketHandshakeFailed;
        }

        // Successfully upgraded to WebSocket
        std.debug.print("WebSocket connection established\n", .{});
    }

    fn subscribeToWebSocketChannels(coinbase: *Coinbase, client: *std.crypto.tls.Client, stream: anytype) !void {
        var product_ids = std.ArrayList([]const u8).init(coinbase.allocator);
        defer product_ids.deinit();

        coinbase.mutex.lock();
        var pending_pairs_exist = false;
        var it = coinbase.subscription_status.iterator();
        while (it.next()) |entry| {
            if (entry.value_ptr.* == .Pending) {
                pending_pairs_exist = true;
            }
            // Collect all pairs that are either pending or already subscribed for the product_ids list
            if (entry.value_ptr.* == .Pending or entry.value_ptr.* == .Subscribed) {
                if (coinbase.pair_map.getPairByKey(entry.key_ptr.*)) |pair| {
                    const product_id = try std.fmt.allocPrint(coinbase.allocator, "{s}-{s}", .{ pair.base, pair.quote });
                    try product_ids.append(product_id); // We need to free this later
                }
            }
        }
        coinbase.mutex.unlock();

        if (product_ids.items.len == 0 and !pending_pairs_exist) {
            std.debug.print("No products to subscribe to or update.\n", .{});
            return;
        }

        // Defer freeing of allocated product_id strings
        defer {
            for (product_ids.items) |pid_str| {
                coinbase.allocator.free(pid_str);
            }
        }

        // Phase 1: Subscribe to public channels (ticker, heartbeat)
        var public_channels_list = std.ArrayList(Channel).init(coinbase.allocator);
        defer public_channels_list.deinit();

        try public_channels_list.append(Channel{ .name = "ticker", .product_ids = product_ids.items });
        try public_channels_list.append(Channel{ .name = "heartbeat", .product_ids = product_ids.items });

        const public_sub_req = WebSocketRequest{
            .type = "subscribe",
            .product_ids = product_ids.items, // product_ids at top level for these too
            .channels = public_channels_list.items,
            .signature = null,
            .key = null,
            .passphrase = "", // Per Coinbase docs, can be empty for public channels
            .timestamp = null,
        };
        const public_json = try std.json.stringifyAlloc(coinbase.allocator, public_sub_req, .{});
        defer coinbase.allocator.free(public_json);
        std.debug.print("Sending public subscription: {s}\n", .{public_json});
        try sendWebSocketTextFrame(client, stream, public_json);

        // Short delay for server to process
        // Consider waiting for subscription confirmation here if issues persist

        // Phase 2: If API credentials are provided, subscribe to authenticated level2_batch channel
        if (coinbase.credentials.api_key.len > 0 and coinbase.credentials.secret_key.len > 0) {
            std.debug.print("Attempting authenticated subscription for level2_batch...\n", .{});

            const timestamp_value = @as(u64, @intCast(time.timestamp()));
            const timestamp_str = try std.fmt.allocPrint(coinbase.allocator, "{d}", .{timestamp_value});
            defer coinbase.allocator.free(timestamp_str);

            const method = "GET";
            const request_path = "/users/self/verify";
            const message_to_sign = try std.fmt.allocPrint(coinbase.allocator, "{s}{s}{s}", .{ timestamp_str, method, request_path });
            defer coinbase.allocator.free(message_to_sign);

            var decoded_secret: [1024]u8 = undefined;
            if (decodeBase64Secret(&decoded_secret, coinbase.credentials.secret_key)) |key_len| {
                var signature_out: [32]u8 = undefined;
                var hmac_instance = Hmac.init(decoded_secret[0..key_len]);
                hmac_instance.update(message_to_sign);
                hmac_instance.final(&signature_out);

                var signature_buf: [4096]u8 = undefined;
                const signature_encoded = base64.standard.Encoder.encode(&signature_buf, &signature_out);
                const signature_final = try coinbase.allocator.dupe(u8, signature_encoded);
                defer coinbase.allocator.free(signature_final); // Free the duplicated signature string

                var auth_channels_list = std.ArrayList(Channel).init(coinbase.allocator);
                defer auth_channels_list.deinit();
                try auth_channels_list.append(Channel{ .name = "level2_batch", .product_ids = product_ids.items });

                const auth_sub_req = WebSocketRequest{
                    .type = "subscribe",
                    .product_ids = product_ids.items, // Include product_ids at top level as per examples
                    .channels = auth_channels_list.items,
                    .signature = signature_final,
                    .key = coinbase.credentials.api_key,
                    .passphrase = coinbase.credentials.passphrase, // Send actual passphrase if available
                    .timestamp = timestamp_str,
                };

                const auth_json = try std.json.stringifyAlloc(coinbase.allocator, auth_sub_req, .{});
                defer coinbase.allocator.free(auth_json);
                std.debug.print("Sending authenticated level2_batch subscription: {s}\n", .{auth_json});
                try sendWebSocketTextFrame(client, stream, auth_json);
            } else {
                std.debug.print("Failed to decode secret key for level2_batch. Will only receive public channel data.\n", .{});
            }
        } else {
            std.debug.print("No API key/secret for authenticated channels. Sticking to public data.\n", .{});
        }

        // Mark all pending subscriptions as subscribed (assuming server will confirm or reject)
        markPendingAsSubscribed(coinbase);
    }

    // Helper function to mark all pending subscriptions as subscribed
    fn markPendingAsSubscribed(coinbase: *Coinbase) void {
        coinbase.mutex.lock();
        defer coinbase.mutex.unlock();

        var status_it = coinbase.subscription_status.iterator();
        while (status_it.next()) |entry| {
            if (entry.value_ptr.* == .Pending) {
                entry.value_ptr.* = .Subscribed;
            }
        }
    }

    fn sendWebSocketTextFrame(client: *std.crypto.tls.Client, stream: anytype, payload: []const u8) !void {
        var frame_buffer: [14 + 65535]u8 = undefined; // Max header size + reasonable payload limit

        // Create WebSocket frame header with masking (client must mask)
        frame_buffer[0] = 0x81; // FIN + Text opcode

        var header_len: usize = 2;

        // Set payload length
        if (payload.len < 126) {
            frame_buffer[1] = 0x80 | @as(u8, @intCast(payload.len)); // Set mask bit
        } else if (payload.len <= 65535) {
            frame_buffer[1] = 0x80 | 126; // Set mask bit
            frame_buffer[2] = @as(u8, @intCast((payload.len >> 8) & 0xFF));
            frame_buffer[3] = @as(u8, @intCast(payload.len & 0xFF));
            header_len = 4;
        } else {
            frame_buffer[1] = 0x80 | 127; // Set mask bit
            frame_buffer[2] = 0;
            frame_buffer[3] = 0;
            frame_buffer[4] = 0;
            frame_buffer[5] = 0;
            frame_buffer[6] = @as(u8, @intCast((payload.len >> 24) & 0xFF));
            frame_buffer[7] = @as(u8, @intCast((payload.len >> 16) & 0xFF));
            frame_buffer[8] = @as(u8, @intCast((payload.len >> 8) & 0xFF));
            frame_buffer[9] = @as(u8, @intCast(payload.len & 0xFF));
            header_len = 10;
        }

        // Generate a random mask key (client MUST mask according to the spec)
        var mask_key: [4]u8 = undefined;
        std.crypto.random.bytes(&mask_key);
        frame_buffer[header_len] = mask_key[0];
        frame_buffer[header_len + 1] = mask_key[1];
        frame_buffer[header_len + 2] = mask_key[2];
        frame_buffer[header_len + 3] = mask_key[3];
        header_len += 4;

        // Copy and mask payload
        for (payload, 0..) |byte, i| {
            frame_buffer[header_len + i] = byte ^ mask_key[i % 4];
        }

        // Send the frame
        try client.writeAll(stream, frame_buffer[0 .. header_len + payload.len]);
    }

    // Helper function to decode a base64 secret key
    fn decodeBase64Secret(out_buf: *[1024]u8, secret: []const u8) ?usize {
        base64.standard.Decoder.decode(out_buf, secret) catch |err| {
            std.debug.print("Base64 decode error: {s}\n", .{@errorName(err)});
            return null;
        };

        // Find the key length (up to the first null byte or the full buffer)
        for (out_buf.*, 0..) |byte, i| {
            if (byte == 0 and i > 0) {
                return i;
            }
        }

        // Default to 32 bytes for HMAC-SHA256
        return 32;
    }

    // Generate a JWT token for Coinbase API authentication
    fn generateCoinbaseJWT(api_key: []const u8) ![]const u8 {
        // Simple validation - if it doesn't look like a key at all, fail early
        if (api_key.len < 10) {
            return error.InvalidApiKeyFormat;
        }

        // In a real-world scenario, you would:
        // 1. Parse the private key from PEM format
        // 2. Create a JWT header and payload
        // 3. Sign with ES256 algorithm
        // 4. Return the complete JWT token

        // For this example, we'll just use a placeholder approach:
        // Extract the API key string and pass it directly as the JWT
        // This will enable basic authentication but won't work for production

        std.debug.print("Attempting to authenticate API access for level2 data\n", .{});

        // Normally you would create a proper JWT with claims, expiry time, etc.
        // For more information, see: https://docs.cloud.coinbase.com/exchange/docs/authorization-jwt

        return api_key;
    }

    fn sendWebSocketClose(client: *std.crypto.tls.Client, stream: anytype, status_code: u16, reason: []const u8) !void {
        var frame_buffer: [14 + 125]u8 = undefined; // Max header size + max control frame payload

        // Create WebSocket frame header
        frame_buffer[0] = 0x88; // FIN + Close opcode

        // Add status code and reason
        frame_buffer[2] = @as(u8, @intCast((status_code >> 8) & 0xFF));
        frame_buffer[3] = @as(u8, @intCast(status_code & 0xFF));
        const payload_len = @min(reason.len, 123); // Leave room for status code
        @memcpy(frame_buffer[4..][0..payload_len], reason[0..payload_len]);

        // Set payload length
        frame_buffer[1] = @as(u8, @intCast(2 + payload_len));

        // Send the frame
        try client.writeAll(stream, frame_buffer[0 .. 4 + payload_len]);
    }
};

fn handleTickerMessage(coinbase: *Coinbase, ticker: WebSocketTicker) !void {
    const product_id = ticker.product_id;

    // Find the pair for this product ID
    var found_key: ?u64 = null;
    coinbase.mutex.lock();
    const pair_iter = coinbase.pair_map.pairs.items;
    for (pair_iter, 0..) |pair, i| {
        const pair_str = try std.fmt.allocPrint(coinbase.allocator, "{s}-{s}", .{ pair.base, pair.quote });
        defer coinbase.allocator.free(pair_str);

        if (mem.eql(u8, pair_str, product_id)) {
            found_key = coinbase.pair_map.keys.items[i];
            break;
        }
    }
    coinbase.mutex.unlock();

    if (found_key) |key| {
        // Update the price and best bid/ask information
        if (coinbase.status_map.get(key)) |status| {
            // Current price
            const price = try std.fmt.parseFloat(f64, ticker.price);
            status.updatePrice(price);

            // Check if all required bid/ask fields are present and valid
            var best_bid: f64 = 0.0;
            _ = std.fmt.parseFloat(f64, ticker.best_bid) catch {
                return; // Skip if best_bid is not a valid float
            };

            var best_bid_size: f64 = 0.0;
            _ = std.fmt.parseFloat(f64, ticker.best_bid_size) catch {
                return; // Skip if best_bid_size is not a valid float
            };

            var best_ask: f64 = 0.0;
            _ = std.fmt.parseFloat(f64, ticker.best_ask) catch {
                return; // Skip if best_ask is not a valid float
            };

            var best_ask_size: f64 = 0.0;
            _ = std.fmt.parseFloat(f64, ticker.best_ask_size) catch {
                return; // Skip if best_ask_size is not a valid float
            };

            // Parse all values now that we know they're valid
            best_bid = try std.fmt.parseFloat(f64, ticker.best_bid);
            best_bid_size = try std.fmt.parseFloat(f64, ticker.best_bid_size);
            best_ask = try std.fmt.parseFloat(f64, ticker.best_ask);
            best_ask_size = try std.fmt.parseFloat(f64, ticker.best_ask_size);

            // Update the status with best bid/ask information
            status.updateBestBidAsk(best_bid, best_bid_size, best_ask, best_ask_size, ticker.time);

            // Also update the order book with the best bid/ask
            status.order_book.mutex.lock();
            defer status.order_book.mutex.unlock();

            // Mark as limited data since we're using ticker data
            status.order_book.limited_data = true;

            // Rebuild the order book with current best bid/ask if it's empty
            if (status.order_book.bids.len == 0 or status.order_book.asks.len == 0) {
                const allocator = coinbase.allocator;

                // Free existing entries
                allocator.free(status.order_book.bids);
                allocator.free(status.order_book.asks);

                // Create new entries with best bid/ask
                status.order_book.bids = allocator.alloc(OrderBookEntry, 1) catch &[_]OrderBookEntry{};
                status.order_book.asks = allocator.alloc(OrderBookEntry, 1) catch &[_]OrderBookEntry{};

                if (status.order_book.bids.len > 0) {
                    status.order_book.bids[0] = .{ .price = best_bid, .size = best_bid_size };
                }

                if (status.order_book.asks.len > 0) {
                    status.order_book.asks[0] = .{ .price = best_ask, .size = best_ask_size };
                }
            }
        }
    }
}

// Helper function to update a specific side of the order book
fn updateOrderBookSide(allocator: std.mem.Allocator, book_side: *[]OrderBookEntry, price: f64, size: f64) !void {
    // Check if this price level already exists
    for (book_side.*) |*entry| {
        if (std.math.approxEqAbs(f64, entry.price, price, 0.000001)) {
            if (size == 0) {
                // Remove this price level
                entry.size = 0;
            } else {
                // Update size
                entry.size = size;
            }

            // Clean up zero-sized entries
            var non_zero_count: usize = 0;
            for (book_side.*) |e| {
                if (e.size > 0) non_zero_count += 1;
            }

            var new_side = try allocator.alloc(OrderBookEntry, non_zero_count);
            var idx: usize = 0;

            for (book_side.*) |e| {
                if (e.size > 0) {
                    new_side[idx] = e;
                    idx += 1;
                }
            }

            allocator.free(book_side.*);
            book_side.* = new_side;
            return;
        }
    }

    // Price level not found and size > 0, add a new entry
    if (size > 0) {
        const new_side = try allocator.alloc(OrderBookEntry, book_side.len + 1);
        @memcpy(new_side[0..book_side.len], book_side.*);
        new_side[book_side.len] = .{ .price = price, .size = size };

        allocator.free(book_side.*);
        book_side.* = new_side;
    }
}

const WebSocketOpcode = enum(u4) {
    continuation = 0x0,
    text = 0x1,
    binary = 0x2,
    close = 0x8,
    ping = 0x9,
    pong = 0xA,
    // Add support for all opcodes
    data_frame_3 = 0x3,
    data_frame_4 = 0x4,
    data_frame_5 = 0x5,
    data_frame_6 = 0x6,
    data_frame_7 = 0x7,
    data_frame_f = 0xF,
    // Reserved control frames - these should be ignored
    control_frame_b = 0xB,
    control_frame_c = 0xC,
    control_frame_d = 0xD,
    control_frame_e = 0xE,
};

const WebSocketFrameHeader = struct {
    fin: bool,
    opcode: WebSocketOpcode,
    mask: bool,
    payload_length: u64,
    header_size: usize,
    mask_key: ?[4]u8 = null,
};

fn parseWebSocketFrameHeader(data: []const u8) !WebSocketFrameHeader {
    if (data.len < 2) return error.InvalidWebSocketFrame;

    const byte1 = data[0];
    const byte2 = data[1];
    const fin = (byte1 & 0x80) != 0;
    const opcode_val = byte1 & 0x0F;
    const opcode: WebSocketOpcode = @enumFromInt(opcode_val);
    const mask = (byte2 & 0x80) != 0;
    const payload_length_7bit: u8 = byte2 & 0x7F;
    var header_size: usize = 2;
    var actual_payload_length: u64 = 0;

    if (payload_length_7bit < 126) {
        actual_payload_length = payload_length_7bit;
    } else if (payload_length_7bit == 126) {
        header_size += 2;
        if (data.len < header_size) return error.InvalidWebSocketFrame;
        actual_payload_length = @as(u64, data[2]) << 8 | @as(u64, data[3]);
    } else { // 127
        header_size += 8;
        if (data.len < header_size) return error.InvalidWebSocketFrame;
        actual_payload_length = @as(u64, data[2]) << 56 |
            @as(u64, data[3]) << 48 |
            @as(u64, data[4]) << 40 |
            @as(u64, data[5]) << 32 |
            @as(u64, data[6]) << 24 |
            @as(u64, data[7]) << 16 |
            @as(u64, data[8]) << 8 |
            @as(u64, data[9]);
    }
    var mask_key_val: ?[4]u8 = null;
    if (mask) {
        if (data.len < header_size + 4) return error.InvalidWebSocketFrame;
        mask_key_val = .{ data[header_size], data[header_size + 1], data[header_size + 2], data[header_size + 3] };
        header_size += 4;
    }
    return WebSocketFrameHeader{
        .fin = fin,
        .opcode = opcode,
        .mask = mask,
        .payload_length = actual_payload_length,
        .header_size = header_size,
        .mask_key = mask_key_val,
    };
}

fn sendWebSocketPing(client: *std.crypto.tls.Client, stream: anytype) !void {
    var frame_buffer: [14]u8 = undefined; // Enough for header + masking key

    // Create WebSocket frame header with masking
    frame_buffer[0] = 0x89; // FIN + Ping opcode
    frame_buffer[1] = 0x80; // Masked, no payload

    // Generate a random mask key
    var mask_key: [4]u8 = undefined;
    std.crypto.random.bytes(&mask_key);
    frame_buffer[2] = mask_key[0];
    frame_buffer[3] = mask_key[1];
    frame_buffer[4] = mask_key[2];
    frame_buffer[5] = mask_key[3];

    // Send the frame (header only, no payload)
    try client.writeAll(stream, frame_buffer[0..6]);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Coinbase API credentials
    // To get full order book data, you need to provide valid API credentials
    // If not provided, the system will only receive ticker data
    const credentials = CoinbaseCredentials{
        .passphrase = "", // Your Coinbase API passphrase - REQUIRED for level2 data
    };

    // CRITICAL COINBASE AUTHENTICATION INFORMATION:
    // The secret key MUST be a base64-encoded string directly from Coinbase API page.
    // If you're using an EC private key or PEM format, that's NOT correct.
    // The correct format from Coinbase should look like: "a1b2c3d4e5f6g7h8i9j0..."
    // You need BOTH a valid API key AND a passphrase for level2 authentication.
    // Get these from: Coinbase Advanced → Settings → API → New API Key

    // Display a notice about whether we're in ticker-only mode
    if (credentials.api_key.len == 0 or
        credentials.secret_key.len == 0)
    {
        std.debug.print("\n-----------------------------------------------------------------\n", .{});
        std.debug.print("NOTE: For full order book data, you need valid Coinbase API credentials\n", .{});
        std.debug.print("This example will only receive ticker data (best bid/ask prices)\n", .{});
        std.debug.print("-----------------------------------------------------------------\n\n", .{});
    }

    const coinbase = try Coinbase.init(allocator, credentials);
    defer coinbase.deinit();

    // Register a pair to track
    const eth_usd_pair = Pair{ .base = "ETH", .quote = "USD" };
    const status = try coinbase.registerPair(eth_usd_pair);
    // Wait a bit for the WebSocket connection to establish and fetch data
    std.debug.print("Connecting to Coinbase WebSocket and fetching order book...\n", .{});

    // Display the current status
    std.debug.print("\nETH-USD Status:\n", .{});
    std.debug.print("  Price: {d}\n", .{status.price});

    // Keep the program running to continue receiving updates
    std.debug.print("\nPress Ctrl+C to exit...\n", .{});
    while (true) {
        std.time.sleep(1 * std.time.ns_per_s);
        status.order_book.mutex.lock();
        defer status.order_book.mutex.unlock();

        std.debug.print("  Order Book:\n", .{});
        if (status.order_book.limited_data) {
            std.debug.print("    (TICKER DATA ONLY - Using best bid/ask)\n", .{});
        }
        std.debug.print("    Asks: {d} entries\n", .{status.order_book.asks.len});
        if (status.order_book.asks.len > 0) {
            std.debug.print("      Best ask: {d:.2} @ {d:.6}\n", .{ status.order_book.asks[0].price, status.order_book.asks[0].size });
            // Print a few more ask levels if available
            const ask_display_count = @min(status.order_book.asks.len, 5);
            for (status.order_book.asks[0..ask_display_count]) |ask| {
                std.debug.print("      {d:.2} @ {d:.6}\n", .{ ask.price, ask.size });
            }
        }

        std.debug.print("    Bids: {d} entries\n", .{status.order_book.bids.len});
        if (status.order_book.bids.len > 0) {
            std.debug.print("      Best bid: {d:.2} @ {d:.6}\n", .{ status.order_book.bids[0].price, status.order_book.bids[0].size });
            // Print a few more bid levels if available
            const bid_display_count = @min(status.order_book.bids.len, 5);
            for (status.order_book.bids[0..bid_display_count]) |bid| {
                std.debug.print("      {d:.2} @ {d:.6}\n", .{ bid.price, bid.size });
            }
        }

        // Add a separator between updates
        std.debug.print("  -----------------------------\n", .{});
    }
}
