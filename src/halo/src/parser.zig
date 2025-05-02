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

// Define the Var struct for mutable variables
pub const Var = struct {
    identifier: []const u8,
    value: *Expression,
};

// Define the Decl struct for declarations
pub const Decl = struct {
    identifier: []const u8,
    value: *Expression,
};

// Define the Const struct for constant variables
pub const Const = struct {
    identifier: []const u8,
    value: *Expression,
};

pub const Expression = struct {
    data: ExpressionData,
    ref_count: usize,
    pub fn init(data: ExpressionData) Expression {
        return Expression{
            .data = data,
            .ref_count = 1,
        };
    }

    pub fn addRef(self: *Expression) void {
        self.ref_count += 1;
    }

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        self.ref_count -= 1;
        if (self.ref_count == 0) {
            self.deinit(allocator);
            allocator.destroy(self);
        }
    }
};

pub const ExpressionData = union(enum) {
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
    PointerMember: *PointerMember, // Added for ptr.* member syntax (equivalent to -> in C)
    PointerDeref: *PointerDeref, // New: simple pointer dereference (ptr.*)
    Var: *Var, // Mutable variable expression
    Decl: *Decl, // Declaration expression
    Const: *Const, // Constant variable expression

    pub fn deinit(self: *Expression, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Literal => |*val| {
                // Free string if present
                if (val.* == .string and val.string.len > 0) {
                    allocator.free(val.string);
                }
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
            .Variable => |v| {
                if (v.identifier.len > 0) { // Only free if not empty
                    allocator.free(v.identifier);
                }
                allocator.destroy(v);
            },
            .Global => |g| {
                switch (g.type) {
                    .Const, .Var, .Fn, .Reference => {
                        if (g.identifier.len > 0) { // Only free if not empty
                            allocator.free(g.identifier);
                        }
                        if (g.value) |val| {
                            val.deinit(allocator);
                        }
                    },
                    .Call => {
                        if (g.identifier.len > 0) { // Only free if not empty
                            allocator.free(g.identifier);
                        }
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
            .PointerDeref => |pd| {
                pd.ptr.deinit(allocator);
                allocator.destroy(pd);
            },
            .Var => |v| {
                allocator.free(v.identifier);
                v.value.deinit(allocator);
                allocator.destroy(v);
            },
            .Decl => |d| {
                allocator.free(d.identifier);
                d.value.deinit(allocator);
                allocator.destroy(d);
            },
            .Const => |c| {
                allocator.free(c.identifier);
                c.value.deinit(allocator);
                allocator.destroy(c);
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

// Define the PointerDeref struct for simple pointer dereference (ptr.*)
pub const PointerDeref = struct {
    ptr: *Expression, // The pointer expression
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
        return try self.allocate(Expression.init(.{ .Literal = Value{ .unit = {} } }));
    }

    // Check if an expression is a parenthesis marker
    pub fn isParenMarker(self: *ExpressionHeap, handle: usize) bool {
        if (self.get(handle)) |expr| {
            return expr.*.data == .Literal and expr.*.data.Literal == .unit;
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
    in_inline_if: bool = false,
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

        // Add a safety check to prevent infinite recursion
        // This helps avoid loops when processing operators and identifiers
        if (self.index < self.tokens.len) {
            const curr = self.tokens[self.index];
            const should_skip = switch (curr) {
                .operator => |op| op == .@"=" or
                    op == .@"*" or
                    op == .@"&" or
                    op == .@"~" or
                    op == .@"!",
                .punctuation => |p| p == .@"[" or p == .@"]", // Skip array indexing brackets
                .identifier => true, // Skip whitespace processing for identifiers to prevent loops
                else => false,
            };

            if (should_skip) {
                debug("processWhitespace: Skipping whitespace processing for token {any} to prevent loop\n", .{curr});
                return;
            }
        }

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
                var should_allow_indent_jump = false;

                // Special handling for indentation at level 0
                if (self.indentationLevel == 0) {
                    // At the root level, we can be more permissive with indentation jumps
                    should_allow_indent_jump = true;
                    debug("processWhitespace: At root level, allowing larger indent jump from 0 to {d}\n", .{indentCount});
                }

                if (self.index > 0 and !should_allow_indent_jump) {
                    var look_back = self.index - 1;
                    // Skip any whitespace when looking backwards
                    while (look_back > 0) {
                        const prev = self.tokens[look_back];
                        if (prev == .space or prev == .newline or prev == .indent or prev == .comment) {
                            look_back -= 1;
                            continue;
                        }
                        // Check if it's an else token
                        if (prev == .keyword and prev.keyword == .@"else") {
                            should_allow_indent_jump = true;
                        }
                        debug("processWhitespace: Looking back found token: {any}, allowing jump: {}\n", .{ prev, should_allow_indent_jump });
                        break;
                    }
                }

                if (should_allow_indent_jump) {
                    // Special case: Allow bigger indentation jumps after 'else' or at root level
                    debug("processWhitespace: Allowing indentation jump from {d} -> {d}\n", .{ self.indentationLevel, indentCount });
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
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"@") {
            _ = state.nextToken(); // consume the @ operator
        } else {
            debug("parseGlobalExpression: Error - Expected @ operator, got {any}\n", .{token});
            return ParseError.UnexpectedToken;
        }
    } else {
        debug("parseGlobalExpression: Error - Unexpected end of tokens\n", .{});
        return ParseError.UnexpectedToken;
    }

    try state.processWhitespace();

    // Get the identifier after @
    if (state.currentToken()) |token| {
        debug("parseGlobalExpression: Processing token after @: {any}\n", .{token});

        switch (token) {
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
                        result.* = Expression.init(ExpressionData{ .Global = global });

                        // Mark identifier as transferred
                        ident_ptr = null;

                        // Check for chained dot operators after the function call
                        try state.processWhitespace();
                        if (state.currentToken()) |dot_token| {
                            if (dot_token == .operator and dot_token.operator == .@".") {
                                debug("parseGlobalExpression: Found dot operator after global call, parsing member access\n", .{});
                                return parseDotChain(state, result);
                            }
                        }

                        return result;
                    } else if (next_token == .operator and next_token.operator == .@"=") {
                        // Global variable assignment (e.g., @myVar = 10)
                        debug("parseGlobalExpression: Detected assignment to global '{s}'\n", .{ident});
                        try parseOperator(state, .@"=");
                        try state.processWhitespace();

                        // Parse the value expression
                        const value = try parseExpression(state);

                        // Create a global var with the assignment
                        const global = try state.allocator.create(Global);
                        global.* = Global{
                            .type = .Var, // Default to Var type for direct assignments
                            .identifier = ident, // Ownership moves here
                            .value = value,
                        };

                        const result = try state.allocator.create(Expression);
                        result.* = Expression.init(ExpressionData{ .Global = global });

                        // Mark identifier as transferred
                        ident_ptr = null;
                        return result;
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
                result.* = Expression.init(ExpressionData{ .Global = global });

                // Mark identifier as transferred
                ident_ptr = null;

                // Check for chained dot operators after the reference
                try state.processWhitespace();
                if (state.currentToken()) |dot_token| {
                    if (dot_token == .operator and dot_token.operator == .@".") {
                        debug("parseGlobalExpression: Found dot operator after global reference, parsing member access\n", .{});
                        return parseDotChain(state, result);
                    }
                }

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

// Add a helper function to parse chains of dot operators
fn parseDotChain(state: *ParserState, left_expr: *Expression) ParserError!*Expression {
    debug("parseDotChain: Starting with left expression\n", .{});

    var current_expr = left_expr;

    while (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@".") {
            _ = state.nextToken(); // Consume the dot
            try state.processWhitespace();

            // Check for * (pointer dereference)
            if (state.currentToken()) |maybe_star| {
                if (maybe_star == .operator and maybe_star.operator == .@"*") {
                    debug("parseDotChain: Found pointer dereference (.* operator)\n", .{});
                    _ = state.nextToken(); // Consume the *

                    // Create pointer dereference expression
                    const ptr_deref = try state.allocator.create(PointerDeref);
                    ptr_deref.* = PointerDeref{
                        .ptr = current_expr,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .PointerDeref = ptr_deref });
                    current_expr = result;

                    try state.processWhitespace();
                    continue;
                }
            }

            // Parse the member name (identifier)
            if (state.currentToken() == null or state.currentToken().? != .identifier) {
                debug("parseDotChain: Error - Expected identifier after dot\n", .{});
                return ParseError.ExpectedIdentifier;
            }

            const member_name = try parseIdentifier(state);
            debug("parseDotChain: Parsed member name: '{s}'\n", .{member_name});

            // Create property expression
            const property = try state.allocator.create(Property);
            property.* = Property{
                .key = member_name,
                .value = current_expr,
            };

            const result = try state.allocator.create(Expression);
            result.* = Expression.init(ExpressionData{ .Property = property });
            current_expr = result;

            try state.processWhitespace();
        } else {
            // Not a dot, end of the chain
            break;
        }
    }

    return current_expr;
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

    // Use a block expression to represent the function body if there are multiple expressions
    var body_exprs = std.ArrayList(*Expression).init(state.allocator);
    errdefer {
        for (body_exprs.items) |expr| {
            expr.deinit(state.allocator);
        }
        body_exprs.deinit();
    }

    const starting_indent = state.indentationLevel;
    debug("parseFunctionExpression: Starting indent level for body: {d}\n", .{starting_indent});

    // Parse multiple expressions in the function body
    while (state.currentToken() != null) {
        try state.processWhitespace();

        // If we've decreased indentation below the function's indent level, we're done with the body
        if (state.indentationLevel < starting_indent or state.currentToken() == null) {
            debug("parseFunctionExpression: End of function body - indentation dropped to {d}\n", .{state.indentationLevel});
            break;
        }

        // Parse the next expression in the body
        debug("parseFunctionExpression: Parsing body expression at indent {d}, token: {any}\n", .{ state.indentationLevel, state.currentToken() });

        const expr = try parseExpression(state);
        try body_exprs.append(expr);

        debug("parseFunctionExpression: Parsed body expression, now at index {d}\n", .{state.index});
        try state.processWhitespace();
    }

    debug("parseFunctionExpression: Parsed {d} expressions in body\n", .{body_exprs.items.len});

    // Create a block for the function body if there are multiple expressions
    var body: *Expression = undefined;
    if (body_exprs.items.len > 1) {
        const block = try state.allocator.create(Block);
        block.* = Block{
            .body = body_exprs,
        };

        body = try state.allocator.create(Expression);
        body.* = Expression.init(ExpressionData{ .Block = block });
        debug("parseFunctionExpression: Created Block with {d} expressions for function body\n", .{body_exprs.items.len});
    } else if (body_exprs.items.len == 1) {
        // Just use the single expression directly
        body = body_exprs.items[0];
        // Don't deinit the ArrayList since we're keeping the item
        body_exprs.deinit();
        debug("parseFunctionExpression: Using single expression for function body\n", .{});
    } else {
        // Empty function body - use unit value
        body = try createLiteralExpression(state, Value{ .unit = {} });
        body_exprs.deinit();
        debug("parseFunctionExpression: Using unit value for empty function body\n", .{});
    }

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
    result.* = Expression.init(ExpressionData{ .Function = function });
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

    // Special handling for 'else' keywords that appear outside of if-context
    if (starting_token) |token| {
        if (token == .keyword and token.keyword == .@"else" and !state.in_if_context) {
            debug("parseExpression: Found 'else' keyword outside of if-context, skipping\n", .{});
            _ = state.nextToken(); // Skip the else keyword

            // Return a unit value since we can't meaningfully process 'else' here
            return createLiteralExpression(state, Value{ .unit = {} });
        }

        // Special case for combinations like bitwise NOT (~) followed by if
        if (token == .operator and (token.operator == .@"~" or token.operator == .@"&") and
            state.index + 1 < state.tokens.len)
        {
            const op = token.operator;
            const next_token = state.tokens[state.index + 1];

            if (next_token == .keyword and next_token.keyword == .@"if") {
                debug("parseExpression: Found bitwise operator followed by if, special handling\n", .{});

                // Consume the unary operator
                _ = state.nextToken();
                try state.processWhitespace();

                // Parse the if expression
                const if_expr = try parseIfExpression(state);

                // Wrap it in a unary operation
                const unary = try state.allocator.create(Unary);
                unary.* = Unary{
                    .op = op,
                    .operand = if_expr,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Unary = unary });
                return result;
            }
        }
    }

    // Try to match pointer dereferencing pattern first by looking ahead
    // This is an optimization to avoid double parsing
    if (state.index + 2 < state.tokens.len) {
        // Look for identifier followed by dot-star pattern
        if (state.tokens[state.index] == .identifier) {
            var dot_index: ?usize = null;
            var star_index: ?usize = null;

            // Look ahead for . and then *
            var i = state.index + 1;
            var looking_for_dot = true;
            var whitespace_ok = true;

            while (i < state.tokens.len) {
                const peek_token = state.tokens[i];

                // Skip whitespace
                if (peek_token == .space or peek_token == .newline or
                    peek_token == .indent or peek_token == .comment)
                {
                    i += 1;
                    continue;
                }

                if (looking_for_dot) {
                    if (peek_token == .operator and peek_token.operator == .@".") {
                        dot_index = i;
                        looking_for_dot = false;
                        whitespace_ok = true;
                        i += 1;
                        continue;
                    } else {
                        // Not a pointer operation
                        break;
                    }
                } else {
                    // Looking for *
                    if (peek_token == .operator and peek_token.operator == .@"*") {
                        star_index = i;
                        // Found the pattern
                        debug("parseExpression: Found potential .* pattern at dot_index={?}, star_index={?}\n", .{ dot_index, star_index });
                        return parsePointerExpression(state);
                    } else {
                        // Not a pointer operation
                        break;
                    }
                }
            }
        }
    }

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
            result.* = Expression.init(ExpressionData{ .Unary = unary_node });
            return result;
        }
    }

    // Handle keywords that define the entire expression type directly
    if (state.currentToken()) |token| {
        if (token == .keyword) {
            // START Restored block
            switch (token.keyword) {
                .@"if" => return parseIfExpression(state),
                .@"while" => {
                    debug("parseExpression: Parsing while expression\n", .{});
                    return parseWhileExpression(state);
                },
                .@"for" => return parseForExpression(state),
                .@"return", .@"break", .@"continue", .@"defer" => return parseFlowExpression(state),
                .@"fn" => return parseFunctionExpression(state),
                .@"const" => return parseConstExpression(state),
                .@"var" => return parseVarExpression(state),
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
            // Global expression - handle the @ operator directly
            debug("parseExpression: Found @ operator, parsing as global expression\n", .{});
            return parseGlobalExpression(state);
        } else if (token == .identifier) {
            debug("parseExpression: Found identifier '{s}'\n", .{token.identifier});

            // Check for function call pattern (identifier followed by parenthesis)
            if (state.index + 1 < state.tokens.len and
                state.tokens[state.index + 1] == .punctuation and
                state.tokens[state.index + 1].punctuation == .@"(")
            {
                debug("parseExpression: Found potential function call for '{s}'\n", .{token.identifier});
            }

            // Check for array indexing pattern (identifier followed by '[')
            if (state.index + 1 < state.tokens.len and
                state.tokens[state.index + 1] == .punctuation and
                state.tokens[state.index + 1].punctuation == .@"[")
            {
                debug("parseExpression: Found potential array indexing for '{s}'\n", .{token.identifier});
                return parseArrayIndexExpression(state);
            }
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

                // Process this as a global expression directly
                return parseGlobalExpression(state);
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

    debug("parseExpression: Successfully evaluated RPN, result type {s}\n", .{@tagName(std.meta.activeTag(final_expr.*.data))});
    return final_expr;
}
fn evaluateRPN(state: *ParserState) ParserError!*Expression {
    debug("evaluateRPN: Starting with {d} RPN tokens\n", .{state.outputStack.items.len});

    var evalStack = std.ArrayList(*Expression).init(state.allocator);
    defer evalStack.deinit();

    for (state.outputStack.items) |expr_handle| {
        const expr = state.expressionHeap.get(expr_handle) orelse {
            return ParseError.InvalidSyntax;
        };

        switch (expr.data) {
            // For literals and variables, just push them onto the stack
            .Literal, .Variable, .Global => {
                try evalStack.append(expr);
            },

            .Operator => |op| {
                switch (op) {
                    .@"@" => {
                        if (evalStack.items.len < 1) return ParseError.InvalidSyntax;
                        const ident_expr = evalStack.pop();

                        if (ident_expr) |innerExpr| {
                            if (innerExpr.data != .Variable) {
                                return ParseError.InvalidSyntax;
                            }
                            
                            const global = try state.allocator.create(Global);
                            errdefer state.allocator.destroy(global);

                            // Create new copy of identifier for global
                            const ident_copy = try state.allocator.dupe(u8, innerExpr.data.Variable.identifier);
                            errdefer state.allocator.free(ident_copy);

                            global.* = Global{
                                .type = .Reference,
                                .identifier = ident_copy,
                                .value = null,
                                .arguments = null,
                            };

                            const result = try state.allocator.create(Expression);
                            errdefer state.allocator.destroy(result);
                            result.* = Expression.init(ExpressionData{ .Global = global });

                            try evalStack.append(result);
                        } else {
                            return ParseError.InvalidSyntax;
                        }
                    },

                    .@"&", .@"~", .@"!", .@"*" => {
                        if (evalStack.items.len < 1) return ParseError.InvalidSyntax;
                        const operand = evalStack.pop();

                        const unary = try state.allocator.create(Unary);
                        errdefer state.allocator.destroy(unary);

                        unary.* = Unary{
                            .op = op,
                            .operand = operand orelse return ParseError.InvalidSyntax,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Unary = unary });

                        try evalStack.append(result);
                    },

                    .@"=", .@"+=" , .@"-=", .@"*=", .@"/=" => {
                        if (evalStack.items.len < 2) return ParseError.InvalidSyntax;
                        const right = evalStack.pop();
                        const left = evalStack.pop();

                        const binary = try state.allocator.create(Binary);
                        errdefer state.allocator.destroy(binary);

                        binary.* = Binary{
                            .op = op,
                            .left = left orelse return ParseError.InvalidSyntax,
                            .right = right orelse return ParseError.InvalidSyntax,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Binary = binary });

                        try evalStack.append(result);
                    },

                    .@"<<", .@">>" => {
                        if (evalStack.items.len < 2) return ParseError.InvalidSyntax;
                        const right = evalStack.pop();
                        const left = evalStack.pop();

                        const binary = try state.allocator.create(Binary);
                        errdefer state.allocator.destroy(binary);

                        binary.* = Binary{
                            .op = op,
                            .left = left orelse return ParseError.InvalidSyntax,
                            .right = right orelse return ParseError.InvalidSyntax,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Binary = binary });

                        try evalStack.append(result);
                    },

                    else => {
                        if (evalStack.items.len < 2) return ParseError.InvalidSyntax;
                        const right = evalStack.pop();
                        const left = evalStack.pop();

                        const binary = try state.allocator.create(Binary);
                        errdefer state.allocator.destroy(binary);

                        binary.* = Binary{
                            .op = op,
                            .left = left orelse return ParseError.InvalidSyntax,
                            .right = right orelse return ParseError.InvalidSyntax,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Binary = binary });

                        try evalStack.append(result);
                    },
                }
            },

            else => {
                try evalStack.append(expr);
            },
        }
    }

    if (evalStack.items.len == 1) {
        const final_expr = evalStack.pop();
        const result = final_expr orelse return ParseError.InvalidSyntax;
        return result;
    }

    return ParseError.InvalidSyntax;
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
    var last_index: usize = 0; // Track the last processed index to detect loops
    var repeat_count: usize = 0; // Count repeated processing of the same index

    while (state.currentToken() != null) {
        try state.processWhitespace();
        if (state.currentToken() == null) break;

        const loop_start_index = state.index;
        debug("parse: Loop iteration start. Index: {d}, Token: {any}\n", .{ loop_start_index, state.currentToken() });

        // Safety check to prevent infinite loops
        if (loop_start_index == last_index) {
            repeat_count += 1;
            if (repeat_count > 3) {
                debug("parse: Detected potential infinite loop at index {d}, token: {any}\n", .{ loop_start_index, state.currentToken() });

                // Force advance the index to break the loop
                state.index += 1;
                if (state.index >= state.tokens.len) break;

                // Reset the repeat counter
                repeat_count = 0;
                continue;
            }
        } else {
            repeat_count = 0;
        }
        last_index = loop_start_index;

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

            // Special handling for array indexing
            if (curr_token == .punctuation and curr_token.punctuation == .@"[") {
                debug("parse: Found array indexing token at top level\n", .{});

                // Create a fresh state for parsing this expression
                var array_index_state = try ParserState.init(allocator, state.tokens[state.index..]);
                defer array_index_state.deinit();
                array_index_state.indentationLevel = state.indentationLevel;

                // Try to parse as array indexing
                debug("parse: Attempting to parse as array index\n", .{});
                const array_expr = try parseArrayIndexExpression(&array_index_state);
                try results.append(array_expr);

                // Update main state index
                const pre_update_index = state.index;
                state.index += array_index_state.index;
                debug("parse: Array indexing parsing advanced index from {d} to {d} ({d} tokens)\n", .{ pre_update_index, state.index, state.index - pre_update_index });

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
                    debug("parse: Converting function '{s}' to global function\n", .{if (func_expr.data == .Function) func_expr.data.Function.identifier else "unknown"});

                    if (func_expr.data == .Function) {
                        // Create global function wrapper
                        const global = try allocator.create(Global);
                        global.* = Global{
                            .type = .Fn,
                            .identifier = try allocator.dupe(u8, func_expr.data.Function.identifier),
                            .value = func_expr,
                            .arguments = null,
                        };

                        const global_expr = try allocator.create(Expression);
                        global_expr.* = Expression.init(ExpressionData{ .Global = global });

                        // Add the global function expression to results
                        try results.append(global_expr);
                    } else {
                        // If not a function (shouldn't happen), add as-is
                        try results.append(func_expr);
                    }
                } else {
                    // Regular function (not global)
                    try results.append(func_expr);
                }

                // Continue to next iteration - we've handled this function
                continue;
            } else if (curr_token == .keyword) {
                // For other keywords like while, if, for, etc., parse them as expressions
                debug("parse: Found keyword {s} at index {d}\n", .{ @tagName(curr_token.keyword), state.index });
                const expr = try parseExpression(&state);
                try results.append(expr);
                continue;
            } else if (curr_token == .identifier) {
                // Check if this identifier might be a function call
                if (state.index + 1 < state.tokens.len and
                    state.tokens[state.index + 1] == .punctuation and
                    state.tokens[state.index + 1].punctuation == .@"(")
                {
                    debug("parse: Found potential function call for '{s}'\n", .{curr_token.identifier});
                }

                // Parse as a normal expression
                const expr = try parseExpression(&state);
                try results.append(expr);
                continue;
            }
        }

        // Try to parse a regular expression if no special handling applied
        debug("parse: Parsing general expression at index {d}\n", .{state.index});

        // Create a fresh state for this expression to avoid state contamination
        var expr_state = try ParserState.init(allocator, state.tokens[state.index..]);
        defer expr_state.deinit();
        expr_state.indentationLevel = state.indentationLevel;

        const expr = try parseExpression(&expr_state);
        try results.append(expr);

        // Update the main state's index
        const pre_update_index = state.index;
        state.index += expr_state.index;
        debug("parse: Expression parsing advanced index from {d} to {d} ({d} tokens)\n", .{ pre_update_index, state.index, state.index - pre_update_index });

        expr_count += 1;
    }

    debug("parse: Completed with {d} expressions\n", .{results.items.len});
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
    result.* = Expression.init(ExpressionData{ .Literal = value });
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
    // Set a flag that we're in an inline if expression to help with parsing
    condition_state.in_inline_if = true;

    const condition = try parseExpression(&condition_state);
    errdefer condition.deinit(state.allocator);

    // Update state index
    state.index += condition_state.index;

    try state.processWhitespace();

    // Parse the body (the true branch)
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;
    // Set a flag that we're in an inline if expression body
    body_state.in_inline_if = true;

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
            // Set a flag that we're in an inline if expression else branch
            else_state.in_inline_if = true;

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
    result.* = Expression.init(ExpressionData{ .Conditional = conditional });
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
    debug("parseWhileExpression: Parsed condition, new index {d}\n", .{state.index});

    // Check for tail expression (after ':')
    var tail_expression: ?*Expression = null;
    errdefer if (tail_expression) |t| t.deinit(state.allocator);

    try state.processWhitespace();

    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@":") {
            debug("parseWhileExpression: Found tail expression marker ':'\n", .{});
            _ = state.nextToken(); // consume ':'
            try state.processWhitespace();

            // Parse tail expression
            var tail_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            defer tail_state.deinit();
            tail_state.indentationLevel = state.indentationLevel;

            tail_expression = try parseExpression(&tail_state);
            debug("parseWhileExpression: Parsed tail expression\n", .{});

            // Update state index
            state.index += tail_state.index;
        }
    }

    try state.processWhitespace();

    // Parse body
    debug("parseWhileExpression: Parsing body with indentation level {d}\n", .{state.indentationLevel});
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();
    body_state.indentationLevel = state.indentationLevel;

    const body = try parseExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update state index
    state.index += body_state.index;
    debug("parseWhileExpression: Parsed body, new index {d}\n", .{state.index});

    // Create loop expression
    const loop = try state.allocator.create(Loop);
    loop.* = Loop{
        .type = .While,
        .condition = condition,
        .body = body,
        .tail_expression = tail_expression,
    };

    const result = try state.allocator.create(Expression);
    result.* = Expression.init(ExpressionData{ .Loop = loop });
    debug("parseWhileExpression: Created Loop node\n", .{});
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
        loop_expr.* = Expression.init(ExpressionData{ .Loop = loop });

        // Add the loop to the block
        try block_items.append(loop_expr);

        // Create the block
        const block = try state.allocator.create(Block);
        block.* = Block{
            .body = block_items,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Block = block });
        return result;
    } else {
        // Only the condition, no initialization
        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Loop = loop });
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
    result.* = Expression.init(ExpressionData{ .Flow = flow });
    return result;
}

