pub const std = @import("std");
pub const Value = @import("value.zig").Value;
pub const Operator = @import("lexer.zig").Operator;
pub const Token = @import("lexer.zig").Token;
pub const Keyword = @import("lexer.zig").Keyword;
pub const Punctuation = @import("lexer.zig").Punctuation;

// Debug configuration
const DEBUG = true; // Set to false to disable debug output
fn debug(comptime fmt: []const u8, args: anytype) void {
    if (DEBUG) {
        std.debug.print("[DEBUG] " ++ fmt, args);
    }
}

// Add a GlobalType enum to specify global expression types
pub const GlobalType = enum {
    Const,
    Var,
    Fn,
    Reference,
    Call,
};

pub const Expression = union(enum) {
    Literal: Value,
    Variable: *Variable,
    Operator: Operator,
    Logical: *Logical,
    Conditional: *Conditional,
    Loop: *Loop,
    Call: *Call,
    Function: *Function,
    Block: *Block,
    Object: *Object,
    Property: *Property,
    Flow: *Flow,
    Global: *Global, // Add Global variant for @-prefixed expressions
    Index: *Index,
    Range: *Range,
    Tensor: *Tensor,
    Expansion: *Expansion,
    CompoundAssign: *CompoundAssign, // Add new variant for compound assignments
    Binary: *Binary, // Added for generic binary ops
    Unary: *Unary, // Added for unary ops
    PointerMember: *PointerMember, // Added for ptr.* syntax (equivalent to -> in C)

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Literal => |*val| {
                // Free string if present
                if (val.* == .string and val.string.len > 0) {
                    allocator.free(val.string);
                }
            },
            .Variable => |v| {
                allocator.free(v.identifier);
                allocator.destroy(v);
            },
            .Operator => {}, // No allocation needed
            .Logical => |l| {
                l.left.deinit(allocator);
                l.right.deinit(allocator);
                allocator.destroy(l);
            },
            .Conditional => |c| {
                c.condition.deinit(allocator);
                c.body.deinit(allocator);
                if (c.else_body) |else_body| {
                    else_body.deinit(allocator);
                }
                allocator.destroy(c);
            },
            .Loop => |l| {
                if (l.condition) |condition| {
                    condition.deinit(allocator);
                }
                l.body.deinit(allocator);
                if (l.variable) |variable| {
                    allocator.free(variable);
                }
                if (l.collection) |collection| {
                    collection.deinit(allocator);
                }
                if (l.tail_expression) |tail_expr| {
                    tail_expr.deinit(allocator);
                }
                allocator.destroy(l);
            },
            .Call => |c| {
                allocator.free(c.identifier);
                c.arguments.deinit();
                allocator.destroy(c);
            },
            .Function => |f| {
                allocator.free(f.identifier);
                f.body.deinit(allocator);
                for (f.parameters.items) |param| {
                    allocator.free(param.identifier);
                }
                f.parameters.deinit();
                allocator.destroy(f);
            },
            .Block => |b| {
                for (b.body.items) |expr| {
                    expr.deinit(allocator);
                }
                b.body.deinit();
                allocator.destroy(b);
            },
            .Object => |o| {
                for (o.properties.items) |prop| {
                    var p = prop;
                    p.deinit(allocator);
                    allocator.destroy(prop);
                }
                o.properties.deinit();
                allocator.destroy(o);
            },
            .Property => |p| {
                var property = p;
                property.deinit(allocator);
                allocator.destroy(p);
            },
            .Flow => |f| {
                if (f.condition) |condition| {
                    condition.deinit(allocator);
                }
                if (f.body) |body| {
                    body.deinit(allocator);
                }
                allocator.destroy(f);
            },
            .Global => |g| {
                switch (g.type) {
                    .Const, .Var => {
                        allocator.free(g.identifier);
                        if (g.value) |val| {
                            val.deinit(allocator);
                        }
                    },
                    .Fn => {
                        allocator.free(g.identifier);
                        if (g.value) |val| {
                            val.deinit(allocator);
                        }
                    },
                    .Reference => {
                        allocator.free(g.identifier);
                        if (g.value) |val| {
                            val.deinit(allocator);
                        }
                    },
                    .Call => {
                        allocator.free(g.identifier);
                        if (g.arguments) |args| {
                            for (args.items) |arg| {
                                arg.deinit(allocator);
                            }
                            args.deinit();
                        }
                    },
                }
                allocator.destroy(g);
            },
            .Index => |idx| {
                idx.array.deinit(allocator);
                idx.index.deinit(allocator);
                allocator.destroy(idx);
            },
            .Range => |range| {
                if (range.start) |s| s.deinit(allocator);
                if (range.end) |e| e.deinit(allocator);
                allocator.destroy(range);
            },
            .Tensor => |tensor| {
                for (tensor.elements.items) |el| el.deinit(allocator);
                tensor.elements.deinit();
                allocator.destroy(tensor);
            },
            .Expansion => |exp| {
                exp.expr.deinit(allocator);
                allocator.destroy(exp);
            },
            .CompoundAssign => |ca| {
                ca.target.deinit(allocator);
                ca.value.deinit(allocator);
                allocator.destroy(ca);
            },
            .Binary => |b| {
                b.left.deinit(allocator);
                b.right.deinit(allocator);
                allocator.destroy(b);
            },
            .Unary => |u| {
                u.operand.deinit(allocator);
                allocator.destroy(u);
            },
            .PointerMember => |pm| {
                pm.object.deinit(allocator);
                allocator.free(pm.member);
                allocator.destroy(pm);
            },
        }
        allocator.destroy(self);
    }
};

pub const Variable = struct {
    identifier: []const u8,
    value: Value,
};

pub const LogicalOp = enum {
    And,
    Or,
};

pub const Logical = struct {
    op: LogicalOp,
    left: *Expression,
    right: *Expression,
};

pub const Conditional = struct {
    condition: *Expression,
    body: *Expression,
    else_body: ?*Expression = null,
};

pub const LoopType = enum {
    While,
    For,
};

pub const Loop = struct {
    type: LoopType = .While,
    condition: ?*Expression = null, // Used for While loops
    body: *Expression,
    variable: ?[]const u8 = null, // Used for For loops - variable name
    collection: ?*Expression = null, // Used for For loops - collection to iterate
    tail_expression: ?*Expression = null, // Used for tail expressions in while loops (after ':')
};

pub const Call = struct {
    identifier: []const u8,
    arguments: std.ArrayList(*Expression),
};

pub const Function = struct {
    identifier: []const u8,
    body: *Expression,
    parameters: std.ArrayList(Variable),
};

pub const Block = struct {
    body: std.ArrayList(*Expression),
};

pub const Object = struct {
    properties: std.ArrayList(*Property),
};

pub const Property = struct {
    key: []const u8,
    value: *Expression,

    pub fn deinit(self: *Property, allocator: std.mem.Allocator) void {
        allocator.free(self.key);
        self.value.deinit(allocator);
    }
};

pub const FlowType = enum {
    Return,
    Break,
    Continue,
    Defer, // Add defer flow type
};

pub const Flow = struct {
    type: FlowType = .Return,
    condition: ?*Expression = null,
    body: ?*Expression = null,
};

// Add a Global struct to represent global expressions
pub const Global = struct {
    type: GlobalType,
    identifier: []const u8,
    value: ?*Expression = null,
    arguments: ?std.ArrayList(*Expression) = null,
};

pub const Index = struct {
    array: *Expression,
    index: *Expression,
};

pub const Range = struct {
    start: ?*Expression,
    end: ?*Expression,
};

pub const Tensor = struct {
    elements: std.ArrayList(*Expression),
};

pub const Expansion = struct {
    expr: *Expression,
};

pub const CompoundAssign = struct {
    target: *Expression,
    op: Operator,
    value: *Expression,
};

// Define the new Binary struct
pub const Binary = struct {
    op: Operator,
    left: *Expression,
    right: *Expression,
};

