const std = @import("std");

pub const Value = @import("./value.zig").Value;

pub const Keyword = enum {
    @"fn",
    @"return",
    @"if",
    @"else",
    @"while",
    @"for",
    @"break",
    @"continue",
    @"const",
    @"var",
    @"defer",
    true,
    false,
};

pub const Punctuation = enum {
    @"\"",
    @",",
    @"[",
    @"]",
    @"(",
    @")",
    @":",
};

pub const Operator = enum {
    And, // And & and
    Or, // Or | or
    @".",
    @"+",
    @"-",
    @"*",
    @"/",
    @"%",
    @"=",
    @"==",
    @"!=",
    @"<",
    @">",
    @"<=",
    @">=",
    @"!",
    @"~",
    @"&",
    @"|",
    @"^",
    @"<<",
    @">>",
    @"..",
    @"...",
    @"@",
    @"and", // New: textual and operator
    @"or", // New: textual or operator

    pub fn requiresLeftSpace(self: Operator) bool {
        //Should be C like syntax, for instance, dot operator is false but math operators are true
        //TODO this should consider context, for instance, & could be address of (where this is false) or bitwise and (where this is true)
        return switch (self) {
            .@".", .@"@", .@"*", .@"&", .@"...", .@"and", .@"or" => false,
            else => true,
        };
    }

    pub fn requiresRightSpace(self: Operator) bool {
        //Should be C like syntax, for instance, dot operator is false but math operators are true
        //TODO this should consider context, for instance, & could be address of (where this is false) or bitwise and (where this is true)
        return switch (self) {
            .@".", .@"@", .@"*", .@"&", .@"~", .@"!", .@"...", .@"and", .@"or" => false,
            else => true,
        };
    }

    pub fn canBeCompoundAssignment(self: Operator) bool {
        // Only certain operators can be used in compound assignments
        return switch (self) {
            .@"+", .@"-", .@"*", .@"/", .@"%", .@"&", .@"|", .@"^", .@"<<", .@">>" => true,
            else => false,
        };
    }

    pub fn precedence(self: Operator) u8 {
        return switch (self) {
            .@"and" => 2, // Text version 'and' has same precedence as And
            .@"or" => 1, // Text version 'or' has same precedence as Or
            .And => 2,
            .Or => 1,
            .@"<" => 4,
            .@">" => 4,
            .@"<=" => 4,
            .@">=" => 4,
            .@"==" => 4,
            .@"!=" => 4,
            .@"+" => 5,
            .@"-" => 5,
            .@"*" => 6,
            .@"/" => 6,
            .@"%" => 6,
            .@"!" => 7,
            .@"~" => 7,
            .@"&" => 8,
            .@"|" => 8,
            .@"^" => 8,
            .@"<<" => 9,
            .@">>" => 9,
            .@".." => 10,
            .@"..." => 11,
            .@"@" => 12,
            .@"." => 13,
            .@"=" => 3, // Assignment has lower precedence than comparison
        };
    }

    pub fn associativity(self: Operator) Associativity {
        return switch (self) {
            .@".",
            .@"*",
            .@"&",
            .@"...",
            .@"=",
            => .right,
            else => .left,
        };
    }
};

pub const Associativity = enum {
    left,
    right,
};

pub const Token = union(enum) {
    indent,
    newline,
    space,
    comment: []const u8,
    keyword: Keyword,
    operator: Operator,
    literal: Value,
    punctuation: Punctuation,
    identifier: []const u8,

    /// Free any memory allocated by this token
    /// This function now safely handles potential double-free issues by checking
    /// for empty slices before attempting to free memory.
    pub fn deinit(self: *Token, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .identifier => |ident| {
                // Only free non-empty slices
                if (ident.len > 0) {
                    allocator.free(ident);
                }
                self.* = .{ .identifier = "" }; // Zero out after freeing
            },
            .comment => |cmt| {
                // Free comment text if present
                if (cmt.len > 0) {
                    allocator.free(cmt);
                }
                self.* = .{ .comment = "" }; // Zero out after freeing
            },
            .literal => |*val| {
                if (val.* == .string) {
                    // Only free non-empty string slices
                    if (val.string.len > 0) {
                        allocator.free(val.string);
                        val.* = .{ .string = "" }; // Zero out after freeing
                    }
                }
            },
            else => {}, // No allocated memory for other token types
        }
    }
};