fn parseShuntingYard(state: *ParserState) ParserError!void {
    var in_array_index = false;
    var paren_depth: usize = 0;
    var in_global_call = false;

    while (state.currentToken()) |token| {

        switch (token) {
            .identifier => {
                const ident = try state.allocator.dupe(u8, token.identifier);
                const variable = try state.allocator.create(Variable);
                variable.* = Variable{
                    .identifier = ident,
                    .value = .{ .unit = {} },
                };
                const expr = Expression.init(.{ .Variable = variable });
                const expr_handle = try state.expressionHeap.allocate(expr);
                try state.outputStack.append(expr_handle);
                _ = state.nextToken();
            },

            .literal => |lit| {
                const expr_handle = try state.expressionHeap.allocate(Expression.init(.{ .Literal = lit }));
                try state.outputStack.append(expr_handle);
                _ = state.nextToken();
            },

            .operator => |op| {
                // Handle @ operator specially
                if (op == .@"@") {
                    // Look ahead for function call pattern
                    if (state.index + 2 < state.tokens.len and
                        state.tokens[state.index + 1] == .identifier and
                        state.tokens[state.index + 2] == .punctuation and
                        state.tokens[state.index + 2].punctuation == .@"(")
                    {
                        in_global_call = true;
                        const global_expr = try parseGlobalExpression(state);
                        const expr_handle = try state.expressionHeap.allocate(global_expr.*);
                        try state.outputStack.append(expr_handle);
                        continue;
                    }
                }

                // Handle binary operators
                while (state.operatorStack.items.len > 0) {
                    const top_handle = state.operatorStack.items[state.operatorStack.items.len - 1];
                    
                    // Validate handle
                    if (top_handle >= state.expressionHeap.expressions.items.len) {
                        return ParseError.InvalidSyntax;
                    }
                    
                    const top_expr = state.expressionHeap.get(top_handle) orelse {
                        return ParseError.InvalidSyntax;
                    };

                    if (top_expr.*.data == .Operator and
                        !in_global_call and
                        top_expr.*.data.Operator.precedence() >= op.precedence())
                    {
                        _ = state.operatorStack.pop();
                        try state.outputStack.append(top_handle);
                    } else break;
                }

                const op_handle = try state.expressionHeap.allocate(Expression.init(.{ .Operator = op }));
                try state.operatorStack.append(op_handle);
                _ = state.nextToken();
            },

            .punctuation => |p| {
                switch (p) {
                    .@"[" => {
                        in_array_index = true;
                        const marker = try state.expressionHeap.createParenMarker();
                        try state.operatorStack.append(marker);
                        _ = state.nextToken();
                    },

                    .@"]" => {
                        if (!in_array_index) break;

                        // Pop everything until matching [
                        while (state.operatorStack.items.len > 0) {
                            const op_handle = state.operatorStack.pop().?;
                            if (state.expressionHeap.isParenMarker(op_handle)) break;
                            try state.outputStack.append(op_handle);
                        }

                        in_array_index = false;
                        _ = state.nextToken();
                    },

                    .@"(" => {
                        paren_depth += 1;
                        const marker = try state.expressionHeap.createParenMarker();
                        try state.operatorStack.append(marker);
                        _ = state.nextToken();
                    },

                    .@")" => {
                        if (paren_depth == 0) break;

                        // Pop until matching (
                        while (state.operatorStack.items.len > 0) {
                            const op_handle = state.operatorStack.pop().?;
                            if (state.expressionHeap.isParenMarker(op_handle)) break;
                            try state.outputStack.append(op_handle);
                        }

                        paren_depth -= 1;
                        if (in_global_call and paren_depth == 0) {
                            in_global_call = false;
                        }
                        _ = state.nextToken();
                    },

                    .@"," => {
                        if (!in_array_index and !in_global_call) break;

                        // Pop operators until ( or [
                        while (state.operatorStack.items.len > 0) {
                            const top_handle = state.operatorStack.items[state.operatorStack.items.len - 1];
                            if (state.expressionHeap.isParenMarker(top_handle)) break;
                            _ = state.operatorStack.pop();
                            try state.outputStack.append(top_handle);
                        }
                        _ = state.nextToken();
                    },

                    else => {},
                }
            },

            .space, .indent, .comment => _ = state.nextToken(),

            else => if (!in_array_index and !in_global_call) break,
        }

        try state.processWhitespace();
    }

    // Handle any remaining operators
    while (state.operatorStack.items.len > 0) {
        const op_handle = state.operatorStack.pop().?;
        if (!state.expressionHeap.isParenMarker(op_handle)) {
            try state.outputStack.append(op_handle);
        }
    }
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
    } else {
        debug("parseArgumentList: Unexpected end of tokens (no closing parenthesis)\n", .{});
        return ParseError.UnterminatedExpression;
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

                // Check if there's an immediate closing parenthesis after the comma (trailing comma case)
                if (state.currentToken()) |next_token| {
                    if (next_token == .punctuation and next_token.punctuation == .@")") {
                        _ = state.nextToken(); // consume closing parenthesis
                        break;
                    }
                }

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
    // This function is replaced by the more flexible parsePointerExpression
    return parsePointerExpression(state);
}