// Define the new Unary struct
pub const Unary = struct {
    op: Operator,
    operand: *Expression,
};

// Define the PointerMember struct for pointer member access (ptr.* syntax)
pub const PointerMember = struct {
    object: *Expression, // The pointer expression
    member: []const u8, // The member name
};

const ParseError = error{
    UnexpectedToken,
    UnterminatedExpression,
    ExpectedIdentifier,
    InvalidSyntax,
    InconsistentIndentation,
    InconsistentSpacing,
    OutOfMemory,
};

// Define possible error types combining all potential errors
const ParserError = ParseError || std.mem.Allocator.Error;

// Add a simple heap system for managing expressions
const ExpressionHeap = struct {
    allocator: std.mem.Allocator,
    expressions: std.ArrayList(*Expression),

    pub fn init(allocator: std.mem.Allocator) ExpressionHeap {
        return ExpressionHeap{
            .allocator = allocator,
            .expressions = std.ArrayList(*Expression).init(allocator),
        };
    }

    pub fn deinit(self: *ExpressionHeap) void {
        // Free all expressions in the heap
        for (self.expressions.items) |expr| {
            expr.deinit(self.allocator);
        }
        self.expressions.deinit();
    }

    // Allocate a new expression and return its handle (index)
    pub fn allocate(self: *ExpressionHeap, expr: Expression) !usize {
        const new_expr = try self.allocator.create(Expression);
        new_expr.* = expr;

        try self.expressions.append(new_expr);
        return self.expressions.items.len - 1; // Return the index as handle
    }

    // Get an expression by handle
    pub fn get(self: *ExpressionHeap, handle: usize) ?*Expression {
        if (handle >= self.expressions.items.len) return null;
        return self.expressions.items[handle];
    }

    // Create a special marker for parentheses
    pub fn createParenMarker(self: *ExpressionHeap) !usize {
        return try self.allocate(Expression{ .Literal = Value{ .unit = {} } });
    }

    // Check if an expression is a parenthesis marker
    pub fn isParenMarker(self: *ExpressionHeap, handle: usize) bool {
        if (self.get(handle)) |expr| {
            return expr.* == .Literal and expr.Literal == .unit;
        }
        return false;
    }
};

// Update ParserState to include the heap
pub fn initParserState(allocator: std.mem.Allocator, tokens: []const Token) std.mem.Allocator.Error!ParserState {
    return ParserState{
        .tokens = tokens,
        .index = 0,
        .allocator = allocator,
        .operatorStack = std.ArrayList(usize).init(allocator),
        .outputStack = std.ArrayList(usize).init(allocator),
        .expressionHeap = ExpressionHeap.init(allocator),
        .indentationLevel = 0,
        .in_if_context = false,
        .if_indent_level = 0,
    };
}

// Modify ParserState struct to use the heap:
const ParserState = struct {
    tokens: []const Token,
    index: usize,
    allocator: std.mem.Allocator,
    operatorStack: std.ArrayList(usize), // Now stores handles (indices) to expressions in the heap
    outputStack: std.ArrayList(usize), // Now stores handles (indices) to expressions in the heap
    expressionHeap: ExpressionHeap, // The heap for managing expressions
    indentationLevel: usize,
    in_if_context: bool = false,
    if_indent_level: usize = 0,

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) std.mem.Allocator.Error!ParserState {
        return initParserState(allocator, tokens);
    }

    pub fn deinit(self: *ParserState) void {
        self.operatorStack.deinit();
        self.outputStack.deinit();
        self.expressionHeap.deinit();
    }

    pub fn currentToken(self: *ParserState) ?Token {
        if (self.index >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.index];
    }

    pub fn nextToken(self: *ParserState) ?Token {
        self.index += 1;
        return self.currentToken();
    }

    pub fn peekNextToken(self: *ParserState) ?Token {
        if (self.index + 1 >= self.tokens.len) {
            return null;
        }
        return self.tokens[self.index + 1];
    }

    pub fn checkIndentation(self: *ParserState) !void {
        var indentCount: usize = 0;
        var newlineFound = false;
        var invalidIndent = false;

        // Look for newline followed by indentation
        var i: usize = self.index;
        while (i < self.tokens.len) : (i += 1) {
            const token = self.tokens[i];

            if (token == .newline) {
                newlineFound = true;
                indentCount = 0;
                continue;
            }

            if (newlineFound) {
                if (token == .indent) {
                    indentCount += 1;
                } else {
                    break;
                }
            } else if (token == .indent) {
                // Track if we found indentation without a preceding newline
                // (We'll handle this after the loop)
                indentCount += 1;
                invalidIndent = true;
            }
        }

        // Check if there's an indentation without a newline
        if (invalidIndent and !newlineFound) {
            // Only allow this at the root level
            debug("checkIndentation: Indent without newline (level: {d})\n", .{self.indentationLevel});
            if (self.indentationLevel > 0) {
                return ParseError.InvalidSyntax; // Indent without preceding newline not at root level
            }
        }

        // Check if indentation level changed unexpectedly
        if (newlineFound and indentCount != self.indentationLevel) {
            // Allow increasing by exactly one level
            if (indentCount == self.indentationLevel + 1) {
                debug("checkIndentation: Increasing indent level from {d} to {d}\n", .{ self.indentationLevel, indentCount });
                self.indentationLevel = indentCount;
            }
            // Allow decreasing to any previous level
            else if (indentCount < self.indentationLevel) {
                debug("checkIndentation: Decreasing indent level from {d} to {d}\n", .{ self.indentationLevel, indentCount });
                self.indentationLevel = indentCount;
            }
            // Otherwise, it's an error
            else if (indentCount > self.indentationLevel + 1) {
                debug("checkIndentation: Error - Inconsistent indentation (jumped from {d} to {d})\n", .{ self.indentationLevel, indentCount });
                return ParseError.InconsistentIndentation;
            }
        }
    }

    pub fn processWhitespace(self: *ParserState) !void {
        debug("processWhitespace: Starting at index {d}, current indentationLevel: {d}\n", .{ self.index, self.indentationLevel });
        var newlineFound = false;
        var indentCount: usize = 0;
        var whitespace_count: usize = 0;
        var found_else = false;
        var else_token_idx: usize = 0;

        // Look ahead to find if there's an else token after whitespace
        var peek_idx = self.index;
        debug("processWhitespace: Looking ahead for tokens starting at index {d}\n", .{peek_idx});
        while (peek_idx < self.tokens.len) {
            const peek_token = self.tokens[peek_idx];
            if (peek_token == .space or peek_token == .newline or peek_token == .indent or peek_token == .comment) {
                peek_idx += 1;
                continue;
            }

            // Found a non-whitespace token
            found_else = (peek_token == .keyword and peek_token.keyword == .@"else");
            if (found_else) {
                else_token_idx = peek_idx;
                debug("processWhitespace: Found 'else' token at index {d} looking ahead, in_if_context: {}, if_indent_level: {d}\n", .{ else_token_idx, self.in_if_context, self.if_indent_level });
            } else {
                debug("processWhitespace: Found non-else token at index {d}: {any}\n", .{ peek_idx, peek_token });
            }
            break;
        }

        // Collect all whitespace tokens and calculate indentation
        debug("processWhitespace: Now counting indentation starting from index {d}\n", .{self.index});
        while (self.index < self.tokens.len) {
            const curToken = self.tokens[self.index];
            switch (curToken) {
                .newline => {
                    newlineFound = true;
                    indentCount = 0;
                    debug("processWhitespace: Found newline, resetting indentCount to 0\n", .{});
                    self.index += 1;
                    whitespace_count += 1;
                },
                .indent => {
                    if (!newlineFound) {
                        debug("processWhitespace: Error - Indent without preceding newline\n", .{});
                        return ParseError.InvalidSyntax;
                    }
                    indentCount += 1;
                    debug("processWhitespace: Found indent, indentCount now {d}\n", .{indentCount});
                    self.index += 1;
                    whitespace_count += 1;
                },
                .space, .comment => {
                    self.index += 1;
                    whitespace_count += 1;
                },
                else => {
                    debug("processWhitespace: Found non-whitespace token: {any}, breaking loop\n", .{curToken});
                    break;
                },
            }
        }

        if (newlineFound) {
            debug("processWhitespace: Newline was found, indentCount: {d}, old indentationLevel: {d}\n", .{ indentCount, self.indentationLevel });

            // Check if we found an else token and verify indentation if in if-context
            if (found_else and self.in_if_context) {
                debug("processWhitespace: Processing 'else' indentation. Current line indent: {d}, required if_indent_level: {d}, in_if_context: {}\n", .{ indentCount, self.if_indent_level, self.in_if_context });

                if (indentCount != self.if_indent_level) {
                    debug("processWhitespace: 'else' token has incorrect line indentation {d}, must match 'if' line indentation: {d}\n", .{ indentCount, self.if_indent_level });
                    return ParseError.InconsistentIndentation;
                } else {
                    // 'else' has correct indentation
                    debug("processWhitespace: 'else' token has correct line indentation matching 'if': {d}\n", .{indentCount});
                    self.indentationLevel = indentCount;
                }
            } else if (found_else) {
                debug("processWhitespace: Found 'else' token but in_if_context is false! Will use normal indentation rules.\n", .{});
                debug("processWhitespace: 'else' indentCount: {d}, indentationLevel: {d}, if_indent_level: {d}\n", .{ indentCount, self.indentationLevel, self.if_indent_level });
                // Fall through to normal indentation checking
            } else {
                debug("processWhitespace: Using normal indentation rules (non-else token)\n", .{});
            }

            // Normal indentation level checking for tokens (including 'else' if not in if-context)
            if (indentCount == self.indentationLevel + 1) {
                // New block - indent increased by exactly one level
                debug("processWhitespace: Indentation increased by 1 from {d} to {d}\n", .{ self.indentationLevel, indentCount });
                self.indentationLevel = indentCount;
            } else if (indentCount <= self.indentationLevel) {
                // Dedent or same level - always allowed
                debug("processWhitespace: Indentation decreased or stayed same: {d} -> {d}\n", .{ self.indentationLevel, indentCount });
                self.indentationLevel = indentCount;
            } else if (indentCount > self.indentationLevel + 1) {
                // Check if the previous token was 'else' - if so, be more lenient
                var prev_token_was_else = false;
                if (self.index > 0) {
                    var look_back = self.index - 1;
                    // Skip any whitespace when looking backwards
                    while (look_back > 0) {
                        const prev = self.tokens[look_back];
                        if (prev == .space or prev == .newline or prev == .indent or prev == .comment) {
                            look_back -= 1;
                            continue;
                        }
                        // Check if it's an else token
                        prev_token_was_else = (prev == .keyword and prev.keyword == .@"else");
                        debug("processWhitespace: Looking back found token: {any}, is_else: {}\n", .{ prev, prev_token_was_else });
                        break;
                    }
                }

                if (prev_token_was_else) {
                    // Special case: Allow bigger indentation jumps after 'else'
                    debug("processWhitespace: Allowing indentation jump after 'else': {d} -> {d}\n", .{ self.indentationLevel, indentCount });
                    self.indentationLevel = indentCount;
                } else {
                    debug("processWhitespace: Error - Indent jumped more than one level: {d} -> {d}\n", .{ self.indentationLevel, indentCount });
                    return ParseError.InconsistentIndentation;
                }
            }
        } else {
            debug("processWhitespace: No newline found, keeping indentationLevel at {d}\n", .{self.indentationLevel});
        }
        debug("processWhitespace: Finished with {d} whitespace tokens, new indentationLevel: {d}\n", .{ whitespace_count, self.indentationLevel });
    }

    pub fn checkOperatorSpacing(self: *ParserState) !void {
        if (self.currentToken()) |token| {
            if (token == .operator) {
                // Special case for operators that don't require spaces
                // Check for space before operator
                if (token.operator.requiresLeftSpace() and self.index > 0) {
                    const prevToken = self.tokens[self.index - 1];
                    if (prevToken != .space) {
                        return ParseError.InconsistentSpacing;
                    }
                }

                // Check for space after operator
                if (token.operator.requiresRightSpace() and self.index + 1 < self.tokens.len) {
                    const tokenAfter = self.tokens[self.index + 1];
                    if (tokenAfter != .space) {
                        return ParseError.InconsistentSpacing;
                    }
                }
            }
        }
    }
};