pub const Lookup = struct {
    string: []const u8,
    token: Token,

    pub fn compare(a: Lookup, b: Lookup) std.math.Order {
        var key_compare = a.string;
        var value_compare = b.string;

        var result = std.math.Order.eq;

        // Force both values to the same length so we can figure out if key is gt or lt value on a character by character basis.
        if (value_compare.len < key_compare.len) {
            result = std.math.Order.gt;
            key_compare = key_compare[0..value_compare.len];
        } else if (value_compare.len > key_compare.len) {
            result = std.math.Order.lt;
            value_compare = value_compare[0..key_compare.len];
        }

        for (key_compare, value_compare) |k, v| {
            const order = std.math.order(k, v);
            if (order != .eq) {
                return order;
            }
        }

        return result;
    }
};

pub const LookupTable = struct {
    list: std.ArrayList(Lookup),
    longest: usize,

    pub fn deinit(self: *LookupTable) void {
        self.list.deinit();
    }
};

fn buildLookupTable(allocator: std.mem.Allocator) !LookupTable {
    std.debug.print("DEBUG: Building lookup table\n", .{});
    var lexerTable = std.StringHashMap(Token).init(allocator);
    defer lexerTable.deinit();

    // Keywords
    const keyword_strings = [_][]const u8{ "fn", "return", "if", "else", "while", "for", "break", "continue", "const", "var", "defer", "true", "false" };
    const keyword_values = [_]Keyword{ .@"fn", .@"return", .@"if", .@"else", .@"while", .@"for", .@"break", .@"continue", .@"const", .@"var", .@"defer", .true, .false };
    comptime {
        if (keyword_strings.len != keyword_values.len) {
            @compileError("keyword arrays must have same length");
        }
    }
    inline for (keyword_strings, keyword_values) |str, val| {
        try lexerTable.put(str, Token{ .keyword = val });
        std.debug.print("DEBUG: Added keyword: {s}\n", .{str});
    }

    // Operators
    const operator_strings = [_][]const u8{ "and", "or", "+", "-", "*", "/", "%", "=", "==", "!=", "<", ">", "<=", ">=", "!", "~", "&", "|", "^", "<<", ">>", "..", "...", "@", "." };
    const operator_values = [_]Operator{ .@"and", .@"or", .@"+", .@"-", .@"*", .@"/", .@"%", .@"=", .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=", .@"!", .@"~", .@"&", .@"|", .@"^", .@"<<", .@">>", .@"..", .@"...", .@"@", .@"." };
    comptime {
        if (operator_strings.len != operator_values.len) {
            @compileError("operator arrays must have same length");
        }
    }
    inline for (operator_strings, operator_values) |str, val| {
        try lexerTable.put(str, Token{ .operator = val });
        std.debug.print("DEBUG: Added operator: {s}\n", .{str});
    }

    // Punctuation
    const punctuation_strings = [_][]const u8{ "\"", ",", "[", "]", "(", ")", ":" };
    const punctuation_values = [_]Punctuation{ .@"\"", .@",", .@"[", .@"]", .@"(", .@")", .@":" };
    comptime {
        if (punctuation_strings.len != punctuation_values.len) {
            @compileError("punctuation arrays must have same length");
        }
    }
    inline for (punctuation_strings, punctuation_values) |str, val| {
        try lexerTable.put(str, Token{ .punctuation = val });
        std.debug.print("DEBUG: Added punctuation: {s}\n", .{str});
    }

    // Build the lookup table
    var lookupTable = std.ArrayList(Lookup).init(allocator);

    var it = lexerTable.iterator();
    var longest: usize = 0;
    while (it.next()) |entry| {
        try lookupTable.append(Lookup{ .string = entry.key_ptr.*, .token = entry.value_ptr.* });
        if (entry.key_ptr.*.len > longest) {
            longest = entry.key_ptr.*.len;
        }
    }
    std.debug.print("DEBUG: Lookup table built with {d} entries, longest entry: {d}\n", .{ lookupTable.items.len, longest });

    const Context = struct {
        pub fn lessThan(_: void, a: Lookup, b: Lookup) bool {
            return Lookup.compare(a, b) == .lt;
        }
    };
    std.mem.sort(Lookup, lookupTable.items, {}, Context.lessThan);
    std.debug.print("DEBUG: Lookup table sorted\n", .{});

    // Print all entries in the lookup table for debugging
    std.debug.print("DEBUG: --- Lookup Table Contents ---\n", .{});
    for (lookupTable.items, 0..) |item, i| {
        std.debug.print("DEBUG: [{d}] string: '{s}'\n", .{ i, item.string });
    }
    std.debug.print("DEBUG: --- End of Lookup Table ---\n", .{});

    return LookupTable{ .list = lookupTable, .longest = longest };
}

pub const State = packed struct {
    string: bool,
    identifier: bool,
    index: u64,
    identifier_start: u64,
};

pub const TokenList = struct {
    list: std.ArrayList(Token),
    allocator: std.mem.Allocator,
    pub fn deinit(self: *TokenList) void {
        for (self.list.items) |*token| {
            token.deinit(self.allocator);
        }
        self.list.deinit();
    }
};

pub fn lexer(allocator: std.mem.Allocator, source: []const u8) !TokenList {
    std.debug.print("DEBUG: Starting lexer on source of length {d}\n", .{source.len});
    var list = std.ArrayList(Token).init(allocator);
    errdefer {
        // Free any allocated token memories before freeing the ArrayList
        for (list.items) |*token| {
            token.deinit(allocator);
        }
        list.deinit();
    }

    // Create a stack to store indices
    var stack = std.ArrayList(State).init(allocator);
    defer stack.deinit();

    var state = State{ .string = false, .identifier = false, .index = 0, .identifier_start = 0 };
    std.debug.print("DEBUG: Building lookup table\n", .{});
    var lookupTable = try buildLookupTable(allocator);
    defer lookupTable.deinit();

    // Push initial index onto stack
    try stack.append(state);
    std.debug.print("DEBUG: Initial state pushed to stack\n", .{});

    // Process until stack is empty
    outer: while (stack.items.len > 0) {
        // Pop index from stack
        state = stack.pop().?;
        const index = state.index;
        var next = State{ .string = false, .identifier = false, .index = index + 1, .identifier_start = state.identifier_start };
        var same = State{ .string = false, .identifier = false, .index = index, .identifier_start = state.identifier_start };

        // Special handling for end of input with active identifier
        if (index >= source.len) {
            std.debug.print("DEBUG: Index {d} out of bounds\n", .{index});

            // If we're processing an identifier and reached the end, finalize it
            if (state.identifier) {
                std.debug.print("DEBUG: End of identifier/number at end of input, started at {d}\n", .{state.identifier_start});
                const token_text = source[state.identifier_start..source.len];
                std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                // Process identifier or number
                processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                    std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                    return err; // Propagate the error to trigger cleanup
                };
            }
            continue;
        }

        const c = source[index];
        std.debug.print("DEBUG: Processing index {d}, char '{c}' (string: {s}, identifier: {s})\n", .{ index, c, if (state.string) "true" else "false", if (state.identifier) "true" else "false" });

        // Check for comments (// sequence)
        if (c == '/' and index + 1 < source.len and source[index + 1] == '/') {
            std.debug.print("DEBUG: Found comment starting at {d}\n", .{index});

            // If we're in an identifier, finish it
            if (state.identifier) {
                std.debug.print("DEBUG: End of identifier before comment, started at {d}\n", .{state.identifier_start});
                const token_text = source[state.identifier_start..index];
                std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                // Process identifier or number
                processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                    std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                    return err; // Propagate the error to trigger cleanup
                };
            }

            // Find end of line or end of source
            var comment_end = index + 2;
            while (comment_end < source.len and source[comment_end] != '\n') {
                comment_end += 1;
            }

            // Create a comment token with the content
            const comment_text = try allocator.dupe(u8, source[index + 2 .. comment_end]);
            try list.append(Token{ .comment = comment_text });

            // If we reached a newline, add it as a token
            if (comment_end < source.len and source[comment_end] == '\n') {
                try list.append(.newline);
                comment_end += 1;
            }

            // Continue processing after the comment
            var post = state;
            post.identifier = false;
            post.string = false;
            post.index = comment_end;
            try stack.append(post);
            continue;
        }

        // First check for technical symbols
        switch (c) {
            ' ' => {
                // If we're in an identifier, finish it
                if (state.identifier) {
                    std.debug.print("DEBUG: End of identifier/number on space, started at {d}\n", .{state.identifier_start});
                    const token_text = source[state.identifier_start..index];
                    std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                    // Process identifier or number
                    processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                        std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                        return err; // Propagate the error to trigger cleanup
                    };
                }

                std.debug.print("DEBUG: Found space\n", .{});
                // Skip space, push next index
                try list.append(.space);
                try stack.append(next);
                continue;
            },
            // TABS ONLY
            '\t' => {
                // If we're in an identifier, finish it
                if (state.identifier) {
                    std.debug.print("DEBUG: End of identifier/number on tab, started at {d}\n", .{state.identifier_start});
                    const token_text = source[state.identifier_start..index];
                    std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                    // Process identifier or number
                    processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                        std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                        return err; // Propagate the error to trigger cleanup
                    };
                }

                std.debug.print("DEBUG: Found tab, adding indent token\n", .{});
                try list.append(.indent);
                // Push next index
                try stack.append(next);
                continue;
            },
            '\n' => {
                // If we're in an identifier, finish it
                if (state.identifier) {
                    std.debug.print("DEBUG: End of identifier/number on newline, started at {d}\n", .{state.identifier_start});
                    const token_text = source[state.identifier_start..index];
                    std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                    // Process identifier or number
                    processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                        std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                        return err; // Propagate the error to trigger cleanup
                    };
                }

                std.debug.print("DEBUG: Found newline, adding newline token\n", .{});
                try list.append(.newline);
                // Push next index
                try stack.append(next);
                continue;
            },
            else => {},
        }

        // Check the lookup table for predefined tokens
        std.debug.print("DEBUG: Checking tokens at index {d}, char '{c}'\n", .{ index, source[index] });

        // If we're in an identifier and the current character isn't part of the identifier,
        // finish the identifier before processing the current character
        if (state.identifier) {
            var is_valid_ident_char = std.ascii.isAlphanumeric(c);
            if (!is_valid_ident_char) {
                is_valid_ident_char = (c == '_');
            }

            // In this approach, we'll completely avoid checking for tokens within identifiers
            // We'll just process identifiers character by character until we hit a non-identifier character
            if (!is_valid_ident_char) {
                // Not a valid identifier character, so end the identifier here
                std.debug.print("DEBUG: End of identifier, found non-identifier char, started at {d}\n", .{state.identifier_start});
                const token_text = source[state.identifier_start..index];
                std.debug.print("DEBUG: Token text: '{s}', length: {d}\n", .{ token_text, token_text.len });

                // Process identifier or number
                processIdentifierOrNumber(token_text, &list, allocator) catch |err| {
                    std.debug.print("DEBUG: Error processing identifier: {any}\n", .{err});
                    return err; // Propagate the error to trigger cleanup
                };

                // Reset identifier flag for current character processing
                same.identifier = false;
                next.identifier = false;

                // Process the current character
                try stack.append(same);
                continue;
            } else {
                // Continue collecting the identifier
                next.identifier = true;
                try stack.append(next);
                continue;
            }
        }

        // Linear search through tokens from longest to shortest possible match
        var found_token = false;
        var token_len: usize = 0;
        var len_check: usize = lookupTable.longest;
        while (len_check > 0) : (len_check -= 1) {
            if (index + len_check > source.len) continue;

            const slice_to_check = source[index .. index + len_check];
            std.debug.print("DEBUG: Checking for token of length {d}: '{s}'\n", .{ len_check, slice_to_check });

            // Try to find an exact match in the lookup table
            for (lookupTable.list.items) |item| {
                if (std.mem.eql(u8, slice_to_check, item.string)) {
                    // For keywords, make sure they are standalone
                    if (std.meta.activeTag(item.token) == .keyword) {
                        const keyword_len = slice_to_check.len;

                        // Simple approach: only recognize keywords when they're:
                        // 1. Preceded by a space, newline, operator, or punctuation (or start of source)
                        // 2. Followed by a space, newline, operator, or punctuation (or end of source)

                        // Check if this is a standalone keyword
                        const prev_pos = if (index > 0) index - 1 else 0;
                        const prev_is_separator = (index == 0) or
                            (source[prev_pos] == ' ') or
                            (source[prev_pos] == '\n') or
                            (source[prev_pos] == '\t') or
                            isPunctuationOrOperator(source[prev_pos]);

                        const next_pos = index + keyword_len;
                        const next_is_separator = (next_pos >= source.len) or
                            (source[next_pos] == ' ') or
                            (source[next_pos] == '\n') or
                            (source[next_pos] == '\t') or
                            isPunctuationOrOperator(source[next_pos]);

                        // If not a standalone keyword, skip it
                        if (!prev_is_separator or !next_is_separator) {
                            // Before skipping, check if we should be in identifier mode
                            if (index == 0 or !std.ascii.isAlphanumeric(source[index]) and source[index] != '_') {
                                // Not the start of an identifier either, so keep looking for tokens
                                continue;
                            } else {
                                // This should actually be treated as an identifier
                                same.identifier = true;
                                same.identifier_start = index;
                                try stack.append(same);
                                continue :outer;
                            }
                        }
                    }

                    found_token = true;
                    token_len = len_check;
                    const token = item.token;
                    std.debug.print("DEBUG: Found exact token match '{s}' at index {d}\n", .{ item.string, index });

                    // Special handling for quote - start of string literal
                    if (token == .punctuation and token.punctuation == .@"\"") {
                        std.debug.print("DEBUG: Starting string literal processing\n", .{});
                        // Push a special marker on the stack to process the string content
                        same.string = true;
                        try stack.append(same);
                        continue :outer;
                    }

                    // Push the index after this token
                    var post = same;
                    post.index += @intCast(token_len);
                    try stack.append(post);
                    try list.append(token);
                    std.debug.print("DEBUG: Added token, moving to index {d}\n", .{post.index});
                    continue :outer;
                }
            }

            // If we found a token of this length, break out
            if (found_token) break;
        }

        if (!found_token) {
            std.debug.print("DEBUG: No token found, checking for identifiers or literals\n", .{});
        }

        // Check if we're processing a string (bit 63 set in the index)
        if (state.string) {
            std.debug.print("DEBUG: Processing string at index {d}\n", .{index});

            // Check if current character is a closing quote
            if (c == '"') {
                std.debug.print("DEBUG: Found closing quote\n", .{});
                // String ended, extract the content
                const string_content = source[index + 1 .. index];
                std.debug.print("DEBUG: String content: '{s}'\n", .{string_content});
                // Create a string literal token
                if (string_content.len > 0) {
                    const duped_content = try allocator.dupe(u8, string_content);
                    errdefer allocator.free(duped_content);
                    try list.append(Token{ .literal = Value{ .string = duped_content } });
                } else {
                    // Handle empty string case
                    try list.append(Token{ .literal = Value{ .string = "" } });
                }
                // Continue after the closing quote
                try stack.append(next);
                continue;
            } else if (index >= source.len - 1) {
                std.debug.print("DEBUG: Reached end of source without closing quote\n", .{});
                // Reached end of source without closing quote
                // Handle error or just create a partial string
                const string_content = source[index + 1 .. source.len];
                std.debug.print("DEBUG: Partial string: '{s}'\n", .{string_content});
                if (string_content.len > 0) {
                    const duped_content = try allocator.dupe(u8, string_content);
                    errdefer allocator.free(duped_content);
                    try list.append(Token{ .literal = Value{ .string = duped_content } });
                } else {
                    // Handle empty string case
                    try list.append(Token{ .literal = Value{ .string = "" } });
                }
                continue;
            } else {
                std.debug.print("DEBUG: Continuing string collection\n", .{});
                // Keep processing string: push next char with string marker
                next.string = true;
                try stack.append(next);
                continue;
            }
        }

        // Handle identifiers and numbers using the stack approach
        if (std.ascii.isAlphanumeric(c)) {
            std.debug.print("DEBUG: Starting identifier/number at index {d}, char '{c}'\n", .{ index, c });
            // Push a marker to process identifier/number
            next.identifier = true;
            next.identifier_start = index; // Set the start position here
            try stack.append(next);
            continue;
        }

        std.debug.print("DEBUG: No special handling for char '{c}', moving to next char\n", .{c});
        // Otherwise, just move to the next character
        try stack.append(next);
    }

    std.debug.print("DEBUG: Lexer completed, generated {d} tokens\n", .{list.items.len});
    return TokenList{ .list = list, .allocator = allocator };
}

