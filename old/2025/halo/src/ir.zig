const std = @import("std");
const Allocator = std.mem.Allocator;
const Token = @import("lexer.zig").Token;

pub const Compound = struct {
    operator: Operator,
    base: Operator,
    modifier: Operator,
};
const COMPOUND_OPERATORS = [_]Compound{
    .{ .operator = .add_assign, .base = Operator.add, .modifier = Operator.assign },
    .{ .operator = .sub_assign, .base = Operator.sub, .modifier = Operator.assign },
    .{ .operator = .mul_assign, .base = Operator.mul, .modifier = Operator.assign },
    .{ .operator = .div_assign, .base = Operator.div, .modifier = Operator.assign },
    .{ .operator = .mod_assign, .base = Operator.mod, .modifier = Operator.assign },
    .{ .operator = .shl_assign, .base = Operator.shl, .modifier = Operator.assign },
    .{ .operator = .shr_assign, .base = Operator.shr, .modifier = Operator.assign },
    .{ .operator = .and_assign, .base = Operator.@"and", .modifier = Operator.assign },
    .{ .operator = .or_assign, .base = Operator.@"or", .modifier = Operator.assign },
    .{ .operator = .xor_assign, .base = Operator.xor, .modifier = Operator.assign },
    .{ .operator = .not_equal, .base = Operator.not, .modifier = Operator.assign },
    .{ .operator = .greater_than_or_equal, .base = Operator.greater, .modifier = Operator.assign },
    .{ .operator = .less_than_or_equal, .base = Operator.less, .modifier = Operator.assign },
    .{ .operator = .equal, .base = Operator.assign, .modifier = Operator.assign },
    .{ .operator = .not_equal, .base = Operator.not, .modifier = Operator.assign },
    .{ .operator = .shift_left, .base = Operator.less, .modifier = Operator.less },
    .{ .operator = .shift_right, .base = Operator.greater, .modifier = Operator.greater },
    .{ .operator = .shift_left_assign, .base = Operator.shift_left, .modifier = Operator.assign },
    .{ .operator = .shift_right_assign, .base = Operator.shift_right, .modifier = Operator.assign },
    .{ .operator = .range, .base = Operator.dot, .modifier = Operator.dot },
    .{ .operator = .spread, .base = Operator.range, .modifier = Operator.dot },
};

pub fn detectCompoundOperator(last: Operator, current: Operator) ?Operator {
    for (COMPOUND_OPERATORS) |compound| {
        if (compound.base == last and compound.modifier == current) {
            return compound.operator;
        }
    }
    return null;
}

pub const Ir = union(enum) {
    scalar: u64,
    real: f64,
    string: []const u8,
    identifier: []const u8,
    operator: Operator,
    block_start: BlockType,
    block_end: BlockType,
    flow_control: FlowControl,
    define: void,
    call: void,
    parameter: *Ir,
    expression: []*Ir,

    pub const BlockType = enum {
        if_block,
        else_block,
        while_block,
        for_block,
        loop_block,
        function_block,
        general_block,
        tail_block,
        array_index_block,
    };

    pub const FlowControl = enum {
        break_stmt,
        continue_stmt,
        return_stmt,
    };

    pub fn format(self: Ir, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;

        switch (self) {
            .scalar => |value| try writer.print("scalar({d})", .{value}),
            .real => |value| try writer.print("real({d})", .{value}),
            .string => |value| try writer.print("string(\"{s}\")", .{value}),
            .identifier => |value| try writer.print("identifier({s})", .{value}),
            .operator => |value| try writer.print("operator({s})", .{@tagName(value)}),
            .block_start => |value| try writer.print("block_start({s})", .{@tagName(value)}),
            .block_end => |value| try writer.print("block_end({s})", .{@tagName(value)}),
            .flow_control => |value| try writer.print("flow_control({s})", .{@tagName(value)}),
            .define => try writer.writeAll("define"),
            .call => try writer.writeAll("call"),
            .parameter => |value| {
                try writer.writeAll("parameter(");
                try format(value.*, "", options, writer);
                try writer.writeAll(")");
            },
            .expression => |value| {
                try writer.writeAll("expression[");
                if (value.len > 0) {
                    for (value, 0..) |expr, i| {
                        if (i > 0) try writer.writeAll(", ");
                        try format(expr.*, "", options, writer);
                    }
                }
                try writer.writeAll("]");
            },
        }
    }
};