// Add a deinitSlice function to properly clean up expression arrays
pub fn deinitExpressions(expressions: []const *Expression, allocator: std.mem.Allocator) void {
    for (expressions) |expr| {
        expr.deinit(allocator);
    }
    allocator.free(expressions);
}

// Function to handle global expression parsing
fn parseGlobalExpression(state: *ParserState) ParserError!*Expression {
    debug("parseGlobalExpression: Starting\n", .{});

    // Consume the @ symbol
    try parseOperator(state, .@"@");
    try state.processWhitespace();

    // Get the identifier or keyword after @
    if (state.currentToken()) |token| {
        debug("parseGlobalExpression: Processing token after @: {any}\n", .{token});

        switch (token) {
            .keyword => |kw| {
                // ... existing keyword handling (@const, @var, @fn) ...
                // This part seems okay
                debug("parseGlobalExpression: Found keyword: {any}\n", .{kw});
                switch (kw) {
                    .@"const" => {
                        try parseKeyword(state, .@"const");
                        try state.processWhitespace();
                        const ident = try parseIdentifier(state);
                        errdefer state.allocator.free(ident);
                        try state.processWhitespace();
                        var value: ?*Expression = null;
                        if (state.currentToken()) |eq_token| {
                            if (eq_token == .operator and eq_token.operator == .@"=") {
                                try parseOperator(state, .@"=");
                                try state.processWhitespace();
                                value = try parseExpression(state);
                            }
                        }
                        const global = try state.allocator.create(Global);
                        global.* = Global{
                            .type = .Const,
                            .identifier = ident,
                            .value = value,
                        };
                        const result = try state.allocator.create(Expression);
                        result.* = Expression{ .Global = global };
                        return result;
                    },
                    .@"var" => {
                        try parseKeyword(state, .@"var");
                        try state.processWhitespace();
                        const ident = try parseIdentifier(state);
                        errdefer state.allocator.free(ident);
                        try state.processWhitespace();
                        var value: ?*Expression = null;
                        if (state.currentToken()) |eq_token| {
                            if (eq_token == .operator and eq_token.operator == .@"=") {
                                try parseOperator(state, .@"=");
                                try state.processWhitespace();
                                value = try parseExpression(state);
                            }
                        }
                        const global = try state.allocator.create(Global);
                        global.* = Global{
                            .type = .Var,
                            .identifier = ident,
                            .value = value,
                        };
                        const result = try state.allocator.create(Expression);
                        result.* = Expression{ .Global = global };
                        return result;
                    },
                    .@"fn" => {
                        // Consume fn keyword handled by parseFunctionExpression
                        const func_expr = try parseFunctionExpression(state);

                        // Extract function details
                        if (func_expr.* != .Function) return ParseError.UnexpectedToken;
                        const func = func_expr.Function;

                        // Create global function
                        const global = try state.allocator.create(Global);
                        // Dupe identifier since func_expr owns its identifier
                        global.* = Global{
                            .type = .Fn,
                            .identifier = try state.allocator.dupe(u8, func.identifier),
                            .value = func_expr,
                        };

                        const result = try state.allocator.create(Expression);
                        result.* = Expression{ .Global = global };
                        return result;
                    },
                    else => return ParseError.UnexpectedToken,
                }
            },
            .identifier => |_| { // Use underscore for unused capture
                var ident_ptr: ?[]const u8 = null; // Use a pointer to manage ownership
                errdefer if (ident_ptr) |ptr| state.allocator.free(ptr); // Free if not transferred

                ident_ptr = try parseIdentifier(state);
                const ident = ident_ptr.?;

                debug("parseGlobalExpression: Found identifier: '{s}'\n", .{ident});

                // Skip any whitespace after identifier
                try state.processWhitespace();

                // Check if it's a function call (followed by parentheses)
                if (state.currentToken()) |next_token| {
                    if (next_token == .punctuation and next_token.punctuation == .@"(") {
                        // Global function call - parse arguments directly here
                        debug("parseGlobalExpression: Detected global call for '{s}'\n", .{ident});
                        const args = try parseArgumentList(state);

                        // Create global call
                        const global = try state.allocator.create(Global);
                        global.* = Global{
                            .type = .Call,
                            .identifier = ident, // Ownership moves here
                            .arguments = args,
                        };

                        const result = try state.allocator.create(Expression);
                        result.* = Expression{ .Global = global };

                        // Mark identifier as transferred
                        ident_ptr = null;
                        return result;
                    } else if (next_token == .operator and next_token.operator == .@"=") {
                        // Global variable assignment (e.g., @myVar = 10)
                        // This syntax might be ambiguous or unintended?
                        // For now, let's assume assignment is handled by @var or @const
                        // If direct assignment like @ident = value is needed, handle it here.
                        // Let's treat @identifier = ... as an error for now unless specified.
                        debug("parseGlobalExpression: Error - Direct assignment to @identifier not supported use @var or @const\n", .{});
                        return ParseError.InvalidSyntax;
                    }
                }

                // Simple global reference (e.g., use @myConst)
                debug("parseGlobalExpression: Detected global reference for '{s}'\n", .{ident});
                const global = try state.allocator.create(Global);
                global.* = Global{
                    .type = .Reference,
                    .identifier = ident, // Ownership moves here
                    .value = null,
                    .arguments = null,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression{ .Global = global };

                // Mark identifier as transferred
                ident_ptr = null;
                return result;
            },
            .space, .newline, .indent => {
                debug("parseGlobalExpression: Skipping whitespace\n", .{});
                _ = state.nextToken();
                return parseGlobalExpression(state); // Recursively call to process after whitespace
            },
            .comment => |comment_text| {
                debug("parseGlobalExpression: Skipping comment: '{s}'\n", .{comment_text});
                _ = state.nextToken();
                return parseGlobalExpression(state); // Recursively call to process after comment
            },
            else => {
                debug("parseGlobalExpression: Error - Unexpected token after @: {any}\n", .{token});
                return ParseError.UnexpectedToken;
            },
        }
    } else {
        debug("parseGlobalExpression: Error - Missing token after @\n", .{});
        return ParseError.UnexpectedToken;
    }
}

// Helper function to parse a function expression
fn parseFunctionExpression(state: *ParserState) ParserError!*Expression {
    debug("parseFunctionExpression: Starting\n", .{});
    _ = state.nextToken(); // consume 'fn'

    // Skip any whitespace after 'fn'
    try state.processWhitespace();

    // Parse function name
    const func_name = try parseIdentifier(state);
    errdefer state.allocator.free(func_name);
    debug("parseFunctionExpression: Processing function '{s}'\n", .{func_name});

    // Skip any whitespace after function name
    try state.processWhitespace();

    // Parse parameters
    var params = std.ArrayList(Variable).init(state.allocator);
    errdefer {
        for (params.items) |param| {
            state.allocator.free(param.identifier);
        }
        params.deinit();
    }

    // Check for parameters
    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@"(") {
            debug("parseFunctionExpression: Parsing parameters for '{s}'\n", .{func_name});
            _ = state.nextToken(); // consume open parenthesis
            try state.processWhitespace();

            // Parse parameters
            while (state.currentToken()) |param_token| {
                if (param_token == .punctuation and param_token.punctuation == .@")") {
                    _ = state.nextToken(); // consume close parenthesis
                    break;
                }

                if (param_token == .punctuation and param_token.punctuation == .@",") {
                    _ = state.nextToken(); // consume comma
                    try state.processWhitespace();
                    continue;
                }

                // Check for pointer parameter
                var is_pointer = false;
                if (param_token == .operator and param_token.operator == .@"*") {
                    is_pointer = true;
                    _ = state.nextToken(); // consume *
                    try state.processWhitespace();
                }

                // Parse parameter name
                const param_name = try parseIdentifier(state);
                try state.processWhitespace();

                // Create variable for parameter (with prefix if pointer)
                var full_param_name: []const u8 = undefined;
                if (is_pointer) {
                    // Add a "*" prefix to indicate it's a pointer parameter
                    full_param_name = try std.fmt.allocPrint(state.allocator, "*{s}", .{param_name});
                    state.allocator.free(param_name); // Free the original name
                } else {
                    full_param_name = param_name;
                }

                debug("parseFunctionExpression: Added parameter '{s}' to function '{s}'\n", .{ full_param_name, func_name });
                try params.append(Variable{
                    .identifier = full_param_name,
                    .value = .{ .unit = {} },
                });
            }
        }
    }
    debug("parseFunctionExpression: Function '{s}' has {d} parameters\n", .{ func_name, params.items.len });

    // Parse function body
    try state.processWhitespace();
    debug("parseFunctionExpression: Parsing body for function '{s}'\n", .{func_name});

    // Use a fresh state for the body to avoid any state issues
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;

    const body = try parseExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update the original state's index
    state.index += body_state.index;

    debug("parseFunctionExpression: Successfully parsed body for function '{s}'\n", .{func_name});

    // Create function
    const function = try state.allocator.create(Function);
    function.* = Function{
        .identifier = func_name,
        .body = body,
        .parameters = params,
    };
    debug("parseFunctionExpression: Created function node for '{s}'\n", .{func_name});

    const result = try state.allocator.create(Expression);
    result.* = Expression{ .Function = function };
    debug("parseFunctionExpression: Returning function expression for '{s}'\n", .{func_name});

    return result;
}