// Add this new function to handle pointer operations (both deref and member access)
fn parsePointerExpression(state: *ParserState) ParserError!*Expression {
    debug("parsePointerExpression: Starting\n", .{});

    // Parse the pointer expression
    var identifier_only = true;
    var ptr_expr: ?*Expression = null;
    errdefer if (ptr_expr) |expr| expr.deinit(state.allocator);

    if (state.currentToken()) |token| {
        if (token == .identifier) {
            // Create a variable expression for the identifier
            const ident = try state.allocator.dupe(u8, token.identifier);
            const variable = try state.allocator.create(Variable);
            variable.* = Variable{
                .identifier = ident,
                .value = .{ .unit = {} },
            };

            ptr_expr = try state.allocator.create(Expression);
            ptr_expr.?.* = Expression.init(ExpressionData{ .Variable = variable });
            _ = state.nextToken(); // consume identifier
        } else {
            // Try parsing a more complex expression
            identifier_only = false;
            try state.processWhitespace();

            // Use shunting yard to parse a more complex primary expression
            const old_output_stack = state.outputStack;
            state.outputStack = std.ArrayList(usize).init(state.allocator);
            defer {
                state.outputStack.deinit();
                state.outputStack = old_output_stack;
            }

            try parseShuntingYard(state);
            if (state.outputStack.items.len > 0) {
                const primary = try evaluateRPN(state);
                ptr_expr = primary;
            } else {
                debug("parsePointerExpression: Error - Failed to parse pointer expression\n", .{});
                return ParseError.UnexpectedToken;
            }
        }
    } else {
        debug("parsePointerExpression: Error - Expected token for pointer\n", .{});
        return ParseError.UnexpectedToken;
    }

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

                    // Now determine if this is a member access or a dereference
                    if (state.currentToken()) |next_token| {
                        if (next_token == .identifier) {
                            // This is a pointer member access (ptr.* member)
                            const member = try parseIdentifier(state);
                            errdefer state.allocator.free(member);

                            // Create the pointer member expression
                            const ptr_member = try state.allocator.create(PointerMember);
                            ptr_member.* = PointerMember{
                                .object = ptr_expr.?,
                                .member = member,
                            };

                            const result = try state.allocator.create(Expression);
                            result.* = Expression.init(ExpressionData{ .PointerMember = ptr_member });
                            debug("parsePointerExpression: Created PointerMember for object->'{s}'\n", .{member});
                            return result;
                        } else {
                            // This is a simple pointer dereference (ptr.*)
                            // Create the pointer dereference expression
                            const ptr_deref = try state.allocator.create(PointerDeref);
                            ptr_deref.* = PointerDeref{
                                .ptr = ptr_expr.?,
                            };

                            const result = try state.allocator.create(Expression);
                            result.* = Expression.init(.{ .PointerDeref = ptr_deref });
                            debug("parsePointerExpression: Created PointerDeref\n", .{});

                            // Check if an assignment follows this dereference
                            // We need to handle this specially to avoid the infinite loop issue
                            if (state.currentToken()) |next| {
                                if (next == .operator and next.operator == .@"=") {
                                    debug("parsePointerExpression: Found assignment after dereference\n", .{});
                                    // Don't advance token here - let the expression parser handle the assignment
                                }
                            }

                            return result;
                        }
                    } else {
                        // EOF after .* - treat as dereference
                        const ptr_deref = try state.allocator.create(PointerDeref);
                        ptr_deref.* = PointerDeref{
                            .ptr = ptr_expr.?,
                        };

                        const result = try state.allocator.create(Expression);
                        result.* = Expression.init(.{ .PointerDeref = ptr_deref });
                        debug("parsePointerExpression: Created PointerDeref at EOF\n", .{});
                        return result;
                    }
                }
            }
        }
    }

    // If we reached here, it's not a pointer expression
    // Just return the original expression we parsed
    return ptr_expr.?;
}