pub const Operator = enum {
    addr, // &
    @"and", // &
    @"or", // |
    input, // |
    xor, // ^
    not, // ~
    add, // +
    sub, // -
    mul, // *
    ptr,
    deref, // *
    spread, // ...
    assign, // =
    div, // /
    mod, // %
    land, // and
    lor, // or
    lxor, // xor
    lnot, // not
    @"fn",
    @"if", // if
    @"else", // else
    loop, // loop
    @"defer", // defer
    global, // @
    instruction,
    end,
    dot, // .
    comma, // ,
    flow,
    arrow, // ->
    add_assign,
    sub_assign,
    mul_assign,
    div_assign,
    mod_assign,
    shl_assign,
    shr_assign,
    and_assign,
    or_assign,
    xor_assign,
    not_equal,
    equal,
    range,
    shl,
    shr,
    greater,
    less,
    greater_than_or_equal,
    less_than_or_equal,
    shift_left,
    shift_right,
    shift_left_assign,
    shift_right_assign,

    pub fn hash(self: Operator) u64 {
        var hasher = std.hash.Wyhash.init(0);
        std.hash.autoHash(&hasher, @intFromEnum(self));
        return hasher.final();
    }

    pub fn eql(self: Operator, other: Operator) bool {
        return @intFromEnum(self) == @intFromEnum(other);
    }
};

pub fn contextualOp(lastToken: Token, nextToken: Token, op: Operator) Operator {
    std.debug.print("lastToken: {any}, nextToken: {any}, op: {any}\n", .{ lastToken, nextToken, op });
    if ((lastToken == .space or lastToken == .punctuation and lastToken.punctuation == .@"(") and op == Operator.mul) {
        return Operator.ptr;
    }
    if (lastToken == .symbol and lastToken.symbol == .@"." and op == Operator.mul) {
        return Operator.deref;
    }
    if (op == .@"and" and nextToken != .space) {
        return Operator.addr;
    }

    return op;
}

pub const ExpressError = error{
    OutOfMemory,
    InvalidExpression,
    UnexpectedToken,
    InvalidWhitespace,
    Complete,
};

pub const WhitespaceRule = enum { required, forbidden };