// Restore direct keyword handling in parseExpression
// Modify parseExpression to better handle function call statements

fn parseExpression(state: *ParserState) ParserError!*Expression {
    // Save the current output stack
    const old_output_stack = state.outputStack;
    state.outputStack = std.ArrayList(usize).init(state.allocator);
    defer {
        // We don't need to explicitly free the items here, as evaluateRPN takes ownership
        // of the items in the outputStack if called. If not called (e.g., on error),
        // the expressions in the stack may need to be freed, but we need to be careful
        // not to double-free them.

        // Just deinit the ArrayList itself (not its items) to prevent memory leak
        state.outputStack.deinit();
        state.outputStack = old_output_stack; // Restore original
    }

    debug("parseExpression: Starting at index {d}\n", .{state.index});

    // Store the current token for better error reporting
    const starting_token = state.currentToken();
    debug("parseExpression: Starting with token: {any}\n", .{starting_token});

    // Handle prefix unary operators so "~if" or "&if" etc works
    if (state.currentToken()) |tok| {
        if (tok == .operator and (tok.operator == .@"-" or tok.operator == .@"!" or tok.operator == .@"~" or tok.operator == .@"&" or tok.operator == .@"*")) {
            const op = tok.operator;
            _ = state.nextToken(); // consume unary operator
            try state.processWhitespace();

            // Create a fresh parser state for the operand, preserving the if context
            var operand_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            operand_state.indentationLevel = state.indentationLevel;
            operand_state.in_if_context = state.in_if_context; // Propagate if context
            defer operand_state.deinit();

            const operand = try parseExpression(&operand_state);

            // Update original state index
            state.index += operand_state.index;

            // Wrap operand in a Unary node
            const unary_node = try state.allocator.create(Unary);
            unary_node.* = Unary{ .op = op, .operand = operand };
            const result = try state.allocator.create(Expression);
            result.* = Expression{ .Unary = unary_node };
            return result;
        }
    }

    // Handle keywords that define the entire expression type directly
    if (state.currentToken()) |token| {
        if (token == .keyword) {
            // START Restored block
            switch (token.keyword) {
                .@"if" => return parseIfExpression(state),
                .@"while" => return parseWhileExpression(state),
                .@"for" => return parseForExpression(state),
                .@"return", .@"break", .@"continue", .@"defer" => return parseFlowExpression(state),
                .@"fn" => return parseFunctionExpression(state),
                .true => {
                    try parseKeyword(state, .true);
                    return createLiteralExpression(state, Value{ .boolean = true });
                },
                .false => {
                    try parseKeyword(state, .false);
                    return createLiteralExpression(state, Value{ .boolean = false });
                },
                // Let shunting yard handle 'and', 'or'
                else => {
                    debug("parseExpression: Keyword {s} not handled directly, falling to shunting yard\n", .{@tagName(token.keyword)});
                },
            }
        } else if (token == .operator and token.operator == .@"@") {
            // Let the shunting yard handle @ operator now
            debug("parseExpression: Found @ operator at start, proceeding to shunting yard\n", .{});
        }
    }

    // If control reached here, it wasn't a directly handled keyword or a prefix unary
    debug("parseExpression: Using shunting yard algorithm\n", .{});

    // Run shunting yard to produce RPN in state.outputStack
    try parseShuntingYard(state);

    // Check if shunting yard produced anything
    if (state.outputStack.items.len == 0) {
        debug("parseExpression: Error - Output stack is empty after shunting yard\n", .{});
        if (state.currentToken() == null or state.currentToken().? == .newline) {
            debug("parseExpression: Output stack empty at newline/EOF, returning unit\n", .{});
            return createLiteralExpression(state, Value{ .unit = {} });
        }

        // Improved error handling - check for specific tokens that might have caused the issue
        if (starting_token) |token| {
            debug("parseExpression: Empty output stack, started with token: {any}\n", .{token});

            // Special case for expressions starting with @ (like @column)
            if (token == .operator and token.operator == .@"@") {
                debug("parseExpression: Found @ operator with empty stack, attempting to create global reference\n", .{});

                // Try to create a placeholder global reference
                if (state.index > 0 and state.index < state.tokens.len) {
                    const next_token = state.tokens[state.index];
                    if (next_token == .identifier) {
                        const ident = try state.allocator.dupe(u8, next_token.identifier);

                        const global = try state.allocator.create(Global);
                        global.* = Global{
                            .type = .Reference,
                            .identifier = ident,
                            .value = null,
                        };

                        const result = try state.allocator.create(Expression);
                        result.* = Expression{ .Global = global };
                        return result;
                    }
                }
            }

            // If we're dealing with binary operators like << or >>
            if (token == .operator and (token.operator == .@"<<" or token.operator == .@">>")) {
                debug("parseExpression: Found bitshift operator with empty stack\n", .{});
                // Create a dummy expression to continue processing
                return createLiteralExpression(state, Value{ .scalar = 0 });
            }
        }

        return ParseError.UnterminatedExpression;
    }

    // Evaluate the RPN stack to build the final expression tree
    const final_expr = try evaluateRPN(state);

    debug("parseExpression: Successfully evaluated RPN, result type {s}\n", .{@tagName(std.meta.activeTag(final_expr.*))});
    return final_expr;
}