// Function to parse a const expression (const x = expr) with support for global references
fn parseConstExpression(state: *ParserState) ParserError!*Expression {
    debug("parseConstExpression: Starting\n", .{});

    // Consume 'const' keyword
    try parseKeyword(state, .@"const");
    try state.processWhitespace();

    // Check if this is a global reference declaration (const @identifier = ...)
    var is_global = false;
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"@") {
            is_global = true;
            debug("parseConstExpression: Found global reference declaration (@)\n", .{});
            _ = state.nextToken(); // consume @ symbol
            try state.processWhitespace();
        }
    }

    // Parse the identifier
    const ident = try parseIdentifier(state);
    errdefer state.allocator.free(ident);
    try state.processWhitespace();

    // Check for and require the = operator for const declarations
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"=") {
            _ = state.nextToken(); // consume =
            try state.processWhitespace();

            // Parse the value expression
            const value = try parseExpression(state);

            if (is_global) {
                // Create a Global expression for a global constant
                debug("parseConstExpression: Creating global const '{s}'\n", .{ident});
                const global = try state.allocator.create(Global);
                global.* = Global{
                    .type = .Const,
                    .identifier = ident,
                    .value = value,
                    .arguments = null,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Global = global });
                return result;
            } else {
                // Create a regular Const expression
                debug("parseConstExpression: Creating local const '{s}'\n", .{ident});
                const const_expr = try state.allocator.create(Const);
                const_expr.* = Const{
                    .identifier = ident,
                    .value = value,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Const = const_expr });
                return result;
            }
        }
    }

    // If there's no assignment, create a declaration without value
    // This is an error for const, but we'll return it anyway and let semantic analysis handle it
    debug("parseConstExpression: Warning - const declaration without initializer\n", .{});

    // Create a placeholder value (unit)
    const unit_value = try createLiteralExpression(state, Value{ .unit = {} });

    if (is_global) {
        // Create a Global expression without a value
        debug("parseConstExpression: Creating global const '{s}' without initializer\n", .{ident});
        const global = try state.allocator.create(Global);
        global.* = Global{
            .type = .Const,
            .identifier = ident,
            .value = unit_value,
            .arguments = null,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(.{ .Global = global });
        return result;
    } else {
        // Create a regular Decl expression without a value
        debug("parseConstExpression: Creating local const '{s}' without initializer\n", .{ident});
        const decl_expr = try state.allocator.create(Decl);
        decl_expr.* = Decl{
            .identifier = ident,
            .value = unit_value,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Decl = decl_expr });
        return result;
    }
}