var whitespace_rules: ?WhitespaceRuleTable = undefined;
pub const WhitespaceRuleTable = struct {
    const LexerToken = @import("lexer.zig").Token;
    const IrOperator = @import("ir.zig").Operator;
    rules: std.AutoHashMap(TokenPair, WhitespaceRule),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !WhitespaceRuleTable {
        var rules = std.AutoHashMap(TokenPair, WhitespaceRule).init(allocator);

        // Core space rules
        try rules.put(.{ .first = .space, .second = .space }, .forbidden);
        try rules.put(.{ .first = .newline, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .newline }, .forbidden);
        try rules.put(.{ .first = .indent, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .indent }, .forbidden);
        try rules.put(.{ .first = .space, .second = .literal }, .required);
        try rules.put(.{ .first = .{ .punctuation = .@":" }, .second = .space }, .required);
        try rules.put(.{ .first = .space, .second = .{ .punctuation = .@":" } }, .required);

        // Rules for operators and spaces
        try rules.put(.{ .first = .{ .operator = .assign }, .second = .space }, .required);
        try rules.put(.{ .first = .space, .second = .{ .operator = .add_assign } }, .required);
        try rules.put(.{ .first = .space, .second = .{ .operator = .assign } }, .required);
        try rules.put(.{ .first = .{ .operator = .dot }, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .{ .operator = .dot } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .ptr }, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .{ .operator = .ptr } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .deref }, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .{ .operator = .deref } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .global }, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .{ .operator = .global } }, .required);

        // Rules for basic operators that require spaces
        const spaced_operators = [_]Operator{
            .add,    .sub,                   .mul,                .div,        .mod,
            .@"and", .@"or",                 .not,                .land,       .lor,
            .lxor,   .lnot,                  .equal,              .not_equal,  .greater,
            .less,   .greater_than_or_equal, .less_than_or_equal, .shift_left, .shift_right,
        };

        inline for (spaced_operators) |op| {
            try rules.put(.{ .first = .{ .operator = op }, .second = .space }, .required);
            try rules.put(.{ .first = .space, .second = .{ .operator = op } }, .required);
        }

        // Continue with existing rules...
        // Space transition rules
        try rules.put(.{ .first = .space, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .identifier }, .required);
        try rules.put(.{ .first = .identifier, .second = .space }, .required);
        try rules.put(.{ .first = .keyword, .second = .space }, .required);
        try rules.put(.{ .first = .literal, .second = .space }, .required);
        try rules.put(.{ .first = .space, .second = .newline }, .forbidden);
        try rules.put(.{ .first = .newline, .second = .space }, .forbidden);
        try rules.put(.{ .first = .indent, .second = .space }, .forbidden);
        try rules.put(.{ .first = .space, .second = .indent }, .forbidden);
        try rules.put(.{ .first = .{ .punctuation = .@"," }, .second = .space }, .required); // After comma we need space
        try rules.put(.{ .first = .{ .punctuation = .@")" }, .second = .space }, .required); // After closing paren we need space
        try rules.put(.{ .first = .{ .punctuation = .@"]" }, .second = .space }, .required); // After closing bracket we need space
        try rules.put(.{ .first = .space, .second = .{ .punctuation = .@"," } }, .forbidden); // No space before comma
        try rules.put(.{ .first = .space, .second = .{ .punctuation = .@")" } }, .forbidden); // No space before closing paren
        try rules.put(.{ .first = .space, .second = .{ .punctuation = .@"]" } }, .forbidden); // No space before closing bracket
        try rules.put(.{ .first = .space, .second = .{ .operator = .addr } }, .required); // No space before closing bracket

        // Rules for tokens that require space after them
        try rules.put(.{ .first = .identifier, .second = .identifier }, .required);
        try rules.put(.{ .first = .identifier, .second = .keyword }, .required);
        try rules.put(.{ .first = .keyword, .second = .identifier }, .required);
        try rules.put(.{ .first = .literal, .second = .identifier }, .required);
        try rules.put(.{ .first = .literal, .second = .literal }, .required);

        // Keywords need spaces after them except when followed by special punctuation
        try rules.put(.{ .first = .keyword, .second = .identifier }, .required);
        try rules.put(.{ .first = .keyword, .second = .{ .punctuation = .@"(" } }, .forbidden);
        try rules.put(.{ .first = .keyword, .second = .{ .operator = .mul } }, .forbidden); // fn *T
        try rules.put(.{ .first = .keyword, .second = .literal }, .required);

        // Identifiers
        try rules.put(.{ .first = .identifier, .second = .identifier }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .dot } }, .forbidden); // Changed from punctuation to operator
        try rules.put(.{ .first = .{ .operator = .dot }, .second = .identifier }, .forbidden); // Changed from punctuation to operator
        try rules.put(.{ .first = .identifier, .second = .{ .punctuation = .@"(" } }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .{ .punctuation = .@"[" } }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .literal }, .required);

        // Binary operators need spaces on both sides
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .add } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .sub } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .mul } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .div } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .mod } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .@"and" } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .@"or" } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .xor } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .land } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .lor } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .lxor } }, .required);

        // Special operators (no spaces)
        try rules.put(.{ .first = .{ .operator = .dot }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .dot }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .dot } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .dot }, .second = .{ .operator = .dot } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .ptr }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .deref }, .second = .identifier }, .forbidden);

        // Compound operators
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .shift_left } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .shift_right } }, .required);
        try rules.put(.{ .first = .{ .operator = .shift_left }, .second = .identifier }, .required);
        try rules.put(.{ .first = .{ .operator = .shift_right }, .second = .identifier }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .add_assign } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .sub_assign } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .mul_assign } }, .required);

        // Assignment operators
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .assign } }, .required);
        try rules.put(.{ .first = .{ .operator = .assign }, .second = .identifier }, .required);
        try rules.put(.{ .first = .{ .operator = .assign }, .second = .literal }, .required);

        // Comparison operators
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .equal } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .not_equal } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .greater } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .less } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .greater_than_or_equal } }, .required);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .less_than_or_equal } }, .required);

        // Special @ keywords
        try rules.put(.{ .first = .{ .operator = .global }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .{ .operator = .global } }, .forbidden);

        // Function calls and array indexing
        try rules.put(.{ .first = .{ .punctuation = .@"(" }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .{ .punctuation = .@"[" }, .second = .identifier }, .forbidden);
        try rules.put(.{ .first = .{ .punctuation = .@"(" }, .second = .{ .operator = .ptr } }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .{ .punctuation = .@")" } }, .forbidden);
        try rules.put(.{ .first = .identifier, .second = .{ .punctuation = .@"]" } }, .forbidden);

        // Comma rules
        try rules.put(.{ .first = .identifier, .second = .{ .punctuation = .@"," } }, .forbidden);
        try rules.put(.{ .first = .{ .punctuation = .@"," }, .second = .identifier }, .required);
        try rules.put(.{ .first = .{ .punctuation = .@"," }, .second = .literal }, .required);

        // Literal rules
        try rules.put(.{ .first = .literal, .second = .identifier }, .required);
        try rules.put(.{ .first = .literal, .second = .{ .operator = .add } }, .required);
        try rules.put(.{ .first = .literal, .second = .{ .operator = .sub } }, .required);
        try rules.put(.{ .first = .literal, .second = .{ .operator = .mul } }, .required);
        try rules.put(.{ .first = .literal, .second = .{ .punctuation = .@"," } }, .forbidden);

        // Flow control
        try rules.put(.{ .first = .{ .operator = .@"if" }, .second = .identifier }, .required);
        try rules.put(.{ .first = .{ .operator = .@"else" }, .second = .identifier }, .required);
        try rules.put(.{ .first = .{ .operator = .loop }, .second = .identifier }, .required);

        // Special cases for spacing around blocks
        try rules.put(.{ .first = .{ .operator = .@"if" }, .second = .{ .punctuation = .@"(" } }, .forbidden);
        try rules.put(.{ .first = .{ .operator = .loop }, .second = .{ .punctuation = .@"(" } }, .forbidden);

        return .{ .rules = rules, .allocator = allocator };
    }

    pub const TokenType = union(enum) {
        identifier,
        keyword,
        operator: Operator,
        punctuation: @import("lexer.zig").Punctuation,
        literal,
        space,
        newline,
        indent,
    };

    pub fn getRule(self: *const WhitespaceRuleTable, surrounding: [7]LexerToken) WhitespaceRule {
        const tokenTypes = [_]TokenType{
            tokenToTokenType(surrounding, 1),
            tokenToTokenType(surrounding, 2),
        };
        std.debug.print("surrounding: {any}, tokenTypes: {any}\n", .{ surrounding, tokenTypes });

        const pair = TokenPair{ .first = tokenTypes[0], .second = tokenTypes[1] };

        if (self.rules.get(pair)) |rule| {
            std.debug.print("Found rule for pair: {any} -> {s}\n", .{ pair, @tagName(rule) });
            return rule;
        } else {
            std.debug.print("No rule found for pair: {any}, defaulting to forbidden\n", .{pair});
            return .forbidden;
        }
    }

    fn tokenToTokenType(surrounding: [7]Token, start: usize) TokenType {
        var currentOp: ?Operator = undefined;
        var consumedTokens: usize = 1;
        const middle = 2;
        if (surrounding[middle] == .symbol) {
            currentOp = convertLexerSymbol(surrounding[middle].symbol);
            const tokens = [_]LexerToken{
                surrounding[middle - 1],
                surrounding[middle],
                surrounding[middle + 1],
                surrounding[middle + 2],
                surrounding[middle + 3],
            };
            var lookAheadIdx = start;
            while (lookAheadIdx < tokens.len - 1) {
                lookAheadIdx += 1;
                const nextSymbol = tokens[lookAheadIdx];
                if (nextSymbol != .symbol) break;

                const nextOp = convertLexerSymbol(nextSymbol.symbol);

                if (detectCompoundOperator(currentOp.?, nextOp)) |compound| {
                    currentOp = compound;
                    consumedTokens += 1;
                    std.debug.print("Found multi-symbol compound: {s}, consuming {d} tokens\n", .{ @tagName(currentOp.?), consumedTokens });
                } else {
                    break; // No more compounds possible
                }
            }
        }

        return switch (surrounding[start]) {
            .identifier => .identifier,
            .keyword => .keyword,
            .comment => .newline,
            .symbol => |_| {
                if (consumedTokens == 1) {
                    return .{ .operator = contextualOp(surrounding[start - 1], surrounding[start + 1], currentOp.?) };
                } else {
                    return .{ .operator = currentOp.? };
                }
            },
            .punctuation => |p| .{ .punctuation = p },
            .literal => .literal,
            .space => .space,
            .newline => .newline,
            .indent => .indent,
        };
    }

    fn defaultRule(second: LexerToken) WhitespaceRule {
        // Default rules when no specific rule exists
        return switch (second) {
            .identifier => .required,
            .symbol => .forbidden,
            .punctuation => .forbidden,
            .literal => .required,
            else => .required,
        };
    }

    pub const TokenPair = struct {
        first: TokenType,
        second: TokenType,

        pub fn hash(self: TokenPair) u64 {
            var hasher = std.hash.Wyhash.init(0);

            // Hash the tag of each TokenType first
            const first_tag = std.meta.activeTag(self.first);
            const second_tag = std.meta.activeTag(self.second);

            std.hash.autoHash(&hasher, @intFromEnum(first_tag));
            std.hash.autoHash(&hasher, @intFromEnum(second_tag));

            // Hash the payload if present
            switch (self.first) {
                .operator => |op| std.hash.autoHash(&hasher, @intFromEnum(op)),
                .punctuation => |p| std.hash.autoHash(&hasher, @intFromEnum(p)),
                .literal => |l| std.hash.autoHash(&hasher, @intFromEnum(l)),
                else => {},
            }

            switch (self.second) {
                .operator => |op| std.hash.autoHash(&hasher, @intFromEnum(op)),
                .punctuation => |p| std.hash.autoHash(&hasher, @intFromEnum(p)),
                .literal => |l| std.hash.autoHash(&hasher, @intFromEnum(l)),
                else => {},
            }

            return hasher.final();
        }

        pub fn eql(self: TokenPair, other: TokenPair) bool {
            if (@as(@TypeOf(std.meta.activeTag(self.first)), std.meta.activeTag(self.first)) != std.meta.activeTag(other.first)) return false;
            if (@as(@TypeOf(std.meta.activeTag(self.second)), std.meta.activeTag(self.second)) != std.meta.activeTag(other.second)) return false;

            return switch (self.first) {
                .operator => |op| op == other.first.operator,
                .punctuation => |p| p == other.first.punctuation,
                .literal => |l| l == other.first.literal,
                else => true,
            } and switch (self.second) {
                .operator => |op| op == other.second.operator,
                .punctuation => |p| p == other.second.punctuation,
                .literal => |l| l == other.second.literal,
                else => true,
            };
        }
    };

    pub fn initWhitespaceRules(allocator: std.mem.Allocator) !void {
        whitespace_rules = try WhitespaceRuleTable.init(allocator);
    }

    pub fn deinitWhitespaceRules() void {
        whitespace_rules.deinit();
    }

    pub fn needsWhitespace(surrounding: [7]LexerToken) !bool {
        if (whitespace_rules == null) {
            try WhitespaceRuleTable.initWhitespaceRules(std.heap.page_allocator);
        }
        return whitespace_rules.?.getRule(surrounding) == .required;
    }
};