// Helper function to determine if a character is part of punctuation or operator
fn isPunctuationOrOperator(c: u8) bool {
    return switch (c) {
        ',', '[', ']', '(', ')', ':', '.', '+', '-', '*', '/', '%', '=', '!', '&', '|', '^', '<', '>', '~', '@' => true,
        else => false,
    };
}

/// Helper function to process identifier or number token
fn processIdentifierOrNumber(token_text: []const u8, tokens: *std.ArrayList(Token), allocator: std.mem.Allocator) !void {
    if (token_text.len == 0) return;

    errdefer {
        // On error, ensure the last token is properly cleaned up if it was added
        if (tokens.items.len > 0) {
            var last_token = &tokens.items[tokens.items.len - 1];
            last_token.deinit(allocator);
            _ = tokens.pop();
        }
    }

    // Analyze if it's a number
    var is_number = true;
    var has_decimal = false;

    for (token_text, 0..) |char, i| {
        if (char == '.' and !has_decimal) {
            has_decimal = true;
            // Invalid if at start/end or not followed by digit
            if (i == 0) {
                is_number = false;
                break;
            }
            if (i == token_text.len - 1) {
                is_number = false;
                break;
            }
            if (!std.ascii.isDigit(token_text[i + 1])) {
                is_number = false;
                break;
            }
        } else if (!std.ascii.isDigit(char)) {
            is_number = false;
            break;
        }
    }

    if (is_number and token_text.len > 0 and std.ascii.isDigit(token_text[0])) {
        // It's a number
        if (has_decimal) {
            std.debug.print("DEBUG: Processing as floating point number: '{s}'\n", .{token_text});
            const num = try std.fmt.parseFloat(f32, token_text);
            std.debug.print("DEBUG: Parsed float: {d}\n", .{num});
            try tokens.append(Token{ .literal = Value{ .real = num } });
        } else {
            std.debug.print("DEBUG: Processing as integer: '{s}'\n", .{token_text});
            const num = try std.fmt.parseInt(u64, token_text, 10);
            std.debug.print("DEBUG: Parsed integer: {d}\n", .{num});
            try tokens.append(Token{ .literal = Value{ .scalar = num } });
        }
    } else {
        std.debug.print("DEBUG: Processing as identifier: '{s}'\n", .{token_text});
        // It's an identifier
        if (token_text.len > 0) {
            const duped_text = try allocator.dupe(u8, token_text);
            errdefer allocator.free(duped_text);
            try tokens.append(Token{ .identifier = duped_text });
        } else {
            // Empty identifier case - should rarely happen but handle it anyway
            try tokens.append(Token{ .identifier = "" });
        }
    }
}