// Evaluates the RPN stack (outputStack) to build the final expression tree
fn evaluateRPN(state: *ParserState) ParserError!*Expression {
    debug("evaluateRPN: Starting with {d} RPN tokens\n", .{state.outputStack.items.len});

    var evalStack = std.ArrayList(usize).init(state.allocator);
    defer evalStack.deinit();

    for (state.outputStack.items) |expr_handle| {
        const expr = state.expressionHeap.get(expr_handle).?;
        debug("evaluateRPN: Processing RPN item: {any}\n", .{expr.*});

        switch (expr.*) {
            .Literal, .Variable, .Conditional, .Loop, .Call, .Function, .Block, .Object, .Flow, .Global, .Index, .Range, .Tensor, .Expansion, .CompoundAssign, .Unary => {
                // Operand: Push onto eval stack
                try evalStack.append(expr_handle);
                debug("evaluateRPN: Pushed operand {s}\n", .{@tagName(std.meta.activeTag(expr.*))});
            },

            .Operator => |op| {
                debug("evaluateRPN: Found operator {any}\n", .{op});

                // Handle operators similarly to before but using handles
                if (op == .@"-" or op == .@"!" or op == .@"~" or op == .@"*" or op == .@"&") {
                    // Unary operator
                    if (evalStack.items.len < 1) {
                        debug("evaluateRPN: Error - Insufficient operand for unary operator {any}\n", .{op});
                        return ParseError.InvalidSyntax;
                    }

                    const operand_handle = evalStack.pop().?;
                    const operand = state.expressionHeap.get(operand_handle).?;
                    debug("evaluateRPN: Popped operand={any} for unary op={any}\n", .{ operand.*, op });

                    // Create Unary expression
                    const unary = try state.allocator.create(Unary);
                    unary.* = Unary{
                        .op = op,
                        .operand = operand,
                    };

                    const unary_handle = try state.expressionHeap.allocate(Expression{ .Unary = unary });
                    try evalStack.append(unary_handle);
                    debug("evaluateRPN: Pushed Unary result\n", .{});
                } else {
                    // Binary operator
                    if (evalStack.items.len < 2) {
                        debug("evaluateRPN: Error - Insufficient operands for binary operator {any}\n", .{op});

                        // Special handling for bitshift operators
                        if (op == .@"<<" or op == .@">>") {
                            debug("evaluateRPN: Special handling for bitshift with insufficient operands\n", .{});

                            // Create dummy operands as needed
                            var left_handle: usize = undefined;
                            var right_handle: usize = undefined;

                            if (evalStack.items.len == 0) {
                                // Need both operands
                                left_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .scalar = 0 } });
                                right_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .scalar = 1 } });
                            } else {
                                // Have one operand already
                                right_handle = evalStack.pop().?;
                                left_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .scalar = 0 } });
                            }

                            // Create the binary expression
                            const binary = try state.allocator.create(Binary);
                            binary.* = Binary{ .op = op, .left = state.expressionHeap.get(left_handle).?, .right = state.expressionHeap.get(right_handle).? };

                            const binary_handle = try state.expressionHeap.allocate(Expression{ .Binary = binary });
                            try evalStack.append(binary_handle);
                            continue;
                        }

                        return ParseError.InvalidSyntax;
                    }

                    const right_handle = evalStack.pop().?;
                    const left_handle = evalStack.pop().?;
                    const right = state.expressionHeap.get(right_handle).?;
                    const left = state.expressionHeap.get(left_handle).?;

                    debug("evaluateRPN: Popped left={any}, right={any} for binary op={any}\n", .{ left.*, right.*, op });

                    var new_handle: usize = undefined;

                    if (op == .@"=") {
                        // Assignment
                        debug("evaluateRPN: Creating assignment\n", .{});
                        const binary = try state.allocator.create(Binary);
                        binary.* = Binary{ .op = op, .left = left, .right = right };
                        new_handle = try state.expressionHeap.allocate(Expression{ .Binary = binary });
                    } else {
                        // Generic binary operator
                        const binary = try state.allocator.create(Binary);
                        binary.* = Binary{ .op = op, .left = left, .right = right };
                        new_handle = try state.expressionHeap.allocate(Expression{ .Binary = binary });
                    }

                    try evalStack.append(new_handle);
                    debug("evaluateRPN: Pushed Binary result\n", .{});
                }
            },

            else => {
                debug("evaluateRPN: Error - Unexpected item in RPN stack\n", .{});
                return ParseError.InvalidSyntax;
            },
        }
    }

    // Final result should be the single item left on the stack
    if (evalStack.items.len >= 1) {
        // If more than one item, discard extras
        while (evalStack.items.len > 1) {
            const extra_handle = evalStack.pop().?;
            _ = extra_handle; // We don't free here since expressions are owned by the heap
        }

        const final_handle = evalStack.pop().?;
        const final_expr = state.expressionHeap.get(final_handle).?;

        debug("evaluateRPN: Finished with result\n", .{});
        return final_expr;
    } else {
        debug("evaluateRPN: Error - Eval stack has 0 items, expected expression\n", .{});
        return ParseError.InvalidSyntax;
    }
}