const TokenIterator = struct {
    tokens: []Token,
    index: usize = 0,

    pub fn init(tokens: []Token) TokenIterator {
        return .{ .tokens = tokens };
    }

    pub fn peek(self: *TokenIterator) ?Token {
        if (self.index < self.tokens.len) {
            return self.tokens[self.index];
        }
        return null;
    }

    pub fn next(self: *TokenIterator) ?Token {
        const token = self.peek();
        if (token != null) self.index += 1;
        return token;
    }
};

pub fn convertLexerSymbol(lexer_op: @import("lexer.zig").Symbol) Operator {
    return switch (lexer_op) {
        .@"." => .dot,
        .@"+" => .add,
        .@"-" => .sub,
        .@"*" => .mul,
        .@"/" => .div,
        .@"%" => .mod,
        .@"=" => .assign,
        .@"<" => .less,
        .@">" => .greater,
        .@"!" => .lnot,
        .@"~" => .not,
        .@"&" => .@"and",
        .@"|" => .@"or",
        .@"^" => .xor,
        .@"@" => .global,
        .@"and" => .land,
        .@"or" => .lor,
    };
}
fn checkWhitespace(token_index: usize, tokens: []Token) ExpressError!void {
    if (token_index >= 2 and token_index < tokens.len - 2) {
        const tokenStart = token_index - 2;
        const considered = [7]Token{
            tokens[tokenStart],
            tokens[tokenStart + 1],
            tokens[tokenStart + 2],
            if (token_index + 1 < tokens.len) tokens[tokenStart + 3] else .newline,
            if (token_index + 2 < tokens.len) tokens[tokenStart + 4] else .newline,
            if (token_index + 3 < tokens.len) tokens[tokenStart + 5] else .newline,
            if (token_index + 4 < tokens.len) tokens[tokenStart + 6] else .newline,
        };

        const needs_space = try WhitespaceRuleTable.needsWhitespace(considered);
        // Check for space in the correct position - between tokens[1] and tokens[3]
        const has_space = (considered[1] == .space) != (considered[2] == .space);

        std.debug.print("considered: {any}, needs_space: {}, has_space: {}\n", .{ considered, needs_space, has_space });

        // Error if we need a space but don't have one, or if we have a space but it's forbidden
        // Special case: Don't enforce space rules when we see end of input or newline
        if (needs_space != has_space and considered[2] != .newline) {
            return ExpressError.InvalidWhitespace;
        }
    }
}
pub fn express(allocator: Allocator, tokens: []Token) ExpressError!std.ArrayList(Ir) {
    var token_iterator = TokenIterator.init(tokens);
    var ir_nodes = std.ArrayList(Ir).init(allocator);
    const Indent = struct {
        level: usize,
        parent: ?usize,
        block_type: Ir.BlockType,
    };
    var indent_stack = std.ArrayList(Indent).init(allocator);
    defer indent_stack.deinit();
    try indent_stack.append(.{ .level = 0, .parent = null, .block_type = .general_block });
    var pending_block_type = Ir.BlockType.general_block;

    var token = token_iterator.next();
    var current_indent: usize = 0;
    outer: while (token != null) {
        while (token != null and token.? == .indent) {
            current_indent += 1;
            token = token_iterator.next();
        }

        std.debug.print("token {any} current indent: {}\n", .{ token, current_indent });

        const previous_indent = indent_stack.items[indent_stack.items.len - 1].level;

        if (current_indent > previous_indent) {
            // Indentation increased - start a new block with pending block type
            try ir_nodes.append(.{ .block_start = pending_block_type });
            try indent_stack.append(.{
                .level = current_indent,
                .block_type = pending_block_type,
                .parent = indent_stack.items[indent_stack.items.len - 1].level,
            });
            // Reset pending block type after using it
            pending_block_type = .general_block;
        } else if (current_indent < previous_indent) {
            // Indentation decreased - end blocks
            while (indent_stack.items.len > 1 and indent_stack.items[indent_stack.items.len - 1].level > current_indent) {
                std.debug.print("yo{any}\n", .{indent_stack.items[indent_stack.items.len - 1].block_type});
                try ir_nodes.append(.{ .block_end = indent_stack.items[indent_stack.items.len - 1].block_type });
                _ = indent_stack.pop();
            }
        }

        if (token_iterator.index >= tokens.len)
            break;

        try checkWhitespace(token_iterator.index, tokens);

        blk: switch (token.?) {
            .indent => {
                //print random string
                continue :outer;
            },
            .comment => {
                token = token_iterator.next();
                continue :outer;
            },
            .newline => {
                current_indent = 0;
                token = token_iterator.next();
                //pop the tail from the stack if and only if it is a tail block
                if (indent_stack.items.len > 0 and indent_stack.items[indent_stack.items.len - 1].block_type == .tail_block) {
                    _ = indent_stack.pop();
                    try ir_nodes.append(.{ .block_end = .tail_block });
                }
                continue :outer;
            },
            .keyword => |kw| {
                switch (kw) {
                    .@"const" => {
                        try ir_nodes.append(.define);
                    },
                    .@"var" => {
                        try ir_nodes.append(.define);
                    },
                    .@"if" => {
                        try ir_nodes.append(.{ .operator = .@"if" });
                        pending_block_type = .if_block;
                    },
                    .@"else" => {
                        try ir_nodes.append(.{ .operator = .@"else" });
                        pending_block_type = .else_block;
                    },
                    .@"fn" => {
                        try ir_nodes.append(.define);
                        pending_block_type = .function_block;
                    },
                    .@"while" => {
                        try ir_nodes.append(.{ .operator = .loop });
                        pending_block_type = .while_block;
                    },
                    .@"for" => {
                        try ir_nodes.append(.{ .operator = .loop });
                        pending_block_type = .for_block;
                    },
                    .loop => {
                        try ir_nodes.append(.{ .operator = .loop });
                        pending_block_type = .loop_block;
                    },
                    .@"break" => {
                        try ir_nodes.append(.{ .flow_control = .break_stmt });
                    },
                    .@"continue" => {
                        try ir_nodes.append(.{ .flow_control = .continue_stmt });
                    },
                    else => {
                        unreachable;
                    },
                }
                try checkWhitespace(token_iterator.index, tokens);
                token = token_iterator.next();
                continue :blk token orelse break :outer;
            },
            .space => {
                try checkWhitespace(token_iterator.index, tokens);
                token = token_iterator.next();
                continue :blk token orelse break :outer;
            },
            .identifier => |id| {
                try checkWhitespace(token_iterator.index, tokens);
                try ir_nodes.append(.{ .identifier = id });
                token = token_iterator.next();
                continue :blk token orelse break :outer;
            },
            .symbol => |op_token| {
                const lastToken = if (token_iterator.index >= 1) tokens[token_iterator.index - 2] else .space;
                const nextToken = if (token_iterator.index < tokens.len) tokens[token_iterator.index] else .newline;
                // Store the raw operator without contextual modifications
                const rawOp = convertLexerSymbol(op_token);

                // Process consecutive symbols to build compound operators
                // Example: > followed by > should form shift_right
                var currentOp = rawOp;
                var consumedTokens: usize = 1;

                // Look ahead for additional symbols
                var lookAheadIdx = token_iterator.index - 1;
                while (lookAheadIdx < tokens.len - 1) {
                    lookAheadIdx += 1;
                    const nextSymbol = tokens[lookAheadIdx];
                    if (nextSymbol != .symbol) break;

                    const nextOp = convertLexerSymbol(nextSymbol.symbol);
                    std.debug.print("Testing compound: current={s}, next={s}\n", .{ @tagName(currentOp), @tagName(nextOp) });

                    if (detectCompoundOperator(currentOp, nextOp)) |compound| {
                        currentOp = compound;
                        consumedTokens += 1;
                        std.debug.print("Found multi-symbol compound: {s}, consuming {d} tokens\n", .{ @tagName(currentOp), consumedTokens });
                    } else {
                        break; // No more compounds possible
                    }
                }
                if (consumedTokens == 1) {
                    currentOp = contextualOp(lastToken, nextToken, currentOp);
                }

                // Add the operator (which might be a compound of consecutive symbols)
                try ir_nodes.append(.{ .operator = currentOp });

                // Skip all tokens that were part of this compound
                for (0..consumedTokens) |_| {
                    token = token_iterator.next();
                }
                continue :blk token orelse break :outer;
            },
            .punctuation => |punct| {
                switch (punct) {
                    .@"(" => {
                        try checkWhitespace(token_iterator.index, tokens);
                        if (pending_block_type == .function_block) {
                            try ir_nodes.append(.{ .operator = .@"fn" });
                        }
                    },
                    .@")" => {
                        try checkWhitespace(token_iterator.index, tokens);
                    },
                    .@"," => {
                        try checkWhitespace(token_iterator.index, tokens);
                        try ir_nodes.append(.{ .operator = .comma });
                    },
                    .@":" => {
                        try checkWhitespace(token_iterator.index, tokens);
                        try ir_nodes.append(.{ .block_start = .tail_block });
                        // Also add to the indent stack:
                        const parent_level = indent_stack.items[indent_stack.items.len - 1].level;

                        // Add to stack with correct nesting information
                        try indent_stack.append(.{
                            .level = parent_level + 1, // Make it one level deeper than parent
                            .block_type = .tail_block,
                            .parent = parent_level,
                        });
                    },
                    .@"[" => {
                        try checkWhitespace(token_iterator.index, tokens);
                        try ir_nodes.append(.{ .block_start = .array_index_block });
                        // Also add to the indent stack:
                        const parent_level = indent_stack.items[indent_stack.items.len - 1].level;

                        // Add to stack with correct nesting information
                        try indent_stack.append(.{
                            .level = parent_level + 1, // Make it one level deeper than parent
                            .block_type = .array_index_block,
                            .parent = parent_level,
                        });
                    },
                    .@"]" => {
                        try checkWhitespace(token_iterator.index, tokens);
                        if (indent_stack.items.len > 0 and indent_stack.items[indent_stack.items.len - 1].block_type == .array_index_block) {
                            _ = indent_stack.pop();
                            try ir_nodes.append(.{ .block_end = .array_index_block });
                        }
                    },
                    else => {
                        std.debug.print("punctuation {s}\n", .{@tagName(punct)});
                        unreachable;
                    },
                }
                try checkWhitespace(token_iterator.index, tokens);
                token = token_iterator.next();
                continue :blk token orelse break :outer;
            },
            .literal => |lit| {
                switch (lit) {
                    .scalar => |scalar| {
                        try checkWhitespace(token_iterator.index, tokens);
                        //convert scalar to string
                        try ir_nodes.append(.{ .scalar = scalar });
                    },
                    .real => |real| {
                        try checkWhitespace(token_iterator.index, tokens);
                        //convert real to string
                        try ir_nodes.append(.{ .real = real });
                    },
                    else => {
                        unreachable;
                    },
                }
                token = token_iterator.next();
                continue :blk token orelse break :outer;
            },
        }
    }

    // Create a temporary array to reverse the order of block endings
    var temp_endings = std.ArrayList(Ir.BlockType).init(allocator);
    defer temp_endings.deinit();

    // Collect all block types in reverse order
    while (indent_stack.items.len > 1) {
        const popped = indent_stack.pop();
        try temp_endings.append(popped.?.block_type);
    }

    // Append block_end in the correct order
    for (temp_endings.items) |block_type| {
        try ir_nodes.append(.{ .block_end = block_type });
    }

    return ir_nodes;
}