// Function to parse a var expression (var x = expr) with support for global references
fn parseVarExpression(state: *ParserState) ParserError!*Expression {
    debug("parseVarExpression: Starting\n", .{});

    // Consume 'var' keyword
    try parseKeyword(state, .@"var");
    try state.processWhitespace();

    // Check if this is a global reference declaration (var @identifier = ...)
    var is_global = false;
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"@") {
            is_global = true;
            debug("parseVarExpression: Found global reference declaration (@)\n", .{});
            _ = state.nextToken(); // consume @ symbol
            try state.processWhitespace();
        }
    }

    // Parse the identifier
    const ident = try parseIdentifier(state);
    errdefer state.allocator.free(ident);
    try state.processWhitespace();

    // Check for and parse the = operator
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"=") {
            _ = state.nextToken(); // consume =
            try state.processWhitespace();

            // Parse the value expression
            const value = try parseExpression(state);

            if (is_global) {
                // Create a Global expression for a global variable
                debug("parseVarExpression: Creating global var '{s}'\n", .{ident});
                const global = try state.allocator.create(Global);
                global.* = Global{
                    .type = .Var,
                    .identifier = ident,
                    .value = value,
                    .arguments = null,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Global = global });
                return result;
            } else {
                // Create a Var expression with an initial value
                debug("parseVarExpression: Creating local var '{s}'\n", .{ident});
                const var_expr = try state.allocator.create(Var);
                var_expr.* = Var{
                    .identifier = ident,
                    .value = value,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Var = var_expr });
                return result;
            }
        }
    }

    // If there's no assignment, create a Var expression with a unit value
    debug("parseVarExpression: Creating var declaration without initializer\n", .{});

    // Create a placeholder value (unit)
    const unit_value = try createLiteralExpression(state, Value{ .unit = {} });

    if (is_global) {
        // Create a Global expression without an initial value
        debug("parseVarExpression: Creating global var '{s}' without initializer\n", .{ident});
        const global = try state.allocator.create(Global);
        global.* = Global{
            .type = .Var,
            .identifier = ident,
            .value = unit_value,
            .arguments = null,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(.{ .Global = global });
        return result;
    } else {
        // Create a local Var expression without an initial value
        debug("parseVarExpression: Creating local var '{s}' without initializer\n", .{ident});
        const var_expr = try state.allocator.create(Var);
        var_expr.* = Var{
            .identifier = ident,
            .value = unit_value,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(.{ .Var = var_expr });
        return result;
    }
}

// Add this function after the parsePointerExpression function
fn parseArrayIndexExpression(state: *ParserState) ParserError!*Expression {
    debug("parseArrayIndexExpression: Starting\n", .{});

    // Parse the array expression (identifier or complex expression)
    const array_expr = try parseExpression(state);

    try state.processWhitespace();

    // Check for '[' operator
    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@"[") {
            _ = state.nextToken(); // consume '['
            debug("parseArrayIndexExpression: Found opening '[' for array index\n", .{});
            try state.processWhitespace();

            // Parse the index expression
            const index_expr = try parseExpression(state);
            try state.processWhitespace();

            // Check for ']' to close the index
            if (state.currentToken()) |close_token| {
                if (close_token == .punctuation and close_token.punctuation == .@"]") {
                    _ = state.nextToken(); // consume ']'
                    debug("parseArrayIndexExpression: Found closing ']' for array index\n", .{});

                    // Create the index expression
                    const index = try state.allocator.create(Index);
                    index.* = Index{
                        .array = array_expr,
                        .index = index_expr,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .Index = index });
                    return result;
                } else {
                    debug("parseArrayIndexExpression: Error - Expected ']' to close array index, got {any}\n", .{close_token});
                    return ParseError.UnterminatedExpression;
                }
            } else {
                debug("parseArrayIndexExpression: Error - Unexpected end of tokens while parsing array index\n", .{});
                return ParseError.UnterminatedExpression;
            }
        }
    }

    // If we reach here, it's not an array index expression
    // Just return the original expression we parsed
    return array_expr;
}