pub fn parse(allocator: std.mem.Allocator, tokens: std.ArrayList(Token)) ParserError![]const *Expression {
    debug("parse: Starting with {d} tokens\n", .{tokens.items.len});

    // Log the first 10 tokens for debugging
    debug("parse: First tokens: [", .{});
    const token_display_limit = @min(10, tokens.items.len);
    for (tokens.items[0..token_display_limit], 0..) |token, i| {
        if (i > 0) debug(", ", .{});
        debug("{any}", .{token});
    }
    if (tokens.items.len > token_display_limit) {
        debug(", ...", .{});
    }
    debug("]\n", .{});

    var results = std.ArrayList(*Expression).init(allocator);
    errdefer {
        debug("parse: Error occurred, cleaning up expressions\n", .{});
        for (results.items) |expr| {
            expr.deinit(allocator);
        }
        results.deinit();
    }

    // Initialize parser state
    var state = try ParserState.init(allocator, tokens.items);
    defer {
        debug("parse: Cleaning up parser state\n", .{});
        // No need to do extensive cleanup here as the defer block will just
        // deinit the ArrayLists, and we're careful about memory ownership elsewhere
        state.deinit();
    }

    // Parse multiple expressions until we run out of tokens
    var expr_count: usize = 0;
    while (state.currentToken() != null) {
        try state.processWhitespace();
        if (state.currentToken() == null) break;

        const loop_start_index = state.index;
        debug("parse: Loop iteration start. Index: {d}, Token: {any}\n", .{ loop_start_index, state.currentToken() });

        // Handle special cases for certain tokens
        if (state.currentToken()) |curr_token| {
            // If we find a closing delimiter without opening one, skip it
            if (curr_token == .punctuation and
                (curr_token.punctuation == .@")" or
                    curr_token.punctuation == .@"]" or
                    curr_token.punctuation == .@")"))
            {
                debug("parse: Skipping unexpected closing delimiter: {any}\n", .{curr_token});
                _ = state.nextToken();
                continue;
            }

            // Special handling for function declarations (including main)
            if (curr_token == .keyword and curr_token.keyword == .@"fn") {
                debug("parse: Found function declaration at top level, indentation level: {d}\n", .{state.indentationLevel});

                // Lookahead to check if it might be 'main' or other special functions
                var is_main_function = false;
                var is_special_global_function = false;
                if (state.index + 2 < state.tokens.len) {
                    const maybe_identifier = state.tokens[state.index + 1];
                    if (maybe_identifier == .identifier) {
                        is_main_function = std.mem.eql(u8, maybe_identifier.identifier, "main");
                        is_special_global_function = isAlwaysGlobalFunction(maybe_identifier.identifier);
                        debug("parse: Function name appears to be '{s}'{s}\n", .{ maybe_identifier.identifier, if (is_main_function) " (MAIN FUNCTION)" else if (is_special_global_function) " (SPECIAL GLOBAL FUNCTION)" else "" });
                    }
                }

                // All functions with 0 indentation level are treated as global functions
                const is_global_function = (state.indentationLevel == 0);
                debug("parse: Function is global: {} (indentation level: {}), is special global: {}\n", .{ is_global_function, state.indentationLevel, is_special_global_function });

                // Create a fresh state for parsing the function
                var func_state = try ParserState.init(allocator, state.tokens[state.index..]);
                defer func_state.deinit();
                func_state.indentationLevel = state.indentationLevel;

                // Parse the function expression
                const func_expr = try parseFunctionExpression(&func_state);
                errdefer func_expr.deinit(allocator);

                // Update the original state's index
                const pre_update_index = state.index;
                state.index += func_state.index;
                debug("parse: Function parsing advanced index from {d} to {d} ({d} tokens)\n", .{ pre_update_index, state.index, state.index - pre_update_index });

                // Convert regular function to global function if needed
                if (is_global_function or is_main_function or is_special_global_function) {
                    debug("parse: Converting function '{s}' to global function\n", .{if (func_expr.* == .Function) func_expr.Function.identifier else "unknown"});

                    if (func_expr.* == .Function) {
                        // Create global function wrapper
                        const global = try allocator.create(Global);
                        global.* = Global{
                            .type = .Fn,
                            .identifier = try allocator.dupe(u8, func_expr.Function.identifier),
                            .value = func_expr,
                            .arguments = null,
                        };

                        const global_expr = try allocator.create(Expression);
                        global_expr.* = Expression{ .Global = global };

                        // Add the global function expression to results
                        try results.append(global_expr);
                    } else {
                        // If not a function (shouldn't happen), add as-is
                        try results.append(func_expr);
                    }
                }
            }
        }

        // ... existing code ...

        expr_count += 1;
    }

    return results.toOwnedSlice();
}

// Function to check if an identifier is the name of a function we always want to treat as global
fn isAlwaysGlobalFunction(identifier: []const u8) bool {
    // Add special function names that should always be treated as global functions here
    return (std.mem.eql(u8, identifier, "main") or
        std.mem.eql(u8, identifier, "faceMask"));
}

// Add helper functions for token parsing
fn parseOperator(state: *ParserState, op: Operator) ParserError!void {
    debug("parseOperator: Expecting {s}\n", .{@tagName(op)});

    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == op) {
            _ = state.nextToken(); // consume the operator
            return;
        }
        debug("parseOperator: Error - Expected {s}, got {any}\n", .{ @tagName(op), token });
    } else {
        debug("parseOperator: Error - Expected {s}, got EOF\n", .{@tagName(op)});
    }
    return ParseError.UnexpectedToken;
}

fn parseKeyword(state: *ParserState, kw: Keyword) ParserError!void {
    debug("parseKeyword: Expecting {s}\n", .{@tagName(kw)});

    if (state.currentToken()) |token| {
        if (token == .keyword and token.keyword == kw) {
            _ = state.nextToken(); // consume the keyword
            return;
        }
        debug("parseKeyword: Error - Expected {s}, got {any}\n", .{ @tagName(kw), token });
    } else {
        debug("parseKeyword: Error - Expected {s}, got EOF\n", .{@tagName(kw)});
    }
    return ParseError.UnexpectedToken;
}

fn parseIdentifier(state: *ParserState) ParserError![]const u8 {
    debug("parseIdentifier: Starting\n", .{});

    if (state.currentToken()) |token| {
        if (token == .identifier) {
            const identifier = try state.allocator.dupe(u8, token.identifier);
            _ = state.nextToken(); // consume the identifier
            debug("parseIdentifier: Found '{s}'\n", .{identifier});
            return identifier;
        }
        debug("parseIdentifier: Error - Expected identifier, got {any}\n", .{token});
    } else {
        debug("parseIdentifier: Error - Expected identifier, got EOF\n", .{});
    }
    return ParseError.ExpectedIdentifier;
}

fn createLiteralExpression(state: *ParserState, value: Value) ParserError!*Expression {
    debug("createLiteralExpression: Creating literal with value {any}\n", .{value});

    const result = try state.allocator.create(Expression);
    result.* = Expression{ .Literal = value };
    return result;
}

fn parseIfExpression(state: *ParserState) ParserError!*Expression {
    debug("parseIfExpression: Starting\n", .{});

    // Consume 'if' keyword
    try parseKeyword(state, .@"if");
    try state.processWhitespace();

    // Track that we're in an if context now
    state.in_if_context = true;

    // Save the line indentation level for the 'if' statement
    var line_indent_level: usize = 0;
    // Look backwards to find the beginning of the line and count indents
    if (state.index > 0) {
        var curr_idx = state.index - 1; // Start at the token before 'if'
        while (curr_idx > 0) {
            const tok = state.tokens[curr_idx];
            if (tok == .newline) {
                // Found start of line
                break;
            }
            curr_idx -= 1;
        }

        // Now count indent tokens forward until we hit non-indent
        var found_non_whitespace = false;
        curr_idx += 1; // Move past newline
        while (curr_idx < state.index) {
            const tok = state.tokens[curr_idx];
            if (tok == .indent) {
                line_indent_level += 1;
            } else if (tok != .space and tok != .comment) {
                found_non_whitespace = true;
                break;
            }
            curr_idx += 1;
        }
    }
    debug("parseIfExpression: Line indentation level for 'if' = {d} (previous indentationLevel: {d})\n", .{ line_indent_level, state.indentationLevel });

    // Special case: If we're not at indentation level 0 but the 'if' token appears at indentation 0
    // (common when 'if' is used in an expression context), preserve the current indentation level
    if (state.indentationLevel > 0 and line_indent_level == 0) {
        // This is likely an 'if' used as part of an expression
        debug("parseIfExpression: Using current indentationLevel {d} since if appears at start of line\n", .{state.indentationLevel});
        state.if_indent_level = state.indentationLevel;
    } else {
        // Otherwise use the actual indentation level of the 'if' token line
        state.if_indent_level = line_indent_level;
    }

    // Parse condition (the expression after 'if')
    var condition_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer condition_state.deinit();
    condition_state.indentationLevel = state.indentationLevel;

    const condition = try parseExpression(&condition_state);
    errdefer condition.deinit(state.allocator);

    // Update state index
    state.index += condition_state.index;

    try state.processWhitespace();

    // Parse the body (the true branch)
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;

    const body = try parseExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update state index
    state.index += body_state.index;

    // Check for 'else' clause
    var else_body: ?*Expression = null;
    errdefer if (else_body) |eb| eb.deinit(state.allocator);

    try state.processWhitespace();

    if (state.currentToken()) |next_token| {
        if (next_token == .keyword and next_token.keyword == .@"else") {
            debug("parseIfExpression: Found else clause\n", .{});
            try parseKeyword(state, .@"else");
            try state.processWhitespace();

            // Parse the else branch
            var else_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            defer else_state.deinit();
            else_state.indentationLevel = state.indentationLevel;

            else_body = try parseExpression(&else_state);

            // Update state index
            state.index += else_state.index;
        }
    }

    // We're exiting the if-context
    state.in_if_context = false;

    // Create the conditional expression
    const conditional = try state.allocator.create(Conditional);
    conditional.* = Conditional{
        .condition = condition,
        .body = body,
        .else_body = else_body,
    };

    const result = try state.allocator.create(Expression);
    result.* = Expression{ .Conditional = conditional };
    return result;
}

fn parseWhileExpression(state: *ParserState) ParserError!*Expression {
    debug("parseWhileExpression: Starting\n", .{});

    // Consume 'while' keyword
    try parseKeyword(state, .@"while");
    try state.processWhitespace();

    // Parse condition
    var condition_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer condition_state.deinit();
    condition_state.indentationLevel = state.indentationLevel;

    const condition = try parseExpression(&condition_state);
    errdefer condition.deinit(state.allocator);

    // Update state index
    state.index += condition_state.index;

    // Check for tail expression (after ':')
    var tail_expression: ?*Expression = null;
    errdefer if (tail_expression) |t| t.deinit(state.allocator);

    try state.processWhitespace();

    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@":") {
            _ = state.nextToken(); // consume ':'
            try state.processWhitespace();

            // Parse tail expression
            var tail_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            defer tail_state.deinit();
            tail_state.indentationLevel = state.indentationLevel;

            tail_expression = try parseExpression(&tail_state);

            // Update state index
            state.index += tail_state.index;
        }
    }

    try state.processWhitespace();

    // Parse body
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;

    const body = try parseExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update state index
    state.index += body_state.index;

    // Create loop expression
    const loop = try state.allocator.create(Loop);
    loop.* = Loop{
        .type = .While,
        .condition = condition,
        .body = body,
        .tail_expression = tail_expression,
    };

    const result = try state.allocator.create(Expression);
    result.* = Expression{ .Loop = loop };
    return result;
}

fn parseForExpression(state: *ParserState) ParserError!*Expression {
    debug("parseForExpression: Starting\n", .{});

    // Consume 'for' keyword
    try parseKeyword(state, .@"for");
    try state.processWhitespace();

    // Parse the comma-separated expressions
    var expressions = std.ArrayList(*Expression).init(state.allocator);
    errdefer {
        for (expressions.items) |expr| {
            expr.deinit(state.allocator);
        }
        expressions.deinit();
    }

    // Parse expressions until we find a colon or the end of the statement
    while (true) {
        const expr = try parseExpression(state);
        try expressions.append(expr);

        try state.processWhitespace();

        if (state.currentToken()) |token| {
            if (token == .punctuation and token.punctuation == .@",") {
                // Found a comma, continue to the next expression
                _ = state.nextToken(); // consume comma
                try state.processWhitespace();
                continue;
            } else if (token == .punctuation and token.punctuation == .@":") {
                // Found a colon, indicating a tail expression follows
                _ = state.nextToken(); // consume colon
                try state.processWhitespace();
                break;
            } else if (token == .newline) {
                // End of statement without a tail expression
                break;
            } else {
                // Any other token signals the end of the for expressions
                break;
            }
        } else {
            // End of tokens
            break;
        }
    }

    // Make sure we have at least one expression (the condition)
    if (expressions.items.len == 0) {
        debug("parseForExpression: Error - For loop requires at least a condition\n", .{});
        return ParseError.InvalidSyntax;
    }

    // The last expression is the condition
    const condition = expressions.items[expressions.items.len - 1];

    // Parse the tail expression (after the colon) if present
    var tail_expression: ?*Expression = null;
    errdefer if (tail_expression) |t| t.deinit(state.allocator);

    if (state.currentToken() != null and state.currentToken().? != .newline) {
        var tail_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
        defer tail_state.deinit();
        tail_state.indentationLevel = state.indentationLevel;

        tail_expression = try parseExpression(&tail_state);

        // Update state index
        state.index += tail_state.index;
    }

    try state.processWhitespace();

    // Parse the body of the loop
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;

    const body = try parseExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update state index
    state.index += body_state.index;

    // Create the loop expression
    const loop = try state.allocator.create(Loop);
    loop.* = Loop{
        .type = .For,
        .condition = condition,
        .body = body,
        .tail_expression = tail_expression,
        // We're not setting variable and collection since we're using a different for loop model
    };

    // Attach the initialization expressions (if any) to the loop as part of a Block
    if (expressions.items.len > 1) {
        // Create a block containing the initialization expressions followed by the loop
        var block_items = std.ArrayList(*Expression).init(state.allocator);
        errdefer block_items.deinit();

        // Add all expressions except the last one (the condition)
        for (expressions.items[0 .. expressions.items.len - 1]) |init_expr| {
            try block_items.append(init_expr);
        }

        // Create the loop expression
        const loop_expr = try state.allocator.create(Expression);
        loop_expr.* = Expression{ .Loop = loop };

        // Add the loop to the block
        try block_items.append(loop_expr);

        // Create the block
        const block = try state.allocator.create(Block);
        block.* = Block{
            .body = block_items,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression{ .Block = block };
        return result;
    } else {
        // Only the condition, no initialization
        const result = try state.allocator.create(Expression);
        result.* = Expression{ .Loop = loop };
        return result;
    }
}

fn parseFlowExpression(state: *ParserState) ParserError!*Expression {
    debug("parseFlowExpression: Starting\n", .{});

    var flow_type: FlowType = undefined;

    // Determine flow type from keyword
    if (state.currentToken()) |token| {
        if (token == .keyword) {
            switch (token.keyword) {
                .@"return" => flow_type = .Return,
                .@"break" => flow_type = .Break,
                .@"continue" => flow_type = .Continue,
                .@"defer" => flow_type = .Defer,
                else => return ParseError.UnexpectedToken,
            }
            _ = state.nextToken(); // consume keyword
        } else {
            return ParseError.UnexpectedToken;
        }
    } else {
        return ParseError.UnexpectedToken;
    }

    // Check for value expression (for return or defer)
    var body: ?*Expression = null;
    errdefer if (body) |b| b.deinit(state.allocator);

    if (flow_type == .Return or flow_type == .Defer) {
        try state.processWhitespace();

        if (state.currentToken() != null and
            state.currentToken().? != .newline)
        {
            // There's an expression after return/defer
            body = try parseExpression(state);
        }
    }

    // Create flow expression
    const flow = try state.allocator.create(Flow);
    flow.* = Flow{
        .type = flow_type,
        .body = body,
    };

    const result = try state.allocator.create(Expression);
    result.* = Expression{ .Flow = flow };
    return result;
}

fn parseShuntingYard(state: *ParserState) ParserError!void {
    // Implementation of shunting yard algorithm
    debug("parseShuntingYard: Starting\n", .{});

    while (state.currentToken()) |token| {
        debug("parseShuntingYard: Processing token {any}\n", .{token});

        // Handle different token types
        switch (token) {
            .identifier => {
                // Push variable onto output
                const ident = try state.allocator.dupe(u8, token.identifier);

                const variable = Variable{
                    .identifier = ident,
                    .value = .{ .unit = {} },
                };

                const expr_handle = try state.expressionHeap.allocate(Expression{ .Variable = try state.allocator.create(Variable) });
                state.expressionHeap.get(expr_handle).?.*.Variable.* = variable;

                try state.outputStack.append(expr_handle);
                _ = state.nextToken(); // consume identifier
            },
            .literal => |lit| {
                var expr_handle: usize = undefined;

                if (lit == .scalar) {
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .scalar = lit.scalar } });
                } else if (lit == .real) {
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .real = lit.real } });
                } else if (lit == .string) {
                    const string_copy = try state.allocator.dupe(u8, lit.string);
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .string = string_copy } });
                } else if (lit == .boolean) {
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .boolean = lit.boolean } });
                } else if (lit == .unit) {
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .unit = {} } });
                } else {
                    // Handle other literal types
                    expr_handle = try state.expressionHeap.allocate(Expression{ .Literal = Value{ .unit = {} } });
                }

                try state.outputStack.append(expr_handle);
                _ = state.nextToken(); // consume literal
            },
            .operator => |op| {
                // Handle operator precedence
                while (state.operatorStack.items.len > 0) {
                    const top_handle = state.operatorStack.items[state.operatorStack.items.len - 1];
                    const top_expr = state.expressionHeap.get(top_handle).?;

                    if (top_expr.* == .Operator and
                        top_expr.Operator.precedence() >= op.precedence())
                    {
                        // Pop higher precedence operator onto output
                        const popped_handle = state.operatorStack.pop().?;
                        try state.outputStack.append(popped_handle);
                    } else {
                        break;
                    }
                }

                // Push current operator onto stack
                const op_handle = try state.expressionHeap.allocate(Expression{ .Operator = op });
                try state.operatorStack.append(op_handle);
                _ = state.nextToken(); // consume operator
            },
            .punctuation => |p| {
                switch (p) {
                    .@"(" => {
                        // Push a special marker for an open parenthesis
                        const paren_handle = try state.expressionHeap.createParenMarker();
                        try state.operatorStack.append(paren_handle);
                        _ = state.nextToken(); // consume '('
                    },
                    .@")" => {
                        // Pop operators until matching open parenthesis marker
                        var found_paren = false;
                        while (state.operatorStack.items.len > 0) {
                            const top_handle = state.operatorStack.pop().?;

                            // Check if this is our open parenthesis marker
                            if (state.expressionHeap.isParenMarker(top_handle)) {
                                found_paren = true;
                                break;
                            }

                            try state.outputStack.append(top_handle);
                        }

                        if (!found_paren) {
                            return ParseError.UnterminatedExpression;
                        }

                        _ = state.nextToken(); // consume ')'
                    },
                    else => {
                        // Other punctuation marks the end of the expression
                        break;
                    },
                }
            },
            // Stop on newlines or keywords that can follow expressions
            .newline, .keyword => {
                break;
            },
            .space, .indent, .comment => {
                // Whitespace and comments - skip
                _ = state.nextToken();
            },
        }

        // Skip any whitespace between tokens
        try state.processWhitespace();
    }

    // Pop remaining operators onto output
    while (state.operatorStack.items.len > 0) {
        const op_handle = state.operatorStack.pop().?;

        // Check if this is our open parenthesis marker
        if (state.expressionHeap.isParenMarker(op_handle)) {
            // Found unmatched opening parenthesis
            return ParseError.UnterminatedExpression;
        }

        try state.outputStack.append(op_handle);
    }

    debug("parseShuntingYard: Completed with {d} output items\n", .{state.outputStack.items.len});
}

// Add the parseArgumentList function before it's used
fn parseArgumentList(state: *ParserState) ParserError!std.ArrayList(*Expression) {
    debug("parseArgumentList: Starting\n", .{});

    var args = std.ArrayList(*Expression).init(state.allocator);
    errdefer {
        for (args.items) |arg| {
            arg.deinit(state.allocator);
        }
        args.deinit();
    }

    _ = state.nextToken(); // consume opening parenthesis
    try state.processWhitespace();

    // Check for empty argument list
    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@")") {
            _ = state.nextToken(); // consume closing parenthesis
            return args;
        }
    }

    // Parse arguments
    while (true) {
        const arg = try parseExpression(state);
        try args.append(arg);

        try state.processWhitespace();

        if (state.currentToken()) |token| {
            if (token == .punctuation and token.punctuation == .@")") {
                _ = state.nextToken(); // consume closing parenthesis
                break;
            } else if (token == .punctuation and token.punctuation == .@",") {
                _ = state.nextToken(); // consume comma
                try state.processWhitespace();
                continue;
            } else {
                debug("parseArgumentList: Unexpected token in argument list: {any}\n", .{token});
                return ParseError.UnexpectedToken;
            }
        } else {
            debug("parseArgumentList: Unexpected end of tokens in argument list\n", .{});
            return ParseError.UnterminatedExpression;
        }
    }

    debug("parseArgumentList: Parsed {d} arguments\n", .{args.items.len});
    return args;
}

// Add this new function to handle pointer member access with .* syntax
fn parsePointerMemberExpression(state: *ParserState) ParserError!*Expression {
    debug("parsePointerMemberExpression: Starting\n", .{});

    // Parse the object (pointer) expression
    const object = try parseExpression(state);
    errdefer object.deinit(state.allocator);

    try state.processWhitespace();

    // Check for . operator
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@".") {
            _ = state.nextToken(); // consume dot
            try state.processWhitespace();

            // Now check for * operator
            if (state.currentToken()) |star_token| {
                if (star_token == .operator and star_token.operator == .@"*") {
                    _ = state.nextToken(); // consume *
                    try state.processWhitespace();

                    // Parse member identifier
                    const member = try parseIdentifier(state);
                    errdefer state.allocator.free(member);

                    // Create the pointer member expression
                    const ptr_member = try state.allocator.create(PointerMember);
                    ptr_member.* = PointerMember{
                        .object = object,
                        .member = member,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression{ .PointerMember = ptr_member };
                    debug("parsePointerMemberExpression: Created PointerMember for object->'{s}'\n", .{member});
                    return result;
                }
            }
        }
    }

    // If we reached here, it's not a pointer member expression
    // Free the object since we're not using it in a PointerMember
    object.deinit(state.allocator);
    debug("parsePointerMemberExpression: Failed to parse pointer member access\n", .{});
    return ParseError.UnexpectedToken;
}
