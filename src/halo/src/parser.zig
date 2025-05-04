pub const std = @import("std");
pub const Value = @import("value.zig").Value;
pub const Operator = @import("lexer.zig").Operator;
pub const Token = @import("lexer.zig").Token;
pub const Keyword = @import("lexer.zig").Keyword;
pub const Punctuation = @import("lexer.zig").Punctuation;
pub const operator_utils = @import("operator_utils.zig");

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
        if (self.ref_count == 0) {
            debug("Expression.deinit: Warning - Attempting to decrement ref_count when it's already 0\n", .{});
            return; // Prevent integer underflow
        }

        self.ref_count -= 1;
        if (self.ref_count == 0) {
            // Prevent potential infinite recursion by setting a sentinel value
            self.ref_count = std.math.maxInt(usize);

            // Only now call the internal deinit method
            self.data.deinit(allocator);
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

    pub fn deinit(self: ExpressionData, allocator: std.mem.Allocator) void {
        switch (self) {
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
                for (c.arguments.items) |arg| {
                    arg.deinit(allocator);
                }
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

    // Add a method to check if this binary operation involves conditionals
    pub fn hasConditional(self: *const Binary) bool {
        return self.left.data == .Conditional or self.right.data == .Conditional;
    }
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
    UnexpectedEndOfTokens,
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

// Add comprehensive context flag definitions
const ContextFlag = enum(u32) {
    // Control flow contexts
    IfContext = 0,
    ElseContext = 1,
    WhileContext = 2,
    ForContext = 3,
    SwitchContext = 4,
    CaseContext = 5,
    MatchContext = 6,

    // Expression contexts
    Inline = 7,
    UnaryContext = 8,
    BinaryContext = 9,
    TernaryContext = 10,
    ExpressionContext = 11,
    ParenContext = 12,

    // Function and scope contexts
    FunctionContext = 13,
    BlockContext = 14,
    ArgumentContext = 15,
    ParameterContext = 16,
    LambdaContext = 17,

    // Object and data structure contexts
    ObjectContext = 18,
    PropertyContext = 19,
    ArrayContext = 20,
    TensorContext = 21,
    IndexContext = 22,
    RangeContext = 23,

    // Memory and reference contexts
    PointerContext = 24,
    ReferenceContext = 25,
    DereferenceContext = 26,
    MemoryContext = 27,
    AddressContext = 28,

    // Operator contexts
    DotContext = 29,
    AssignmentContext = 30,
    CompoundAssignContext = 31,
    LogicalOpContext = 32,
    BitwiseOpContext = 33,
    ComparisonContext = 124, // Add the missing ComparisonContext with a high enough index

    // Declaration contexts
    GlobalContext = 34,
    DeclContext = 35,
    VarContext = 36,
    ConstContext = 37,
    TypeContext = 38,
    ImportContext = 39,

    // Flow control contexts
    ReturnContext = 40,
    BreakContext = 41,
    ContinueContext = 42,
    DeferContext = 43,
    ThrowContext = 44,
    TryContext = 45,
    CatchContext = 46,

    // Pattern matching contexts
    PatternContext = 47,
    DestructureContext = 48,

    // Loop contexts
    LoopLabelContext = 49,
    ForInContext = 50,
    ForEachContext = 51,
    IteratorContext = 52,

    // Module and namespace contexts
    ModuleContext = 53,
    NamespaceContext = 54,
    PublicContext = 55,
    PrivateContext = 56,

    // Error handling contexts
    ErrorContext = 57,
    RecoveryContext = 58,

    // Optimization contexts
    InlineContext = 59,
    CompileTimeContext = 60,

    // Metaprogramming contexts
    MacroContext = 61,
    CodeGenContext = 62,

    // Concurrency contexts
    AsyncContext = 63,
    AwaitContext = 64,
    ThreadContext = 65,

    // State tracking for complex expressions
    ExpansionContext = 66,
    SpreadContext = 67,
    RestContext = 68,

    // String and comment contexts
    StringContext = 69,
    CommentContext = 70,
    DocCommentContext = 71,

    // Attribute contexts
    AttributeContext = 72,
    AnnotationContext = 73,

    // Type contexts
    GenericContext = 74,
    ConstraintContext = 75,
    TraitContext = 76,

    // Preprocessor contexts
    PreprocessorContext = 77,
    ConditionalCompilationContext = 78,

    // Special syntax contexts
    InterpolationContext = 79,
    TemplateLiteralContext = 80,
    EnumContext = 81,
    StructContext = 82,
    UnionContext = 83,
    InterfaceContext = 84,

    // Semantic contexts
    StaticContext = 85,
    DynamicContext = 86,
    MutableContext = 87,
    ImmutableContext = 88,

    // Safety contexts
    UnsafeContext = 89,
    SafeContext = 90,

    // Extra contexts for specific language features
    ChannelContext = 91,
    SelectContext = 92,
    CoroutineContext = 93,
    YieldContext = 94,
    ClosureContext = 95,

    // Debugging contexts
    DebugContext = 96,
    TraceContext = 97,

    // Memory management contexts
    AllocContext = 98,
    DeallocContext = 99,

    // Performance and optimization
    NoInlineContext = 100,
    OptLevelContext = 101,

    // Additional parsing contexts to handle edge cases
    AmbiguousContext = 102,
    ErrorRecoveryContext = 103,

    // Compiler directives
    PragmaContext = 104,
    DirectiveContext = 105,

    // Additional required contexts
    LoopContext = 106,
    ArithmeticContext = 107,
    ShiftContext = 108,
    FlowContext = 109,
    CallContext = 110,
    ConditionContext = 111,
    TailContext = 112,
    LoopBodyContext = 113,

    // Reserved for future expansion
    AllowNestedExpressions = 114, // Allow complex nested expressions in block contexts
    Reserved2 = 115,
    Reserved3 = 116,
    Reserved4 = 117,
    Reserved5 = 118,

    // User-defined contexts (for language extensions)
    UserContext1 = 119,
    UserContext2 = 120,
    UserContext3 = 121,
    UserContext4 = 122,
    UserContext5 = 123,

    pub fn getMask(self: ContextFlag) u512 {
        // Use @as(u9, @truncate()) to convert the u32 enum value to u9 for shifting
        return @as(u512, 1) << @as(u9, @truncate(@intFromEnum(self)));
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
        .context = 0, // Bitmap for tracking context flags
        .statement_indent_level = 0, // Generic tracking of statement indentation levels
    };
}

// Helper function to get the contextual precedence of an operator
fn getContextualPrecedence(op: Operator, context: u512) u8 {
    return operator_utils.getContextualPrecedence(op, context);
}

// Function to determine if an operator is a pointer dereference in the current context
fn isPointerDereference(op: Operator, context: u512) bool {
    return operator_utils.isPointerDereference(op, context);
}

// Function to determine if an operator is a pointer reference in the current context
fn isPointerReference(op: Operator, context: u512) bool {
    return operator_utils.isPointerReference(op, context);
}

fn evaluateBinaryOperation(state: *ParserState, left: *Expression, right: *Expression, op: Operator) !*Expression {
    debug("evaluateBinaryOperation: Creating Binary node for {s}\\n", .{@tagName(op)});

    // Set appropriate context flags based on operator type
    state.setContext(.BinaryContext);
    state.setContext(.ExpressionContext);

    // Set operator-specific context flags
    switch (op) {
        .@"=" => state.setContext(.AssignmentContext),
        .@"+", .@"-", .@"/", .@"%" => state.setContext(.ArithmeticContext),
        .@"&", .@"|", .@"^" => state.setContext(.BitwiseOpContext),
        .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=" => state.setContext(.ComparisonContext),
        .@"<<", .@">>" => {
            state.setContext(.BitwiseOpContext);
            state.setContext(.ShiftContext);
        },
        .@"and", .@"or" => state.setContext(.LogicalOpContext),
        .@"!" => state.setContext(.LogicalOpContext),
        .@"~" => state.setContext(.BitwiseOpContext),
        .@"*" => {
            // Determine context for * operator based on surrounding tokens
            var is_deref = false;

            // Check if preceded by a dot (ptr.*)
            if (state.index > 1) {
                const prev_token = state.tokens[state.index - 1];
                if (prev_token == .operator and prev_token.operator == .@".") {
                    is_deref = true;
                }
            }

            if (is_deref) {
                state.setContext(.PointerContext);
                state.setContext(.DereferenceContext);
            } else {
                state.setContext(.ArithmeticContext);
            }
        },
        .@"&" => {
            // Determine context for & operator based on spacing
            var is_address = false;

            // Check for right space - if no right space, it's likely addressing
            if (state.index + 1 < state.tokens.len) {
                const next_token = state.tokens[state.index + 1];
                if (next_token != .space) {
                    is_address = true;
                }
            }

            if (is_address) {
                state.setContext(.PointerContext);
                state.setContext(.AddressContext);
            } else {
                state.setContext(.BitwiseOpContext);
            }
        },
        else => {},
    }

    defer {
        state.clearContext(.BinaryContext);
        state.clearContext(.ExpressionContext);
        state.clearContext(.AssignmentContext);
        state.clearContext(.ArithmeticContext);
        state.clearContext(.BitwiseOpContext);
        state.clearContext(.ComparisonContext);
        state.clearContext(.ShiftContext);
        state.clearContext(.LogicalOpContext);
        // Removed clearing of Pointer/Dereference/Address contexts here
        // as they might be needed by subsequent operations in evaluateRPN
    }

    // Special handling for conditional expressions (SIMPLIFIED)
    // If either operand is a Conditional node, just proceed.
    // The Conditional node should already be fully parsed by parseIfExpression.
    if (left.data == .Conditional or right.data == .Conditional) {
        debug("evaluateBinaryOperation: Operands include conditional node(s) for operator {s}\\n", .{@tagName(op)});
        // No special lookahead or parsing needed here anymore.
        // Set IfContext just in case, though its primary use is in parseIfExpression
        state.setContext(.IfContext);
        defer state.clearContext(.IfContext);
    }

    // Special case for pointer dereference assignment (SIMPLIFIED)
    if (op == .@"=" and left.data == .PointerDeref) {
        debug("evaluateBinaryOperation: Assignment to pointer dereference\\n", .{});
        // Context setting might still be useful for semantic analysis later
        state.setContext(.PointerContext);
        state.setContext(.DereferenceContext);
        defer {
            state.clearContext(.PointerContext);
            state.clearContext(.DereferenceContext);
        }
    }

    // Create the Binary expression
    const binary = try state.allocator.create(Binary);
    errdefer state.allocator.destroy(binary);

    binary.* = Binary{
        .op = op,
        .left = left,
        .right = right,
    };

    const result = try state.allocator.create(Expression);
    errdefer state.allocator.destroy(result);
    result.* = Expression.init(ExpressionData{ .Binary = binary });

    return result;
}

fn handleUnaryConditionalOp(unary_op: Operator, expr: *Expression, state: *ParserState) !*Expression {
    if (expr.data == .Conditional) {
        debug("handleUnaryConditionalOp: Handling unary {s} with conditional expression\n", .{@tagName(unary_op)});

        // Create unary wrapper around the conditional expression
        const unary_node = try state.allocator.create(Unary);
        unary_node.* = Unary{
            .op = unary_op,
            .operand = expr,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Unary = unary_node });
        return result;
    } else {
        // Standard unary handling for non-conditionals
        const unary_node = try state.allocator.create(Unary);
        unary_node.* = Unary{
            .op = unary_op,
            .operand = expr,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Unary = unary_node });
        return result;
    }
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
    context: u512 = 0, // Bitmap for tracking context flags
    statement_indent_level: usize = 0, // Generic tracking of statement indentation levels

    pub fn init(allocator: std.mem.Allocator, tokens: []const Token) std.mem.Allocator.Error!ParserState {
        return initParserState(allocator, tokens);
    }

    pub fn deinit(self: *ParserState) void {
        self.operatorStack.deinit();
        self.outputStack.deinit();
        self.expressionHeap.deinit();
    }

    // Helper functions for context management
    pub fn hasContext(self: *const ParserState, flag: ContextFlag) bool {
        return (self.context & flag.getMask()) != 0;
    }

    pub fn setContext(self: *ParserState, flag: ContextFlag) void {
        self.context |= flag.getMask();
    }

    pub fn clearContext(self: *ParserState, flag: ContextFlag) void {
        self.context &= ~flag.getMask();
    }

    pub fn toggleContext(self: *ParserState, flag: ContextFlag) void {
        self.context ^= flag.getMask();
    }

    // Helper to copy context from another state
    pub fn copyContextFrom(self: *ParserState, other: *const ParserState) void {
        self.context = other.context;
    }

    // Convenience methods for specific contexts
    pub fn inIfContext(self: *const ParserState) bool {
        return self.hasContext(.IfContext);
    }

    pub fn inUnaryContext(self: *const ParserState) bool {
        return self.hasContext(.UnaryContext);
    }

    pub fn inBinaryContext(self: *const ParserState) bool {
        return self.hasContext(.BinaryContext);
    }

    pub fn inElseContext(self: *const ParserState) bool {
        return self.hasContext(.ElseContext);
    }

    pub fn inWhileContext(self: *const ParserState) bool {
        return self.hasContext(.WhileContext);
    }

    pub fn inForContext(self: *const ParserState) bool {
        return self.hasContext(.ForContext);
    }

    pub fn inLoopContext(self: *const ParserState) bool {
        return self.hasContext(.WhileContext) or self.hasContext(.ForContext);
    }

    pub fn inFunctionContext(self: *const ParserState) bool {
        return self.hasContext(.FunctionContext);
    }

    pub fn inGlobalContext(self: *const ParserState) bool {
        return self.hasContext(.GlobalContext);
    }

    pub fn inAssignmentContext(self: *const ParserState) bool {
        return self.hasContext(.AssignmentContext);
    }

    pub fn inPointerContext(self: *const ParserState) bool {
        return self.hasContext(.PointerContext);
    }

    pub fn inDotContext(self: *const ParserState) bool {
        return self.hasContext(.DotContext);
    }

    pub fn inArrayContext(self: *const ParserState) bool {
        return self.hasContext(.ArrayContext) or self.hasContext(.IndexContext);
    }

    pub fn inObjectContext(self: *const ParserState) bool {
        return self.hasContext(.ObjectContext) or self.hasContext(.PropertyContext);
    }

    pub fn inErrorContext(self: *const ParserState) bool {
        return self.hasContext(.ErrorContext) or self.hasContext(.RecoveryContext);
    }

    pub fn inExpressionContext(self: *const ParserState) bool {
        return self.hasContext(.ExpressionContext) or
            self.hasContext(.UnaryContext) or
            self.hasContext(.BinaryContext) or
            self.hasContext(.TernaryContext);
    }

    pub fn inBlockContext(self: *const ParserState) bool {
        return self.hasContext(.BlockContext);
    }

    pub fn inDeclContext(self: *const ParserState) bool {
        return self.hasContext(.DeclContext) or
            self.hasContext(.VarContext) or
            self.hasContext(.ConstContext);
    }

    pub fn inFlowContext(self: *const ParserState) bool {
        return self.hasContext(.ReturnContext) or
            self.hasContext(.BreakContext) or
            self.hasContext(.ContinueContext) or
            self.hasContext(.DeferContext);
    }

    // Set multiple contexts at once
    pub fn setContexts(self: *ParserState, flags: []const ContextFlag) void {
        for (flags) |flag| {
            self.setContext(flag);
        }
    }

    // Clear multiple contexts at once
    pub fn clearContexts(self: *ParserState, flags: []const ContextFlag) void {
        for (flags) |flag| {
            self.clearContext(flag);
        }
    }

    // Check if any of the specified contexts are active
    pub fn hasAnyContext(self: *const ParserState, flags: []const ContextFlag) bool {
        for (flags) |flag| {
            if (self.hasContext(flag)) return true;
        }
        return false;
    }

    // Check if all of the specified contexts are active
    pub fn hasAllContexts(self: *const ParserState, flags: []const ContextFlag) bool {
        for (flags) |flag| {
            if (!self.hasContext(flag)) return false;
        }
        return true;
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

    // Add an optional parameter to allow overriding the indent level check
    pub fn processWhitespace(
        self: *ParserState,
        options: struct {
            expected_indent_level: ?usize = null,
        }, // Options for processWhitespace
    ) !void {
        debug("processWhitespace: Starting at index {d}, current indentationLevel: {d}, expected_level: {?}\\n", .{ self.index, self.indentationLevel, options.expected_indent_level });

        // Add a safety check to prevent infinite recursion
        // This helps avoid loops when processing operators and identifiers
        if (self.index < self.tokens.len) {
            const curr = self.tokens[self.index];
            const should_skip = switch (curr) {
                .operator => |op| op == .@"=" or
                    op == .@"*" or
                    op == .@"&" or
                    op == .@"~" or
                    op == .@"!" or
                    op == .@".", // Skip dot operator to prevent infinite loops with consecutive dots
                .punctuation => |p| p == .@"[" or p == .@"]" or p == .@"(" or p == .@")" or p == .@",", // Skip all brackets and punctuation
                .identifier => true, // Skip whitespace processing for identifiers to prevent loops
                .keyword => true, // Skip whitespace processing for keywords
                else => false,
            };

            if (should_skip) {
                debug("processWhitespace: Skipping whitespace processing for token {any} to prevent loop\n", .{curr});
                return;
            }
        }

        // Mark the start index to detect if we're not making progress
        const start_index = self.index;

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
                debug("processWhitespace: Found 'else' token at index {d} looking ahead, in_if_context: {}, statement_indent_level: {d}\n", .{ else_token_idx, self.inIfContext(), self.statement_indent_level });
            } else {
                debug("processWhitespace: Found non-else token at index {d}: {any}\n", .{ peek_idx, peek_token });
            }
            break;
        }

        // Collect all whitespace tokens and calculate indentation
        debug("processWhitespace: Now counting indentation starting from index {d}\n", .{self.index});

        // Counter to detect potential infinite loops
        var loop_count: usize = 0;
        const MAX_LOOP_COUNT = 100; // Arbitrary limit to prevent infinite loops

        while (self.index < self.tokens.len) {
            // Safety check - if we've been looping too long without finishing
            loop_count += 1;
            if (loop_count > MAX_LOOP_COUNT) {
                debug("processWhitespace: Safety limit reached - breaking out of potential infinite loop\n", .{});
                // Force index progress to ensure we don't get stuck
                if (self.index < self.tokens.len) {
                    self.index += 1;
                }
                return;
            }

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

        // Safety check to prevent infinite loop - if we didn't advance, force advance by one
        if (self.index == start_index) {
            debug("processWhitespace: Warning - No progress made in processWhitespace, forcing index advance\n", .{});
            self.index += 1;
            return;
        }

        if (newlineFound) {
            debug("processWhitespace: Newline was found, indentCount: {d}, old indentationLevel: {d}\n", .{ indentCount, self.indentationLevel });

            // Check if we found an else token and verify indentation if in if-context
            if (found_else and self.inIfContext()) {
                // Use the explicitly passed expected level if provided, otherwise use statement_indent_level
                const required_level = options.expected_indent_level orelse self.statement_indent_level;
                debug("processWhitespace: Processing 'else' indentation. Current line indent: {d}, required level: {d}, in_if_context: {}\\n", .{ indentCount, required_level, self.inIfContext() });

                if (indentCount != required_level + 1) {
                    debug("processWhitespace: 'else' token has incorrect line indentation {d}, must match required level: {d}\\n", .{ indentCount, required_level });
                    return ParseError.InconsistentIndentation;
                } else {
                    // 'else' has correct indentation
                    debug("processWhitespace: 'else' token has correct line indentation matching required level: {d}\\n", .{indentCount});
                    self.indentationLevel = indentCount;
                }
            } else if (found_else) {
                debug("processWhitespace: Found 'else' token but in_if_context is false! Will use normal indentation rules.\n", .{});
                debug("processWhitespace: 'else' indentCount: {d}, indentationLevel: {d}, statement_indent_level: {d}\n", .{ indentCount, self.indentationLevel, self.statement_indent_level });
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

    pub fn isUnbalancedBrackets(self: *ParserState) bool {
        // Count opening and closing brackets to check for unbalanced pairs
        var open_square: usize = 0;
        var open_paren: usize = 0;

        // Only check a reasonable number of tokens ahead
        const max_lookahead = 10;
        const end_idx = @min(self.index + max_lookahead, self.tokens.len);

        for (self.index..end_idx) |i| {
            const token = self.tokens[i];
            if (token == .punctuation) {
                switch (token.punctuation) {
                    .@"[" => open_square += 1,
                    .@"]" => {
                        if (open_square > 0) {
                            open_square -= 1;
                        } else {
                            // Found closing bracket without opening
                            debug("isUnbalancedBrackets: Found unbalanced closing bracket ']'\n", .{});
                            return true;
                        }
                    },
                    .@"(" => open_paren += 1,
                    .@")" => {
                        if (open_paren > 0) {
                            open_paren -= 1;
                        } else {
                            // Found closing paren without opening
                            debug("isUnbalancedBrackets: Found unbalanced closing parenthesis ')'\n", .{});
                            return true;
                        }
                    },
                    else => {},
                }
            }
        }

        return false;
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

    try state.processWhitespace(.{});

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
                try state.processWhitespace(.{});

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
                        try state.processWhitespace(.{});
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
                        try state.processWhitespace(.{});

                        // Parse the value expression
                        const value = try evaluateExpression(state);

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
                try state.processWhitespace(.{});
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
    var consecutive_dots_count: usize = 0;

    while (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@".") {
            _ = state.nextToken(); // Consume the dot
            consecutive_dots_count += 1;

            if (consecutive_dots_count > 3) {
                debug("parseDotChain: Too many consecutive dots ({}), likely a syntax error\n", .{consecutive_dots_count});
                return ParseError.InvalidSyntax;
            }

            try state.processWhitespace(.{});

            // Check for * (pointer dereference)
            if (state.currentToken()) |maybe_star| {
                if (maybe_star == .operator and maybe_star.operator == .@"*") {
                    debug("parseDotChain: Found pointer dereference (.* operator)\n", .{});
                    _ = state.nextToken(); // Consume the *
                    consecutive_dots_count = 0; // Reset consecutive dots counter

                    // Create pointer dereference expression
                    const ptr_deref = try state.allocator.create(PointerDeref);
                    ptr_deref.* = PointerDeref{
                        .ptr = current_expr,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .PointerDeref = ptr_deref });
                    current_expr = result;

                    try state.processWhitespace(.{});
                    continue;
                }
            }

            // Parse the member name (identifier)
            if (state.currentToken() == null or state.currentToken().? != .identifier) {
                debug("parseDotChain: Error - Expected identifier after dot, got {any}\n", .{state.currentToken()});

                // Check for multiple consecutive dots
                if (state.currentToken()) |invalid_token| {
                    if (invalid_token == .operator and invalid_token.operator == .@".") {
                        debug("parseDotChain: Found another dot, advancing to avoid infinite loop\n", .{});
                        // Don't consume the dot here; let the outer loop handle it
                        // We just reset the consecutive dots counter to prevent too many dots error
                        consecutive_dots_count = 0;
                        continue;
                    } else {
                        // Any other token - consume it to prevent infinite loop
                        debug("parseDotChain: Found unexpected token after dot: {any}, skipping\n", .{invalid_token});
                        _ = state.nextToken();
                    }
                }

                return ParseError.ExpectedIdentifier;
            }

            const member_name = try parseIdentifier(state);
            debug("parseDotChain: Parsed member name: '{s}'\n", .{member_name});
            consecutive_dots_count = 0; // Reset consecutive dots counter

            // Create property expression
            const property = try state.allocator.create(Property);
            property.* = Property{
                .key = member_name,
                .value = current_expr,
            };

            const result = try state.allocator.create(Expression);
            result.* = Expression.init(ExpressionData{ .Property = property });
            current_expr = result;

            try state.processWhitespace(.{});
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

    // Set appropriate context flags
    state.setContext(.FunctionContext);
    defer state.clearContext(.FunctionContext);

    _ = state.nextToken(); // consume 'fn'

    // Save the line indentation level for the function declaration
    var line_indent_level: usize = 0;
    // Look backwards to find the beginning of the line and count indents
    if (state.index > 0) {
        var curr_idx = state.index - 1; // Start at the token before 'fn'
        while (curr_idx > 0) {
            const tok = state.tokens[curr_idx];
            if (tok == .newline) {
                // Found start of line
                break;
            }
            curr_idx -= 1;
        }

        // Count indent tokens
        curr_idx += 1; // Move past newline
        while (curr_idx < state.index) {
            const tok = state.tokens[curr_idx];
            if (tok == .indent) {
                line_indent_level += 1;
            } else if (tok != .space and tok != .comment) {
                break;
            }
            curr_idx += 1;
        }
    }

    // Update the statement indentation level
    state.statement_indent_level = line_indent_level;
    debug("parseFunctionExpression: Set statement_indent_level to {d}\n", .{state.statement_indent_level});

    // Skip any whitespace after 'fn'
    try state.processWhitespace(.{});

    // Parse function name
    const func_name = try parseIdentifier(state);
    errdefer state.allocator.free(func_name);
    debug("parseFunctionExpression: Processing function '{s}'\n", .{func_name});

    // Skip any whitespace after function name
    try state.processWhitespace(.{});

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
            try state.processWhitespace(.{});

            // Parse parameters
            while (state.currentToken()) |param_token| {
                if (param_token == .punctuation and param_token.punctuation == .@")") {
                    _ = state.nextToken(); // consume close parenthesis
                    break;
                }

                if (param_token == .punctuation and param_token.punctuation == .@",") {
                    _ = state.nextToken(); // consume comma
                    try state.processWhitespace(.{});
                    continue;
                }

                // Check for pointer parameter
                var is_pointer = false;
                if (param_token == .operator and param_token.operator == .@"*") {
                    is_pointer = true;
                    _ = state.nextToken(); // consume *
                    try state.processWhitespace(.{});
                }

                // Parse parameter name
                const param_name = try parseIdentifier(state);
                try state.processWhitespace(.{});

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
    try state.processWhitespace(.{});
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

    // Tracking to detect infinite loops
    var last_index: usize = 0;
    var consecutive_no_progress: usize = 0;
    const MAX_NO_PROGRESS = 3; // Maximum number of attempts without progress

    // Parse multiple expressions in the function body
    while (state.currentToken() != null) {
        try state.processWhitespace(.{});

        // Store index before parsing to detect if we're making progress
        last_index = state.index;

        // If we've decreased indentation below the function's indent level, we're done with the body
        // For indentation level 0, also check if we see new top-level elements like "fn"
        if (state.indentationLevel < starting_indent) {
            debug("parseFunctionExpression: End of function body - indentation dropped to {d}\n", .{state.indentationLevel});
            break;
        } else if (starting_indent == 0 and state.currentToken() != null and
            state.currentToken().? == .keyword and
            state.currentToken().?.keyword == .@"fn")
        {
            // At root level, if we see another "fn" keyword, treat it as the end of this function
            debug("parseFunctionExpression: End of function body - found new function definition\n", .{});
            break;
        } else if (state.currentToken() == null) {
            debug("parseFunctionExpression: End of function body - end of tokens\n", .{});
            break;
        }

        // Parse the next expression in the body
        debug("parseFunctionExpression: Parsing body expression at indent {d}, token: {any}\n", .{ state.indentationLevel, state.currentToken() });

        const expr = try evaluateExpression(state);

        try body_exprs.append(expr);

        debug("parseFunctionExpression: Parsed body expression, now at index {d}\n", .{state.index});

        // Detect if we're making progress and break if not
        if (state.index == last_index) {
            consecutive_no_progress += 1;
            debug("parseFunctionExpression: No progress made, attempt {d}/{d}\n", .{ consecutive_no_progress, MAX_NO_PROGRESS });

            if (consecutive_no_progress >= MAX_NO_PROGRESS) {
                debug("parseFunctionExpression: Breaking out of potential infinite loop\n", .{});
                if (state.index < state.tokens.len) {
                    state.index += 1; // Force progress
                }
                break;
            }
        } else {
            consecutive_no_progress = 0; // Reset counter if we made progress
        }

        try state.processWhitespace(.{});
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
        return ParseError.InvalidSyntax;
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
    debug("parseExpression: Starting at index {d}\n", .{state.index});

    // Check for EOF
    if (state.index >= state.tokens.len) {
        debug("parseExpression: EOF reached\n", .{});
        return ParseError.UnexpectedEndOfTokens;
    }

    // Get the token we're currently at
    const token = state.tokens[state.index];
    debug("parseExpression: Starting with token: {any}\n", .{token});

    // Handle nested expressions specially when in the appropriate context
    const allow_nesting = state.hasContext(.AllowNestedExpressions);
    debug("parseExpression: Allow nested expressions: {}\n", .{allow_nesting});

    // Special handling for if statements
    if (token == .keyword and token.keyword == .@"if") {
        debug("parseExpression: Found if keyword, setting in_if_context\n", .{});

        // Keep track of the if-context for nesting handling
        const was_in_if_context = state.hasContext(.IfContext);
        const current_nesting_level = state.statement_indent_level;

        // Increase nesting level for nested ifs when AllowNestedExpressions is set
        if (was_in_if_context and allow_nesting) {
            state.statement_indent_level += 1;
            debug("parseExpression: Increased if nesting level to {d}\n", .{state.statement_indent_level});
        }

        const if_expr = try parseIfExpression(state);

        // Restore nesting level
        if (was_in_if_context and allow_nesting) {
            state.statement_indent_level = current_nesting_level;
            debug("parseExpression: Restored if nesting level to {d}\n", .{state.statement_indent_level});
        }

        return if_expr;
    }

    // Track the starting token to improve error reporting
    const starting_token = state.currentToken();
    if (starting_token) |tok| {
        debug("parseExpression: Starting with token: {any}\n", .{tok});
    }

    // Check for unbalanced brackets/parentheses that could cause issues
    if (starting_token != null and state.isUnbalancedBrackets()) {
        debug("parseExpression: Detected unbalanced brackets, attempting to recover\n", .{});

        // Skip current token if it's a closing bracket without a matching opening bracket
        if (starting_token.? == .punctuation and
            (starting_token.?.punctuation == .@")" or
                starting_token.?.punctuation == .@"]"))
        {
            _ = state.nextToken(); // Skip the unbalanced bracket
            return createLiteralExpression(state, Value{ .unit = {} });
        }
    }

    // Special handling for keywords
    if (starting_token) |tok| {
        if (token == .keyword) {
            // Handle directly parseable expressions
            switch (tok.keyword) {
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
                // Special case for 'else' - it should not appear standalone
                .@"else" => {
                    debug("parseExpression: Found standalone 'else' keyword, context: in_if_context={}\n", .{state.inIfContext()});

                    // If we're in an if context, this might be an expected else clause
                    if (state.inIfContext()) {
                        debug("parseExpression: In if context, potentially part of an if-else structure\n", .{});

                        // If we're in a binary operation context (like operator & ~ if ... else),
                        // we need to check if the next token is another 'if'
                        // Consume the 'else' token
                        _ = state.nextToken();
                        try state.processWhitespace(.{});

                        // Parse the expression after 'else'
                        var else_body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
                        defer else_body_state.deinit();
                        else_body_state.indentationLevel = state.indentationLevel;

                        // Parse the expression for the else body
                        const else_body = try evaluateExpression(&else_body_state);

                        // Update state index to after the else body
                        state.index += else_body_state.index;

                        debug("parseExpression: Successfully parsed else body in binary context\n", .{});
                        return else_body;
                    }

                    // Otherwise, this is an unexpected else - consume it and return unit
                    debug("parseExpression: Not in if context, consuming unexpected 'else'\n", .{});
                    _ = state.nextToken();
                    return ParseError.InvalidSyntax;
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
    debug("parseExpression: Using evaluateExpression\n", .{});

    // Track the starting index to detect potential infinite loops
    const start_index = state.index;

    // Use evaluateExpression to handle the expression
    const result = evaluateExpression(state) catch |err| {
        debug("parseExpression: Error in evaluateExpression: {s}, attempting recovery\n", .{@errorName(err)});

        // Check if we made no progress
        if (state.index == start_index) {
            debug("parseExpression: No progress made, forcing index advance\n", .{});
            if (state.index < state.tokens.len) {
                state.index += 1; // Force advance
            }
        }

        // Return a default expression to recover
        return createLiteralExpression(state, Value{ .unit = {} });
    };

    return result;
}

// Helper function to detect unbalanced brackets
fn isUnbalancedBrackets(token: Token) bool {
    // Check for closing brackets without matching opening brackets
    if (token == .punctuation) {
        switch (token.punctuation) {
            .@")" => {
                debug("isUnbalancedBrackets: Found unbalanced closing parenthesis ')'\n", .{});
                return true;
            },
            .@"]" => {
                debug("isUnbalancedBrackets: Found unbalanced closing bracket ']'\n", .{});
                return true;
            },
            else => return false,
        }
    }
    return false;
}

fn evaluateRPN(state: *ParserState) ParserError!*Expression {
    debug("evaluateRPN: Starting with {d} RPN tokens\n", .{state.outputStack.items.len});

    var evalStack = std.ArrayList(*Expression).init(state.allocator);
    defer evalStack.deinit();

    // Print the tokens in the output stack for debugging
    if (DEBUG) {
        debug("evaluateRPN: Output stack contents:\n", .{});
        for (state.outputStack.items, 0..) |expr_handle, i| {
            if (expr_handle >= state.expressionHeap.expressions.items.len) {
                debug("  [{d}] INVALID HANDLE {d}\n", .{ i, expr_handle });
                continue;
            }
            const expr = state.expressionHeap.get(expr_handle) orelse {
                debug("  [{d}] NULL EXPRESSION\n", .{i});
                continue;
            };

            debug("  [{d}] Type: {s}", .{ i, @tagName(std.meta.activeTag(expr.data)) });
            switch (expr.data) {
                .Literal => |val| debug(", Value: {any}\n", .{val}),
                .Variable => |v| debug(", Name: {s}\n", .{v.identifier}),
                .Operator => |op| debug(", Operator: {s}\n", .{@tagName(op)}),
                .Global => |g| debug(", Identifier: {s}\n", .{g.identifier}),
                .Conditional => debug(", Conditional expression\n", .{}),
                else => debug("\n", .{}),
            }
        }
    }

    // Stack size sanity check - we should have a reasonable number of tokens
    if (state.outputStack.items.len > 1000) {
        debug("evaluateRPN: Output stack appears too large ({d} items), potential error\n", .{state.outputStack.items.len});
        return ParseError.InvalidSyntax;
    }

    for (state.outputStack.items, 0..) |expr_handle, i| {
        // Verify the handle is valid before dereferencing
        if (expr_handle >= state.expressionHeap.expressions.items.len) {
            debug("evaluateRPN: Invalid expression handle {d} (out of bounds) at index {d}\n", .{ expr_handle, i });
            return ParseError.InvalidSyntax;
        }

        const expr = state.expressionHeap.get(expr_handle) orelse {
            debug("evaluateRPN: Failed to get expression for handle {d} at index {d}\n", .{ expr_handle, i });
            return ParseError.InvalidSyntax;
        };

        debug("evaluateRPN: Processing token {d}/{d}, type: {s}\n", .{ i + 1, state.outputStack.items.len, @tagName(std.meta.activeTag(expr.data)) });

        switch (expr.data) {
            // For literals, variables, globals, and conditionals, just push them onto the stack
            .Literal, .Variable, .Global, .Conditional => {
                try evalStack.append(expr);
                debug("evaluateRPN: Pushed to stack, stack now has {d} items\n", .{evalStack.items.len});
            },

            .Operator => |op| {
                // Use context-aware operator handling
                switch (op) {
                    // Handle unary operators
                    .@"~", .@"!" => {
                        // Set appropriate context based on operator type
                        switch (op) {
                            .@"~" => state.setContext(.BitwiseOpContext),
                            .@"!" => state.setContext(.LogicalOpContext),
                            else => {}, // No specific context for other unary operators
                        }
                        defer {
                            // Clear contexts when done
                            state.clearContext(.BitwiseOpContext);
                            state.clearContext(.LogicalOpContext);
                        }
                        
                        if (evalStack.items.len < 1) {
                            debug("evaluateRPN: Stack underflow for unary operator {s}, have {d} items\n", .{ @tagName(op), evalStack.items.len });
                            return ParseError.InvalidSyntax;
                        }
                        
                        const operand = evalStack.pop();

                        // Create a unary expression with context awareness
                        const unary = try state.allocator.create(Unary);
                        errdefer state.allocator.destroy(unary);

                        unary.* = Unary{
                            .op = op,
                            .operand = operand.?,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Unary = unary });

                        try evalStack.append(result);
                        debug("evaluateRPN: Created context-aware unary expression for {s}, stack has {d} items\n", 
                              .{ @tagName(op), evalStack.items.len });
                    },

                    // Handle @operator (global reference)
                    .@"@" => {
                        if (evalStack.items.len < 1) {
                            debug("evaluateRPN: Stack underflow for @ operator, have {d} items\n", .{evalStack.items.len});
                            return ParseError.InvalidSyntax;
                        }
                        const ident_expr = evalStack.pop();
                        if (ident_expr) |innerExpr| {
                            // Create a global reference, properly handling conditional identifiers
                            if (innerExpr.data == .Variable) {
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
                                debug("evaluateRPN: Created global reference, stack now has {d} items\n", .{evalStack.items.len});
                            } else {}

                            // Handle other expression types as the target of @
                            debug("evaluateRPN: Creating global reference with non-variable expression\n", .{});

                            const global = try state.allocator.create(Global);
                            errdefer state.allocator.destroy(global);

                            global.* = Global{
                                .type = .Reference,
                                .identifier = try state.allocator.dupe(u8, "_expr"),
                                .value = null,
                                .arguments = null,
                            };

                            const result = try state.allocator.create(Expression);
                            errdefer state.allocator.destroy(result);
                            result.* = Expression.init(ExpressionData{ .Global = global });

                            try evalStack.append(result);
                            debug("evaluateRPN: Created global reference for non-variable, stack now has {d} items\n", .{evalStack.items.len});
                        }
                    },

                    // Handle assignment (=)
                    .@"=" => {
                        // Special case: handle assignment with less than 2 operands
                        if (evalStack.items.len < 2) {
                            debug("evaluateRPN: Stack underflow for assignment operator, have {d} items\n", .{evalStack.items.len});
                            // If we have exactly one expression, it might be a conditional or other complex type
                            // if (evalStack.items.len == 1) {
                            //     debug("evaluateRPN: Creating implicit left operand for assignment\\n", .{});
                            //     const right = evalStack.pop();

                            //     // Create a dummy variable for the left side
                            //     const var_name = try state.allocator.dupe(u8, "_implicit_var");
                            //     const dummy_var = try state.allocator.create(Variable);
                            //     dummy_var.* = Variable{
                            //         .identifier = var_name,
                            //         .value = .{ .unit = {} },
                            //     };

                            //     const left = try state.allocator.create(Expression);
                            //     left.* = Expression.init(.{ .Variable = dummy_var });

                            //     // Create the assignment with the implicit variable
                            //     const binary = try state.allocator.create(Binary);
                            //     binary.* = Binary{
                            //         .op = op,
                            //         .left = left,
                            //         .right = right.?,
                            //     };

                            //     const result = try state.allocator.create(Expression);
                            //     result.* = Expression.init(ExpressionData{ .Binary = binary });
                            //     try evalStack.append(result);

                            //     debug("evaluateRPN: Created assignment with implicit left side, stack now has {d} items\\n", .{evalStack.items.len});
                            //     continue;
                            // }

                            return ParseError.InvalidSyntax;
                        }

                        const right = evalStack.pop();
                        const left = evalStack.pop();

                        // Create a binary expression for the assignment
                        const binary = try state.allocator.create(Binary);
                        errdefer state.allocator.destroy(binary);

                        binary.* = Binary{
                            .op = op,
                            .left = left.?,
                            .right = right.?,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Binary = binary });

                        try evalStack.append(result);
                        debug("evaluateRPN: Created assignment expression, stack now has {d} items\n", .{evalStack.items.len});
                    },

                    // Handle binary operators with context-aware processing
                    .@"&", .@"|", .@"^", .@"+", .@"-", .@"*", .@"/", .@"%", .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=", .@"<<", .@">>" => {
                        // Special case: handle binary operator with less than 2 operands
                        //
                        if (evalStack.items.len < 2) {
                            debug("evaluateRPN: Stack underflow for binary operator {s}, have {d} items\n", .{ @tagName(op), evalStack.items.len });
                            // If we have exactly one expression, add an implicit operand
                            // if (evalStack.items.len == 1) {
                            //     debug("evaluateRPN: Adding implicit left operand for binary operator {s}\\n", .{@tagName(op)});
                            //     const right = evalStack.pop();

                            //     // Create a zero literal for the implicit operand
                            //     const zero_lit = try state.allocator.create(Expression);
                            //     zero_lit.* = Expression.init(.{ .Literal = Value{ .scalar = 0 } });

                            //     // Set the binary context flag before evaluating
                            //     state.setContext(.BinaryContext);
                            //     state.setContext(.BitwiseOpContext);
                            //     defer {
                            //         state.clearContext(.BinaryContext);
                            //         state.clearContext(.BitwiseOpContext);
                            //     }

                            //     // Create the binary expression
                            //     const binary = try state.allocator.create(Binary);
                            //     binary.* = Binary{
                            //         .op = op,
                            //         .left = zero_lit,
                            //         .right = right.?,
                            //     };

                            //     const result = try state.allocator.create(Expression);
                            //     result.* = Expression.init(ExpressionData{ .Binary = binary });
                            //     try evalStack.append(result);

                            //     debug("evaluateRPN: Created binary expression with implicit left side, stack now has {d} items\\n", .{evalStack.items.len});
                            //     continue;
                            // }
                            if (state.inPointerContext() and state.hasContext(.DereferenceContext)) {
                                //return unit to the caller
                                return createLiteralExpression(state, .unit);
                            } else {
                                return ParseError.InvalidSyntax;
                            }
                        }

                        const right = evalStack.pop();
                        const left = evalStack.pop();

                        // Set the binary context flag to help with processing conditionals
                        state.setContext(.BinaryContext);
                        state.setContext(.ExpressionContext);

                        // Set specific operator context flags based on the operator
                        switch (op) {
                            // Enhanced context setting for bitwise operators
                            .@"&", .@"|", .@"^", .@"<<", .@">>" => {
                                state.setContext(.BitwiseOpContext);
                                
                                // Special handling for shift operators
                                if (op == .@"<<" or op == .@">>") {
                                    state.setContext(.ShiftContext);
                                }
                                
                                // Special handling for & which could be address-of
                                if (op == .@"&" and left.?.data == .Variable) {
                                    debug("evaluateRPN: Potential address-of for &{s}\n", 
                                          .{left.?.data.Variable.identifier});
                                    state.setContext(.AddressContext);
                                }
                            },
                            // Enhanced context setting for arithmetic operators
                            .@"+", .@"-", .@"*", .@"/", .@"%" => {
                                state.setContext(.ArithmeticContext);
                                
                                // Special handling for * which could be pointer dereference
                                if (op == .@"*") {
                                    // Detect pointer dereference patterns
                                    const potential_ptr_types = [_][]const u8{"ptr", "pointer", "ref", "p_"};
                                    var is_likely_deref = false;
                                    
                                    // Check variable name patterns that suggest pointers
                                    if (left.?.data == .Variable) {
                                        const var_name = left.?.data.Variable.identifier;
                                        for (potential_ptr_types) |ptr_prefix| {
                                            if (std.mem.startsWith(u8, var_name, ptr_prefix)) {
                                                is_likely_deref = true;
                                                break;
                                            }
                                        }
                                        
                                        // Also check for pointer prefix *
                                        if (var_name.len > 0 and var_name[0] == '*') {
                                            is_likely_deref = true;
                                        }
                                    }
                                    
                                    if (is_likely_deref or state.inPointerContext()) {
                                        debug("evaluateRPN: Likely pointer dereference detected with *\n", .{});
                                        state.setContext(.PointerContext);
                                        state.setContext(.DereferenceContext);
                                    }
                                }
                            },
                            .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=" => state.setContext(.ComparisonContext),
                            else => {},
                        }

                        defer {
                            state.clearContext(.BinaryContext);
                            state.clearContext(.ExpressionContext);
                            state.clearContext(.BitwiseOpContext);
                            state.clearContext(.ArithmeticContext);
                            state.clearContext(.ComparisonContext);
                        }

                        // Special handling for if expressions inside binary operations
                        if (right.?.data == .Conditional or left.?.data == .Conditional) {
                            debug("evaluateRPN: Binary operation involves conditional expression\n", .{});
                            // Set in_if_context flag to true to help with else clause handling
                            state.setContext(.IfContext);
                            defer state.clearContext(.IfContext);

                            // Special handling for shift operators (<< and >>)
                            if (op == .@"<<" or op == .@">>") {
                                debug("evaluateRPN: Special handling for shift operation with conditional expression\n", .{});
                                state.setContext(.ShiftContext);
                                defer state.clearContext(.ShiftContext);

                                // If we have a conditional on either side of a shift operator,
                                // we need extra processing
                                if (right.?.data == .Conditional) {
                                    // The right side is a conditional
                                    const conditional = right.?.data.Conditional;

                                    // Check if the conditional is missing its else branch
                                    if (conditional.else_body == null) {
                                        debug("evaluateRPN: Conditional in shift operation might be missing its else branch\n", .{});

                                        // Look ahead for an else token
                                        var look_idx = state.index;
                                        var found_else = false;
                                        var else_token_idx: usize = 0;

                                        while (look_idx < state.tokens.len) : (look_idx += 1) {
                                            const token = state.tokens[look_idx];
                                            debug("evaluateRPN: Looking ahead for else at index {d}: {any}\n", .{ look_idx, token });
                                            if (token == .keyword and token.keyword == .@"else") {
                                                found_else = true;
                                                else_token_idx = look_idx;
                                                break;
                                            } else if (token != .newline and token != .space and token != .indent and token != .comment) {
                                                // Found non-whitespace, non-else token - stop looking
                                                break;
                                            }
                                        }

                                        if (found_else) {
                                            debug("evaluateRPN: Found else token at index {d} for conditional in shift operation\n", .{else_token_idx});

                                            // We don't need to save the current index since we're not restoring it
                                            // const current_index = state.index;

                                            // Update state index to point after the else token
                                            state.index = else_token_idx + 1;
                                            try state.processWhitespace(.{});

                                            // Parse the else branch
                                            var else_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
                                            defer else_state.deinit();
                                            else_state.indentationLevel = state.indentationLevel;
                                            else_state.setContext(.IfContext);
                                            else_state.setContext(.BinaryContext);

                                            // Parse the else expression
                                            const else_expr = try evaluateExpression(&else_state);

                                            // Connect to the conditional
                                            conditional.else_body = else_expr;
                                            debug("evaluateRPN: Connected else body to conditional in shift op: {*}\n", .{else_expr});

                                            // Update state index
                                            state.index += else_state.index;
                                            debug("evaluateRPN: Successfully parsed else branch in shift op\n", .{});
                                        }
                                    } else {
                                        debug("evaluateRPN: Conditional in shift operation has else branch: {*}\n", .{conditional.else_body});
                                    }
                                }
                            }
                        }

                        // Create a binary expression, properly handling conditional operands
                        const binary = try state.allocator.create(Binary);
                        errdefer state.allocator.destroy(binary);

                        binary.* = Binary{
                            .op = op,
                            .left = left.?,
                            .right = right.?,
                        };

                        const result = try state.allocator.create(Expression);
                        errdefer state.allocator.destroy(result);
                        result.* = Expression.init(ExpressionData{ .Binary = binary });

                        try evalStack.append(result);
                        debug("evaluateRPN: Created binary expression for {s}, stack now has {d} items\n", .{ @tagName(op), evalStack.items.len });
                    },

                    // Handle dot operator for member access
                    .@"." => {
                        // Check if we're in a pointer dereference context - if so,
                        // this is a special marker for the .* pattern
                        // Look ahead in the output stack for a * operator that might follow
                        var ptr_deref_pattern = false;
                        var star_op_idx: ?usize = null;

                        // Check for * operator on the eval stack
                        if (evalStack.items.len > 0) {
                            for (evalStack.items) |stack_item| {
                                if (stack_item.data == .Operator and stack_item.data.Operator == .@"*") {
                                    ptr_deref_pattern = true;
                                    debug("evaluateRPN: Found * operator on eval stack, treating as .* pattern\n", .{});
                                    break;
                                }
                            }
                        }

                        // Check upcoming items in the output stack for a * operator
                        if (!ptr_deref_pattern and i + 1 < state.outputStack.items.len) {
                            const next_handle = state.outputStack.items[i + 1];
                            if (next_handle < state.expressionHeap.expressions.items.len) {
                                const next_expr = state.expressionHeap.get(next_handle) orelse {
                                    debug("evaluateRPN: Invalid next expression after dot\n", .{});
                                    break;
                                };

                                if (next_expr.data == .Operator and next_expr.data.Operator == .@"*") {
                                    ptr_deref_pattern = true;
                                    star_op_idx = i + 1;
                                    debug("evaluateRPN: Detected .* pattern in upcoming RPN tokens\n", .{});
                                }
                            }
                        }

                        // Set pointer dereference context if pattern detected
                        if (ptr_deref_pattern) {
                            state.setContext(.PointerContext);
                            state.setContext(.DereferenceContext);
                            debug("evaluateRPN: Setting pointer dereference context for .* pattern\n", .{});
                        }

                        if (ptr_deref_pattern or (state.inPointerContext() and state.hasContext(.DereferenceContext))) {
                            debug("evaluateRPN: Found . operator in pointer dereference context\n", .{});

                            // In dereference context with a single operand, this is a pointer dereference
                            if (evalStack.items.len < 1) {
                                debug("evaluateRPN: Stack underflow for .* operator, have {d} items\n", .{evalStack.items.len});
                                return ParseError.InvalidSyntax;
                            }

                            const pointer = evalStack.pop();

                            // Create a pointer dereference node
                            debug("evaluateRPN: Creating pointer dereference for .*\n", .{});
                            const ptr_deref = try state.allocator.create(PointerDeref);
                            ptr_deref.* = PointerDeref{
                                .ptr = pointer.?,
                            };

                            const result = try state.allocator.create(Expression);
                            result.* = Expression.init(ExpressionData{ .PointerDeref = ptr_deref });

                            try evalStack.append(result);
                            debug("evaluateRPN: Created pointer dereference, stack now has {d} items\n", .{evalStack.items.len});

                            // Skip the * operator in the output stack if we found one
                            if (ptr_deref_pattern and star_op_idx != null) {
                                debug("evaluateRPN: Handling * operator at index {d} as part of .* pattern\n", .{star_op_idx.?});
                                
                                // Remove the * operator from consideration in the next iteration
                                // We'll modify the output stack to handle this properly
                                if (star_op_idx.? == i + 1) {
                                    // Modify the star operator in the output stack to a noop unit
                                    // This ensures it won't be processed as a separate operation
                                    if (star_op_idx.? < state.outputStack.items.len) {
                                        const star_handle = state.outputStack.items[star_op_idx.?];
                                        
                                        // Verify it's still a star operator (sanity check)
                                        if (star_handle < state.expressionHeap.expressions.items.len) {
                                            const star_expr = state.expressionHeap.get(star_handle) orelse {
                                                debug("evaluateRPN: Can't get star expr, skipping safety check\n", .{});
                                                continue; // Skip this check if we can't get the expression
                                            };
                                            
                                            if (star_expr.data == .Operator and star_expr.data.Operator == .@"*") {
                                                // Replace it with a unit value that will be ignored
                                                const unit_handle = try state.expressionHeap.allocate(
                                                    Expression.init(.{ .Literal = Value{ .unit = {} } })
                                                );
                                                state.outputStack.items[star_op_idx.?] = unit_handle;
                                                debug("evaluateRPN: Replaced * token with unit value to skip it\n", .{});
                                            }
                                        }
                                    }
                                }
                            }

                            // Clear the pointer dereference context now that we've handled it
                            state.clearContext(.DereferenceContext);
                            continue;
                        }

                        // Normal property access (not pointer dereference)
                        if (evalStack.items.len < 2) {
                            debug("evaluateRPN: Stack underflow for dot operator, have {d} items\n", .{evalStack.items.len});
                            return ParseError.InvalidSyntax;
                        }

                        const operand2 = evalStack.pop(); // Could be property name (Variable) or '*' (Operator)
                        const operand1 = evalStack.pop(); // Should be the object/pointer

                        // Check if the second operand is the '*' operator, indicating .*
                        if (operand2.?.data == .Operator and operand2.?.data.Operator == .@"*") {
                            // This is a pointer dereference (.* operator)
                            debug("evaluateRPN: Found .* syntax for pointer dereference\n", .{});

                            // Set pointer dereference context to ensure proper precedence
                            state.setContext(.PointerContext);
                            state.setContext(.DereferenceContext);

                            // Deallocate the temporary '*' operator expression
                            operand2.?.deinit(state.allocator);

                            // Create a pointer dereference node
                            const ptr_deref = try state.allocator.create(PointerDeref);
                            ptr_deref.* = PointerDeref{
                                .ptr = operand1.?,
                            };

                            const result = try state.allocator.create(Expression);
                            result.* = Expression.init(ExpressionData{ .PointerDeref = ptr_deref });

                            try evalStack.append(result);
                            debug("evaluateRPN: Created pointer dereference, stack now has {d} items\n", .{evalStack.items.len});
                        } else if (operand2.?.data == .Variable) {
                            // This is a regular property access (.identifier)
                            debug("evaluateRPN: Found .identifier syntax for property access\n", .{});

                            // Create a property access with the property name
                            const prop = try state.allocator.create(Property);
                            errdefer state.allocator.destroy(prop);

                            // Get the identifier string
                            const ident_str = operand2.?.data.Variable.identifier;

                            prop.* = Property{
                                .key = try state.allocator.dupe(u8, ident_str),
                                .value = operand1.?,
                            };

                            // Deallocate the temporary Variable expression holding the identifier
                            operand2.?.deinit(state.allocator);

                            const result = try state.allocator.create(Expression);
                            errdefer state.allocator.destroy(result);
                            result.* = Expression.init(ExpressionData{ .Property = prop });

                            try evalStack.append(result);
                            debug("evaluateRPN: Created property access for key '{s}', stack now has {d} items\n", .{ prop.key, evalStack.items.len });
                        } else {
                            // Invalid sequence after dot
                            debug("evaluateRPN: Invalid expression type after dot operator: {any}\n", .{operand2.?});
                            // Deallocate operands before returning error
                            operand1.?.deinit(state.allocator);
                            operand2.?.deinit(state.allocator);
                            return ParseError.InvalidSyntax;
                        }
                    },

                    // Handle any other operators
                    else => {
                        debug("evaluateRPN: Unhandled operator: {s}\n", .{@tagName(op)});
                        return ParseError.InvalidSyntax;
                    },
                }
            },

            // Handle any other expression types
            else => {
                debug("evaluateRPN: Pushing unhandled expression type: {s}\n", .{@tagName(std.meta.activeTag(expr.data))});
                try evalStack.append(expr);
            },
        }
    }

    // Make sure we have a valid result
    debug("evaluateRPN: Final evaluation stack size: {d}\n", .{evalStack.items.len});

    if (evalStack.items.len == 0) {
        debug("evaluateRPN: Empty evaluation stack, returning unit value\n", .{});
        // If we ended up with nothing on the stack, return a unit value
        const result = try state.allocator.create(Expression);
        result.* = Expression.init(.{ .Literal = Value{ .unit = {} } });
        return result;
    } else if (evalStack.items.len == 1) {
        // We have a single result, return it
        const result = evalStack.pop();
        debug("evaluateRPN: Successfully evaluated to a single expression of type {s}\n", .{@tagName(std.meta.activeTag(result.?.data))});
        return result.?;
    } else {
        // We have multiple results, create a block containing all of them
        debug("evaluateRPN: Multiple expressions on stack ({d}), creating a block\n", .{evalStack.items.len});

        var block_exprs = std.ArrayList(*Expression).init(state.allocator);
        errdefer block_exprs.deinit();

        for (evalStack.items) |expr| {
            try block_exprs.append(expr);
        }

        const block = try state.allocator.create(Block);
        block.* = Block{
            .body = block_exprs,
        };

        const result = try state.allocator.create(Expression);
        result.* = Expression.init(ExpressionData{ .Block = block });
        return result;
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
    var last_index: usize = 0; // Track the last processed index to detect loops
    var repeat_count: usize = 0; // Count repeated processing of the same index

    while (state.currentToken() != null) {
        try state.processWhitespace(.{});
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

                // Lookahead to check if it might be 'main' function
                var is_main_function = false;
                if (state.index + 2 < state.tokens.len) {
                    const maybe_identifier = state.tokens[state.index + 1];
                    if (maybe_identifier == .identifier) {
                        is_main_function = std.mem.eql(u8, maybe_identifier.identifier, "main");
                        debug("parse: Function name appears to be '{s}'{s}\n", .{ maybe_identifier.identifier, if (is_main_function) " (MAIN FUNCTION)" else "" });
                    }
                }

                // Only functions with 0 indentation level are treated as global functions
                const is_global_function = (state.indentationLevel == 0);
                debug("parse: Function is global: {} (indentation level: {})\n", .{ is_global_function, state.indentationLevel });

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
                if (is_global_function) {
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
    debug("parseIfExpression: Starting\\n", .{});

    // Remember initial indentation level
    const start_indent_level = state.indentationLevel;
    debug("parseIfExpression: Starting indentation level: {d}\\n", .{start_indent_level});

    // Use context methods to check various contexts
    debug("parseIfExpression: Current contexts - unary: {}, binary: {}, expression: {}\\n", .{ state.inUnaryContext(), state.inBinaryContext(), state.inExpressionContext() });

    // Consume 'if' keyword
    try parseKeyword(state, .@"if");
    try state.processWhitespace(.{});

    // Track that we're in an if context now and set additional relevant contexts
    state.setContext(.IfContext);
    state.setContext(.ExpressionContext);
    state.setContext(.ConditionContext); // Important for parsing complex conditions
    state.setContext(.BinaryContext); // Allow binary expressions in condition

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

        // Count indent tokens
        curr_idx += 1; // Move past newline
        while (curr_idx < state.index) {
            const tok = state.tokens[curr_idx];
            if (tok == .indent) {
                line_indent_level += 1;
            } else if (tok != .space and tok != .comment) {
                break;
            }
            curr_idx += 1;
        }
    }

    debug("parseIfExpression: Line indentation level for 'if' = {d} (previous indentationLevel: {d})\\n", .{ line_indent_level, state.indentationLevel });

    // Parse condition (the expression after 'if')
    var condition_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer condition_state.deinit();
    condition_state.indentationLevel = state.indentationLevel;

    // Set appropriate condition parsing context flags
    condition_state.setContext(.IfContext);
    condition_state.setContext(.Inline);
    condition_state.setContext(.ConditionContext);
    condition_state.setContext(.ExpressionContext);
    condition_state.setContext(.UnaryContext);
    condition_state.setContext(.BinaryContext);

    // Enhance condition parsing to ensure it captures the correct token sequence
    debug("parseIfExpression: Parsing condition at index {d}\\n", .{state.index});

    // If we're at the end of the tokens, return an error
    if (state.index >= state.tokens.len) {
        debug("parseIfExpression: Error - Unexpected end of tokens while parsing condition\\n", .{});
        return ParseError.UnexpectedEndOfTokens;
    }

    // Log the token we're about to parse as condition
    if (state.index < state.tokens.len) {
        const token = state.tokens[state.index];
        if (token == .identifier) {
            debug("parseIfExpression: About to parse condition starting with identifier '{s}'\\n", .{token.identifier});
        } else if (token == .keyword) {
            debug("parseIfExpression: About to parse condition starting with keyword '{s}'\\n", .{@tagName(token.keyword)});
        } else if (token == .operator) {
            debug("parseIfExpression: About to parse condition starting with operator '{s}'\\n", .{@tagName(token.operator)});
        }
    }

    // Use evaluateExpression for the condition, as it might be complex
    const condition = try evaluateExpression(&condition_state);
    errdefer condition.deinit(state.allocator);

    // Update state index
    state.index += condition_state.index;

    debug("parseIfExpression: Parsed condition: type={s}\\n", .{@tagName(std.meta.activeTag(condition.data))});
    if (condition.data == .Variable) {
        debug("parseIfExpression: Condition is variable: {s}\\n", .{condition.data.Variable.identifier});
    } else if (condition.data == .Literal) {
        debug("parseIfExpression: Condition is literal\\n", .{});
    } else if (condition.data == .Binary) {
        const binop = condition.data.Binary;
        debug("parseIfExpression: Condition is binary op {s}\\n", .{@tagName(binop.op)});
    }

    // Clear ConditionContext after parsing the condition
    state.clearContext(.ConditionContext);
    try state.processWhitespace(.{});

    // Parse the body (the true branch)
    // Use parseExpression here as the body can contain any statement/expression
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();

    body_state.indentationLevel = state.indentationLevel;
    body_state.statement_indent_level = line_indent_level; // Pass the if statement's indent level

    // Set context flags for the body
    body_state.setContext(.IfContext); // Still within the overall if context
    body_state.setContext(.BlockContext); // Body acts like a block
    body_state.setContext(.ExpressionContext); // Body can contain expressions
    body_state.setContext(.AllowNestedExpressions); // Allow nested ifs, etc.

    debug("parseIfExpression: About to parse body at indentation level {d} (line indent: {d})\\n", .{ body_state.indentationLevel, body_state.statement_indent_level });

    const body = try evaluateExpression(&body_state);
    errdefer body.deinit(state.allocator);

    // Update state index
    state.index += body_state.index;

    debug("parseIfExpression: Body expression type: {s}\\n", .{@tagName(std.meta.activeTag(body.data))});

    // Check for 'else' clause
    var else_body: ?*Expression = null;
    errdefer if (else_body) |eb| eb.deinit(state.allocator);

    // Save index before whitespace processing to restore if no else is found
    const index_before_else_check = state.index;
    const indent_level_before_else_check = state.indentationLevel;

    // When looking for 'else' clause, pass the if statement's indent level
    // to ensure the 'else' indentation check uses the correct level
    try state.processWhitespace(.{ .expected_indent_level = line_indent_level });

    var found_else = false;
    if (state.currentToken()) |token| {
        // Check indentation level - else must be at the same level as the corresponding if
        if (token == .keyword and token.keyword == .@"else" and state.indentationLevel == line_indent_level) {
            found_else = true;
        }
    }

    if (found_else) {
        debug("parseIfExpression: Found else clause at correct indentation level {d}\\n", .{state.indentationLevel});

        // Consume the 'else' token
        _ = state.nextToken();
        try state.processWhitespace(.{});

        // Set else context flag for parsing the else body
        state.setContext(.ElseContext);
        defer state.clearContext(.ElseContext); // Ensure ElseContext is cleared after parsing else body

        // Parse the else branch (use parseExpression)
        var else_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
        defer else_state.deinit();

        else_state.indentationLevel = state.indentationLevel;
        else_state.statement_indent_level = line_indent_level; // Pass the if statement's indent level

        // Set context flags for the else body
        else_state.setContext(.ElseContext);
        else_state.setContext(.BlockContext);
        else_state.setContext(.ExpressionContext);
        else_state.setContext(.AllowNestedExpressions);

        debug("parseIfExpression: Parsing else body at indentation level {d}\\n", .{else_state.indentationLevel});

        // Log the token we're about to parse as the else branch
        if (state.index < state.tokens.len) {
            const token = state.tokens[state.index];
            if (token == .identifier) {
                debug("parseIfExpression: Else branch starts with identifier '{s}'\\n", .{token.identifier});
            } else if (token == .keyword) {
                debug("parseIfExpression: Else branch starts with keyword '{s}'\\n", .{@tagName(token.keyword)});
            } else if (token == .operator) {
                debug("parseIfExpression: Else branch starts with operator '{s}'\\n", .{@tagName(token.operator)});
            } else if (token == .literal) {
                debug("parseIfExpression: Else branch starts with literal\\n", .{});
            }
        }

        // Parse the else expression with full recursion
        else_body = try evaluateExpression(&else_state);

        // Update state index
        state.index += else_state.index;

        debug("parseIfExpression: Else body expression type: {s}\\n", .{@tagName(std.meta.activeTag(else_body.?.data))});
        debug("parseIfExpression: Successfully parsed else body: {*}\\n", .{else_body.?});
    } else {
        debug("parseIfExpression: No else clause found or else at wrong indentation (current: {d}, expected: {d})\\n", .{ state.indentationLevel, line_indent_level });
        // Restore state if no else was found/consumed
        state.index = index_before_else_check;
        state.indentationLevel = indent_level_before_else_check;
    }

    // We're exiting the if-context - clear all related flags
    state.clearContext(.IfContext);
    state.clearContext(.Inline); // Clear Inline if it was set for condition
    state.clearContext(.ConditionalCompilationContext); // If used

    // Ensure body and else_body are wrapped in blocks if they aren't already
    const final_body = try guaranteeBlock(state, body);
    const final_else_body = if (else_body) |eb| try guaranteeBlock(state, eb) else null; // No placeholder block needed if no else

    // Create the conditional
    const conditional = try state.allocator.create(Conditional);
    conditional.* = Conditional{
        .condition = condition,
        .body = final_body,
        .else_body = final_else_body,
    };

    debug("parseIfExpression: Created conditional structure\\n", .{});
    debug("  - Condition: {*} (type: {s})\\n", .{ condition, @tagName(std.meta.activeTag(condition.data)) });
    debug("  - Body: {*} (type: {s})\\n", .{ final_body, @tagName(std.meta.activeTag(final_body.data)) });
    if (final_else_body) |eb| {
        debug("  - ElseBody: {*} (type: {s})\\n", .{ eb, @tagName(std.meta.activeTag(eb.data)) });
    } else {
        debug("  - ElseBody: none\\n", .{});
    }

    const result = try state.allocator.create(Expression);
    result.* = Expression.init(ExpressionData{ .Conditional = conditional });
    debug("parseIfExpression: Successfully created conditional expression\\n", .{});

    // When we return from here, this if-expression will potentially be used
    // as an operand in binary expressions
    return result;
}

// Helper function to ensure an expression is wrapped in a Block
fn guaranteeBlock(state: *ParserState, expr: *Expression) !*Expression {
    // If it's already a Block, return it unmodified
    if (expr.data == .Block) {
        debug("guaranteeBlock: Expression is already a Block with {d} items\n", .{expr.data.Block.body.items.len});
        return expr;
    }

    debug("guaranteeBlock: Wrapping expression type {s} in Block\n", .{@tagName(std.meta.activeTag(expr.data))});

    // Create a Block to contain the expression
    var block_exprs = std.ArrayList(*Expression).init(state.allocator);
    errdefer block_exprs.deinit();

    // Binary expressions need special handling to ensure full tree recursion
    if (expr.data == .Binary) {
        const binop = expr.data.Binary;
        debug("guaranteeBlock: Processing binary expression with op {s}\n", .{@tagName(binop.op)});

        // Special handling for shift operations which are common in if-else branches
        if (binop.op == .@"<<" or binop.op == .@">>") {
            debug("guaranteeBlock: Found shift operation ({s})\n", .{@tagName(binop.op)});

            // Ensure shift operations are properly preserved in the AST
            if (binop.left.data == .Global) {
                const global = binop.left.data.Global;
                debug("guaranteeBlock: Shift operation on global '{s}'\n", .{global.identifier});

                // Verify that the shift operation is properly structured
                debug("guaranteeBlock: Left is global: {s}, right is: {s}\n", .{ global.identifier, @tagName(std.meta.activeTag(binop.right.data)) });
            }
        }
    }

    // Add the original expression to the block
    try block_exprs.append(expr);

    // Create the Block
    const block = try state.allocator.create(Block);
    block.* = Block{
        .body = block_exprs,
    };

    // Create and return an Expression containing the Block
    const result = try state.allocator.create(Expression);
    result.* = Expression.init(ExpressionData{ .Block = block });

    debug("guaranteeBlock: Created block with {d} expressions\n", .{block.body.items.len});
    return result;
}

// Helper function to create a placeholder else block that matches the expected AST
fn createPlaceholderElseBlock(state: *ParserState) !*Expression {
    debug("createPlaceholderElseBlock: Creating empty else block\n", .{});

    // Create an empty block with no expressions
    var else_exprs = std.ArrayList(*Expression).init(state.allocator);
    errdefer else_exprs.deinit();

    // Create a proper expression for the empty block - a unit value
    const placeholder = try state.allocator.create(Expression);
    placeholder.* = Expression.init(ExpressionData{ .Literal = Value{ .unit = {} } });

    try else_exprs.append(placeholder);

    // Create the Block
    const block = try state.allocator.create(Block);
    block.* = Block{
        .body = else_exprs,
    };

    // Create and return an Expression containing the Block
    const result = try state.allocator.create(Expression);
    result.* = Expression.init(ExpressionData{ .Block = block });
    return result;
}

fn parseWhileExpression(state: *ParserState) ParserError!*Expression {
    debug("parseWhileExpression: Starting\n", .{});

    // Set appropriate context flags for while loops
    state.setContext(.WhileContext);
    state.setContext(.LoopContext);
    defer {
        state.clearContext(.WhileContext);
        state.clearContext(.LoopContext);
    }

    // Consume 'while' keyword
    try parseKeyword(state, .@"while");
    try state.processWhitespace(.{});

    // Save the line indentation level for the 'while' statement
    var line_indent_level: usize = 0;
    // Look backwards to find the beginning of the line and count indents
    if (state.index > 0) {
        var curr_idx = state.index - 1; // Start at the token before 'while'
        while (curr_idx > 0) {
            const tok = state.tokens[curr_idx];
            if (tok == .newline) {
                // Found start of line
                break;
            }
            curr_idx -= 1;
        }

        // Count indent tokens
        curr_idx += 1; // Move past newline
        while (curr_idx < state.index) {
            const tok = state.tokens[curr_idx];
            if (tok == .indent) {
                line_indent_level += 1;
            } else if (tok != .space and tok != .comment) {
                break;
            }
            curr_idx += 1;
        }
    }

    // Update the statement indentation level
    state.statement_indent_level = line_indent_level;
    debug("parseWhileExpression: Set statement_indent_level to {d}\n", .{state.statement_indent_level});

    // Parse condition
    var condition_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer condition_state.deinit();

    // Set appropriate context flags for the condition
    condition_state.indentationLevel = state.indentationLevel;
    condition_state.setContext(.WhileContext);
    condition_state.setContext(.ExpressionContext);
    condition_state.setContext(.ConditionContext);

    const condition = try evaluateExpression(&condition_state);
    errdefer condition.deinit(state.allocator);

    // Update state index
    state.index += condition_state.index;
    debug("parseWhileExpression: Parsed condition, new index {d}\n", .{state.index});

    // Check for tail expression (after ':')
    var tail_expression: ?*Expression = null;
    errdefer if (tail_expression) |t| t.deinit(state.allocator);

    try state.processWhitespace(.{});

    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@":") {
            debug("parseWhileExpression: Found tail expression marker ':'\n", .{});
            _ = state.nextToken(); // consume ':'
            try state.processWhitespace(.{});

            // Parse tail expression
            var tail_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            defer tail_state.deinit();

            // Set appropriate context flags for the tail expression
            tail_state.indentationLevel = state.indentationLevel;
            tail_state.setContext(.WhileContext);
            tail_state.setContext(.ExpressionContext);
            tail_state.setContext(.TailContext);

            tail_expression = try evaluateExpression(&tail_state);
            debug("parseWhileExpression: Parsed tail expression\n", .{});

            // Update state index
            state.index += tail_state.index;
        }
    }

    try state.processWhitespace(.{});

    // Parse body
    debug("parseWhileExpression: Parsing body with indentation level {d}\n", .{state.indentationLevel});
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();

    // Set appropriate context flags for the body
    body_state.indentationLevel = state.indentationLevel;
    body_state.setContext(.WhileContext);
    body_state.setContext(.BlockContext);
    body_state.setContext(.LoopBodyContext);

    // Make sure we don't mix up contexts for nested control structures
    body_state.clearContext(.IfContext);
    body_state.clearContext(.ElseContext);
    body_state.statement_indent_level = 0;

    const body = try evaluateExpression(&body_state);
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

    // Set appropriate context flags for for loops
    state.setContext(.ForContext);
    state.setContext(.LoopContext);
    defer {
        state.clearContext(.ForContext);
        state.clearContext(.LoopContext);
    }

    // Consume 'for' keyword
    try parseKeyword(state, .@"for");
    try state.processWhitespace(.{});

    // Save the line indentation level for the 'for' statement
    var line_indent_level: usize = 0;
    // Look backwards to find the beginning of the line and count indents
    if (state.index > 0) {
        var curr_idx = state.index - 1; // Start at the token before 'for'
        while (curr_idx > 0) {
            const tok = state.tokens[curr_idx];
            if (tok == .newline) {
                // Found start of line
                break;
            }
            curr_idx -= 1;
        }

        // Count indent tokens
        curr_idx += 1; // Move past newline
        while (curr_idx < state.index) {
            const tok = state.tokens[curr_idx];
            if (tok == .indent) {
                line_indent_level += 1;
            } else if (tok != .space and tok != .comment) {
                break;
            }
            curr_idx += 1;
        }
    }

    // Update the statement indentation level
    state.statement_indent_level = line_indent_level;
    debug("parseForExpression: Set statement_indent_level to {d}\n", .{state.statement_indent_level});

    // Parse the comma-separated expressions
    var expressions = std.ArrayList(*Expression).init(state.allocator);
    errdefer {
        for (expressions.items) |expr| {
            expr.deinit(state.allocator);
        }
        expressions.deinit();
    }

    // Set iterator context for expression parsing
    state.setContext(.IteratorContext);
    state.setContext(.ForEachContext);

    // Parse expressions until we find a colon or the end of the statement
    while (true) {
        // Parse each expression with appropriate context
        var expr_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
        defer expr_state.deinit();
        expr_state.indentationLevel = state.indentationLevel;
        expr_state.setContext(.ForContext);
        expr_state.setContext(.ExpressionContext);
        expr_state.setContext(.IteratorContext);

        const expr = try evaluateExpression(&expr_state);
        state.index += expr_state.index;
        try expressions.append(expr);

        try state.processWhitespace(.{});

        if (state.currentToken()) |token| {
            if (token == .punctuation and token.punctuation == .@",") {
                // Found a comma, continue to the next expression
                _ = state.nextToken(); // consume comma
                try state.processWhitespace(.{});
                continue;
            } else if (token == .punctuation and token.punctuation == .@":") {
                // Found a colon, indicating a tail expression follows
                _ = state.nextToken(); // consume colon
                try state.processWhitespace(.{});
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

    // Clear iterator context as we're done with the iterator expressions
    state.clearContext(.IteratorContext);
    state.clearContext(.ForEachContext);

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

        // Set appropriate context flags for the tail expression
        tail_state.indentationLevel = state.indentationLevel;
        tail_state.setContext(.ForContext);
        tail_state.setContext(.ExpressionContext);
        tail_state.setContext(.TailContext);

        tail_expression = try evaluateExpression(&tail_state);

        // Update state index
        state.index += tail_state.index;
    }

    try state.processWhitespace(.{});

    // Parse the body of the loop
    var body_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
    defer body_state.deinit();

    // Set appropriate context flags for the body
    body_state.indentationLevel = state.indentationLevel;
    body_state.setContext(.ForContext);
    body_state.setContext(.BlockContext);
    body_state.setContext(.LoopBodyContext);

    // Make sure we don't mix up contexts for nested control structures
    body_state.clearContext(.IfContext);
    body_state.clearContext(.ElseContext);
    body_state.statement_indent_level = 0;

    const body = try evaluateExpression(&body_state);
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

    // Determine flow type from keyword and set appropriate context flags
    if (state.currentToken()) |token| {
        if (token == .keyword) {
            switch (token.keyword) {
                .@"return" => {
                    flow_type = .Return;
                    state.setContext(.ReturnContext);
                    state.setContext(.FlowContext);
                    defer {
                        state.clearContext(.ReturnContext);
                        state.clearContext(.FlowContext);
                    }
                },
                .@"break" => {
                    flow_type = .Break;
                    state.setContext(.BreakContext);
                    state.setContext(.FlowContext);
                    defer {
                        state.clearContext(.BreakContext);
                        state.clearContext(.FlowContext);
                    }
                },
                .@"continue" => {
                    flow_type = .Continue;
                    state.setContext(.ContinueContext);
                    state.setContext(.FlowContext);
                    defer {
                        state.clearContext(.ContinueContext);
                        state.clearContext(.FlowContext);
                    }
                },
                .@"defer" => {
                    flow_type = .Defer;
                    state.setContext(.DeferContext);
                    state.setContext(.FlowContext);
                    defer {
                        state.clearContext(.DeferContext);
                        state.clearContext(.FlowContext);
                    }
                },
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
        try state.processWhitespace(.{});

        if (state.currentToken() != null and
            state.currentToken().? != .newline)
        {
            // There's an expression after return/defer
            // Create a new parser state for the expression with the appropriate context
            var expr_state = try ParserState.init(state.allocator, state.tokens[state.index..]);
            defer expr_state.deinit();
            expr_state.indentationLevel = state.indentationLevel;

            // Set expression context flags
            expr_state.setContext(.ExpressionContext);

            // Set specific flow context flags
            if (flow_type == .Return) {
                expr_state.setContext(.ReturnContext);
            } else if (flow_type == .Defer) {
                expr_state.setContext(.DeferContext);
            }

            body = try evaluateExpression(&expr_state);
            state.index += expr_state.index;
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

    // Remember the starting indentation level
    const starting_indent_level = state.indentationLevel;
    debug("parseShuntingYard: Starting with indentation level {d}\n", .{starting_indent_level});

    // Set appropriate starting context flags
    state.setContext(.ExpressionContext);

    while (state.currentToken()) |token| {
        // Check if we've decreased indentation - if so, stop parsing
        if (state.indentationLevel < starting_indent_level) {
            debug("parseShuntingYard: Stopping due to decrease in indentation (level {d} < starting level {d})\n", .{ state.indentationLevel, starting_indent_level });
            break;
        }

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
                // Add special handling for ".*" pointer dereference
                if (op == .@".") {
                    // Look ahead to check if next token after any whitespace is "*"
                    var is_pointer_deref = false;
                    var look_idx = state.index + 1;

                    // Skip any whitespace
                    while (look_idx < state.tokens.len) {
                        const peek_token = state.tokens[look_idx];
                        if (peek_token == .space or peek_token == .comment) {
                            look_idx += 1;
                            continue;
                        }
                        // Check if it's a star operator
                        if (peek_token == .operator and peek_token.operator == .@"*") {
                            is_pointer_deref = true;
                            debug("parseShuntingYard: Detected .* pointer dereference pattern\n", .{});

                            // Set pointer dereference context
                            state.setContext(.PointerContext);
                            state.setContext(.DereferenceContext);

                            // Handle the entire .* pattern here
                            // 1. Consume the . operator
                            _ = state.nextToken();

                            // 2. Skip any whitespace
                            var space_found = false;
                            while (state.currentToken()) |space_token| {
                                if (space_token == .space or space_token == .comment) {
                                    _ = state.nextToken();
                                    space_found = true;
                                } else {
                                    break;
                                }
                            }

                            // 3. Consume the * operator
                            if (state.currentToken()) |star_token| {
                                if (star_token == .operator and star_token.operator == .@"*") {
                                    _ = state.nextToken(); // consume *

                                    // 4. Insert a special marker in the output stack to indicate .* operation
                                    // We'll create a placeholder expression marked for pointer dereference
                                    debug("parseShuntingYard: Creating .* pointer dereference operator\n", .{});
                                    const deref_expr = try state.expressionHeap.allocate(Expression.init(.{
                                        .Operator = Operator.@"*", // Use * for pointer dereference operations
                                    }));

                                    // Add annotation to the stack to recognize this as a pointer dereference
                                    // during RPN evaluation
                                    while (state.operatorStack.items.len > 0) {
                                        const top_handle = state.operatorStack.items[state.operatorStack.items.len - 1];

                                        // Validate handle before using
                                        if (top_handle >= state.expressionHeap.expressions.items.len) {
                                            break;
                                        }

                                        const top_expr = state.expressionHeap.get(top_handle) orelse break;

                                        if (top_expr.data == .Operator and
                                            getContextualPrecedence(top_expr.data.Operator, state.context) >= getContextualPrecedence(Operator.@".", state.context))
                                        {
                                            const op_handle = state.operatorStack.pop();
                                            try state.outputStack.append(op_handle.?);
                                        } else {
                                            break;
                                        }
                                    }

                                    // Now push the .* operator
                                    try state.operatorStack.append(deref_expr);

                                    // Skip any further processing for this token iteration
                                    continue;
                                }
                            }
                        }
                        break;
                    }
                }

                // Add an implicit 0 literal to the output stack before the shift operator
                // But only if not in a pointer dereference context, since we already handled that
                if ((op == .@">>" or op == .@"<<" or (op == .@"." and !state.inPointerContext())) and
                    state.outputStack.items.len < 2)
                {
                    if (op == .@".") {
                        debug("parseShuntingYard: Not enough operands for dot operator, adding implicit variable\n", .{});
                        // Add a dummy variable expression to represent the object being accessed
                        const dummy_var = try state.allocator.create(Variable);
                        dummy_var.* = Variable{
                            .identifier = try state.allocator.dupe(u8, "_obj"),
                            .value = .{ .unit = {} },
                        };

                        const expr = Expression.init(.{ .Variable = dummy_var });
                        const expr_handle = try state.expressionHeap.allocate(expr);
                        try state.outputStack.append(expr_handle);

                        // Set dot context
                        state.setContext(.DotContext);
                    } else {
                        debug("parseShuntingYard: Not enough operands for shift operator {s}, adding implicit 0\n", .{@tagName(op)});
                        // Add an implicit 0 literal for shift operators
                        const zero_lit = try state.expressionHeap.allocate(Expression.init(.{ .Literal = Value{ .scalar = 0 } }));
                        try state.outputStack.append(zero_lit);

                        // Set shift context
                        state.setContext(.BitwiseOpContext);
                        state.setContext(.ShiftContext);
                    }
                }

                // Special handling for dot operator which might be missing operands
                if (op == .@".") {
                    debug("parseShuntingYard: Handling dot operator, current stack size: {d}\n", .{state.outputStack.items.len});
                    state.setContext(.DotContext);

                    // Enhanced look-ahead to detect .* pattern
                    // Look ahead to check if the next token after any whitespace is a star (*)
                    var peek_idx = state.index;
                    var found_star = false;
                    var space_count: usize = 0;

                    while (peek_idx < state.tokens.len) {
                        const peek_token = state.tokens[peek_idx];

                        // Skip whitespace during look-ahead
                        if (peek_token == .space or peek_token == .comment) {
                            peek_idx += 1;
                            space_count += 1;
                            continue;
                        }

                        // Check if we found a star (*) after the dot
                        if (peek_token == .operator and peek_token.operator == .@"*") {
                            found_star = true;
                            debug("parseShuntingYard: Detected .* pattern with {d} whitespace token(s) between . and *\n", .{space_count});

                            // Set pointer dereference context flags early
                            state.setContext(.PointerContext);
                            state.setContext(.DereferenceContext);

                            // Push a special marker for the * part of .*
                            // This will be recognized during RPN evaluation
                            const star_handle = try state.expressionHeap.allocate(Expression.init(.{ .Operator = .@"*" }));
                            try state.outputStack.append(star_handle);

                            // Add a special debug message to signal the RPN evaluator about this pattern
                            debug("parseShuntingYard: Added special marker for .* pattern in output stack\n", .{});
                        }
                        break;
                    }

                    // If we didn't find a star, this is a regular property access
                    if (!found_star) {
                        debug("parseShuntingYard: No * found after dot, treating as regular property access\n", .{});
                    }
                }

                // Handle @ operator specially
                if (op == .@"@") {
                    // Set global context for @ operator
                    state.setContext(.GlobalContext);

                    // Look ahead for function call pattern
                    if (state.index + 2 < state.tokens.len and
                        state.tokens[state.index + 1] == .identifier and
                        state.tokens[state.index + 2] == .punctuation and
                        state.tokens[state.index + 2].punctuation == .@"(")
                    {
                        in_global_call = true;
                        state.setContext(.FunctionContext);
                        state.setContext(.CallContext);

                        const global_expr = try parseGlobalExpression(state);
                        const expr_handle = try state.expressionHeap.allocate(global_expr.*);
                        try state.outputStack.append(expr_handle);
                        continue;
                    }
                }

                // Set operator-specific context flags
                switch (op) {
                    .@"=" => state.setContext(.AssignmentContext),
                    .@"+", .@"-", .@"/", .@"%" => state.setContext(.ArithmeticContext),
                    .@"|", .@"^" => state.setContext(.BitwiseOpContext),
                    .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=" => state.setContext(.ComparisonContext),
                    .@"<<", .@">>" => {
                        state.setContext(.BitwiseOpContext);
                        state.setContext(.ShiftContext);
                    },
                    .@"and", .@"or" => state.setContext(.LogicalOpContext),
                    .@"!" => state.setContext(.LogicalOpContext),
                    .@"~" => state.setContext(.BitwiseOpContext),
                    .@"*" => {
                        // Determine context for * operator based on surrounding tokens
                        var is_deref = false;

                        // Check if preceded by a dot (ptr.*)
                        if (state.index > 0) {
                            const prev_token = state.tokens[state.index - 1];
                            if (prev_token == .operator and prev_token.operator == .@".") {
                                is_deref = true;
                            }
                        }

                        // Check spacing around * for deref vs multiply
                        var has_left_space = false;
                        var has_right_space = false;

                        // Check for space before *
                        if (state.index > 0 and state.index - 1 < state.tokens.len) {
                            has_left_space = (state.tokens[state.index - 1] == .space);
                        }

                        // Check for space after *
                        if (state.index + 1 < state.tokens.len) {
                            has_right_space = (state.tokens[state.index + 1] == .space);
                        }

                        // No spaces typically indicates dereference
                        if (!has_left_space and !has_right_space) {
                            is_deref = true;
                        }

                        if (is_deref) {
                            state.setContext(.PointerContext);
                            state.setContext(.DereferenceContext);
                        } else {
                            state.setContext(.ArithmeticContext);
                        }
                    },
                    .@"&" => {
                        // Determine context for & operator based on spacing and surrounding tokens
                        var is_address = false;

                        // Check spacing around & for address vs bitwise AND
                        var has_left_space = false;
                        var has_right_space = false;

                        // Check for space before &
                        if (state.index > 0 and state.index - 1 < state.tokens.len) {
                            has_left_space = (state.tokens[state.index - 1] == .space);
                        }

                        // Check for space after &
                        if (state.index + 1 < state.tokens.len) {
                            has_right_space = (state.tokens[state.index + 1] == .space);

                            // Also check next non-space token - if it's an identifier, likely a reference
                            var look_ahead = state.index + 1;
                            while (look_ahead < state.tokens.len) {
                                if (state.tokens[look_ahead] == .space) {
                                    look_ahead += 1;
                                    continue;
                                }

                                // If followed by identifier, likely a reference operation
                                if (state.tokens[look_ahead] == .identifier) {
                                    is_address = true;
                                }
                                break;
                            }
                        }

                        // No right space typically indicates address-of
                        if (!has_right_space) {
                            is_address = true;
                        }

                        if (is_address) {
                            state.setContext(.PointerContext);
                            state.setContext(.AddressContext);
                        } else {
                            state.setContext(.BitwiseOpContext);
                        }
                    },
                    else => {},
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
                        getContextualPrecedence(top_expr.*.data.Operator, state.context) >= getContextualPrecedence(op, state.context))
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
                        state.setContext(.ArrayContext);
                        state.setContext(.IndexContext);

                        const marker = try state.expressionHeap.createParenMarker();
                        try state.operatorStack.append(marker);
                        _ = state.nextToken();
                    },

                    .@"]" => {
                        if (!in_array_index) {
                            // We encountered a closing bracket without a matching opening bracket
                            // This is a syntax error, but we need to handle it gracefully
                            debug("parseShuntingYard: Found unexpected closing bracket, skipping\n", .{});
                            _ = state.nextToken(); // Skip the unexpected closing bracket
                            break;
                        }

                        // Pop everything until matching [
                        var found_matching_bracket = false;
                        while (state.operatorStack.items.len > 0) {
                            const op_handle = state.operatorStack.pop().?;
                            if (state.expressionHeap.isParenMarker(op_handle)) {
                                found_matching_bracket = true;
                                break;
                            }
                            try state.outputStack.append(op_handle);
                        }

                        // If we didn't find a matching bracket, this is likely a syntax error
                        if (!found_matching_bracket) {
                            debug("parseShuntingYard: No matching opening bracket found for ], adding implied open\n", .{});
                            // We'll just proceed as if there was a matching opening bracket
                        }

                        in_array_index = false;
                        state.clearContext(.IndexContext);
                        _ = state.nextToken();
                    },

                    .@"(" => {
                        paren_depth += 1;
                        state.setContext(.ParenContext);

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
                        if (paren_depth == 0) {
                            state.clearContext(.ParenContext);
                        }

                        if (in_global_call and paren_depth == 0) {
                            in_global_call = false;
                            state.clearContext(.CallContext);
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

            .newline => {
                _ = state.nextToken(); // consume newline

                // Process whitespace to update indentation level
                try state.processWhitespace(.{});

                // After processing whitespace, check if we should terminate due to indentation change
                if (state.indentationLevel < starting_indent_level) {
                    debug("parseShuntingYard: Stopping after newline due to decrease in indentation (level {d} < starting level {d})\n", .{ state.indentationLevel, starting_indent_level });
                    break;
                }
            },

            else => if (!in_array_index and !in_global_call) break,
        }

        try state.processWhitespace(.{});
    }

    // Handle any remaining operators
    while (state.operatorStack.items.len > 0) {
        const op_handle = state.operatorStack.pop().?;
        if (!state.expressionHeap.isParenMarker(op_handle)) {
            try state.outputStack.append(op_handle);
        }
    }

    // Clear all relevant context flags when done
    state.clearContext(.ExpressionContext);
    state.clearContext(.DotContext);
    state.clearContext(.PointerContext);
    state.clearContext(.DereferenceContext);
    state.clearContext(.AddressContext);
    state.clearContext(.BitwiseOpContext);
    state.clearContext(.ShiftContext);
    state.clearContext(.ArithmeticContext);
    state.clearContext(.ComparisonContext);
    state.clearContext(.LogicalOpContext);
    state.clearContext(.AssignmentContext);
    state.clearContext(.ParenContext);
    state.clearContext(.ArrayContext);
    state.clearContext(.IndexContext);
    state.clearContext(.GlobalContext);
    state.clearContext(.FunctionContext);
    state.clearContext(.CallContext);

    // Check if we have a single operator in the output stack
    // This happens sometimes with operators like >>
    if (state.outputStack.items.len == 1) {
        // Check if it's an operator
        const handle = state.outputStack.items[0];
        if (handle < state.expressionHeap.expressions.items.len) {
            const expr = state.expressionHeap.get(handle) orelse return;
            if (expr.data == .Operator) {
                // Add implicit zero operand(s) depending on the operator
                const op = expr.data.Operator;

                // Check if it's a binary operator
                const is_binary = switch (op) {
                    .@"+", .@"-", .@"*", .@"/", .@"%", .@"==", .@"!=", .@"<", .@">", .@"<=", .@">=", .@"&", .@"|", .@"^", .@"<<", .@">>", .@"=", .@"and", .@"or" => true,
                    else => false,
                };

                const is_unary = switch (op) {
                    .@"-", .@"!", .@"~", .@"*", .@"&", .@"@" => true,
                    else => false,
                };

                if (is_binary) {
                    // Add two zeros
                    const zero1 = try state.expressionHeap.allocate(Expression.init(.{ .Literal = Value{ .scalar = 0 } }));
                    const zero2 = try state.expressionHeap.allocate(Expression.init(.{ .Literal = Value{ .scalar = 0 } }));

                    // Clear output stack and rebuild it
                    const op_handle = state.outputStack.pop().?;
                    try state.outputStack.append(zero1);
                    try state.outputStack.append(zero2);
                    try state.outputStack.append(op_handle);

                    debug("parseShuntingYard: Added implicit operands for lonely binary operator {s}\n", .{@tagName(op)});
                } else if (is_unary) {
                    // Add one zero
                    const zero = try state.expressionHeap.allocate(Expression.init(.{ .Literal = Value{ .scalar = 0 } }));

                    // Clear output stack and rebuild it
                    const op_handle = state.outputStack.pop().?;
                    try state.outputStack.append(zero);
                    try state.outputStack.append(op_handle);

                    debug("parseShuntingYard: Added implicit operand for lonely unary operator {s}\n", .{@tagName(op)});
                }
            }
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
    try state.processWhitespace(.{});

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
        const arg = try evaluateExpression(state);
        try args.append(arg);

        try state.processWhitespace(.{});

        if (state.currentToken()) |token| {
            if (token == .punctuation and token.punctuation == .@")") {
                _ = state.nextToken(); // consume closing parenthesis
                break;
            } else if (token == .punctuation and token.punctuation == .@",") {
                _ = state.nextToken(); // consume comma
                try state.processWhitespace(.{});

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
            try state.processWhitespace(.{});

            // Use evaluateExpression to parse a more complex primary expression
            ptr_expr = try evaluateExpression(state);
        }
    } else {
        debug("parsePointerExpression: Error - Expected token for pointer\n", .{});
        return ParseError.UnexpectedToken;
    }

    try state.processWhitespace(.{});

    // Check for . operator
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@".") {
            _ = state.nextToken(); // consume dot
            try state.processWhitespace(.{});

            // Now check for * operator
            if (state.currentToken()) |star_token| {
                if (star_token == .operator and star_token.operator == .@"*") {
                    _ = state.nextToken(); // consume *
                    try state.processWhitespace(.{});

                    // Create the pointer dereference expression
                    const ptr_deref = try state.allocator.create(PointerDeref);
                    ptr_deref.* = PointerDeref{
                        .ptr = ptr_expr.?,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(.{ .PointerDeref = ptr_deref });
                    debug("parsePointerExpression: Created PointerDeref\n", .{});

                    // Check if there's another dot after this dereference - handle dot chaining
                    try state.processWhitespace(.{});
                    if (state.currentToken()) |next_dot| {
                        if (next_dot == .operator and next_dot.operator == .@".") {
                            debug("parsePointerExpression: Found chained dot after pointer dereference\n", .{});
                            return parseDotChain(state, result);
                        }
                    }

                    // Check if an assignment follows this dereference
                    if (state.currentToken()) |next| {
                        if (next == .operator and next.operator == .@"=") {
                            debug("parsePointerExpression: Found assignment after dereference\n", .{});
                            // Don't advance token here - let the expression parser handle the assignment
                        }
                    }

                    return result;
                }
            }

            // If we get here, it's a normal property access after a dot
            return parseDotChain(state, ptr_expr.?);
        }
    }

    // No dot operator found, just return the parsed expression
    return ptr_expr.?;
}

// Function to parse a const expression (const x = expr) with support for global references
fn parseConstExpression(state: *ParserState) ParserError!*Expression {
    debug("parseConstExpression: Starting\n", .{});

    // Consume 'const' keyword
    try parseKeyword(state, .@"const");
    try state.processWhitespace(.{});

    // Check if this is a global reference declaration (const @identifier = ...)
    var is_global = false;
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"@") {
            is_global = true;
            debug("parseConstExpression: Found global reference declaration (@)\n", .{});
            _ = state.nextToken(); // consume @ symbol
            try state.processWhitespace(.{});
        }
    }

    // Parse the identifier
    const ident = try parseIdentifier(state);
    errdefer state.allocator.free(ident);
    try state.processWhitespace(.{});

    // Check for and require the = operator for const declarations
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"=") {
            _ = state.nextToken(); // consume =
            try state.processWhitespace(.{});

            // Parse the value expression
            const value = try evaluateExpression(state);

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
    try state.processWhitespace(.{});

    // Check if this is a global reference declaration (var @identifier = ...)
    var is_global = false;
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"@") {
            is_global = true;
            debug("parseVarExpression: Found global reference declaration (@)\n", .{});
            _ = state.nextToken(); // consume @ symbol
            try state.processWhitespace(.{});
        }
    }

    // Parse the identifier
    const ident = try parseIdentifier(state);
    errdefer state.allocator.free(ident);
    try state.processWhitespace(.{});

    // Check for and parse the = operator
    if (state.currentToken()) |token| {
        if (token == .operator and token.operator == .@"=") {
            _ = state.nextToken(); // consume =
            try state.processWhitespace(.{});

            // Parse the value expression
            const value = try evaluateExpression(state);

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
    const array_expr = try evaluateExpression(state);

    try state.processWhitespace(.{});

    // Check for '[' operator
    if (state.currentToken()) |token| {
        if (token == .punctuation and token.punctuation == .@"[") {
            _ = state.nextToken(); // consume '['
            debug("parseArrayIndexExpression: Found opening '[' for array index\n", .{});
            try state.processWhitespace(.{});

            // Check for immediate closing bracket (empty index)
            if (state.currentToken()) |maybe_close| {
                if (maybe_close == .punctuation and maybe_close.punctuation == .@"]") {
                    _ = state.nextToken(); // consume ']'
                    debug("parseArrayIndexExpression: Found empty index []\n", .{});

                    // Create index with default index of 0
                    const zero_expr = try state.allocator.create(Expression);
                    zero_expr.* = Expression.init(.{ .Literal = Value{ .scalar = 0 } });

                    const index = try state.allocator.create(Index);
                    index.* = Index{
                        .array = array_expr,
                        .index = zero_expr,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .Index = index });
                    return result;
                }
            }

            // Parse the index expression with timeout protection
            var index_expr: ?*Expression = null;
            errdefer if (index_expr) |expr| expr.deinit(state.allocator);

            const start_index = state.index;
            index_expr = evaluateExpression(state) catch |err| {
                debug("parseArrayIndexExpression: Error parsing index expression: {s}\n", .{@errorName(err)});
                // Create a default index if parsing fails
                const zero_expr = try state.allocator.create(Expression);
                zero_expr.* = Expression.init(.{ .Literal = Value{ .scalar = 0 } });
                index_expr = zero_expr;
                return zero_expr; // Return it immediately to avoid void assignment
            };

            // Check for infinite loop (no progress made)
            if (state.index == start_index) {
                debug("parseArrayIndexExpression: No progress made parsing index, advancing index\n", .{});
                if (state.index < state.tokens.len) {
                    state.index += 1; // Force advance to prevent infinite loop
                }
            }

            try state.processWhitespace(.{});

            // Check for ']' to close the index
            if (state.currentToken()) |close_token| {
                if (close_token == .punctuation and close_token.punctuation == .@"]") {
                    _ = state.nextToken(); // consume ']'
                    debug("parseArrayIndexExpression: Found closing ']' for array index\n", .{});

                    // Create the index expression
                    const index = try state.allocator.create(Index);
                    index.* = Index{
                        .array = array_expr,
                        .index = index_expr.?,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .Index = index });
                    return result;
                } else {
                    debug("parseArrayIndexExpression: Error - Expected ']' to close array index, got {any}\n", .{close_token});
                    // Don't fail entirely - try to recover
                    debug("parseArrayIndexExpression: Attempting to recover from missing closing bracket\n", .{});

                    // Create the index expression anyway
                    const index = try state.allocator.create(Index);
                    index.* = Index{
                        .array = array_expr,
                        .index = index_expr.?,
                    };

                    const result = try state.allocator.create(Expression);
                    result.* = Expression.init(ExpressionData{ .Index = index });
                    return result;
                }
            } else {
                debug("parseArrayIndexExpression: Error - Unexpected end of tokens while parsing array index\n", .{});
                // Create a default index if we hit EOF
                const index = try state.allocator.create(Index);
                index.* = Index{
                    .array = array_expr,
                    .index = index_expr.?,
                };

                const result = try state.allocator.create(Expression);
                result.* = Expression.init(ExpressionData{ .Index = index });
                return result;
            }
        }
    }

    // If we reach here, it's not an array index expression
    // Just return the original expression we parsed
    return array_expr;
}

// Add a utility function to wrap an expression in a Block
fn wrapExpressionInBlock(state: *ParserState, expr: *Expression) !*Expression {
    // Create an ArrayList to hold the expression
    var block_exprs = std.ArrayList(*Expression).init(state.allocator);
    errdefer {
        // Don't free the expression - it's owned by the caller
        block_exprs.deinit();
    }

    // Add the expression to the block
    try block_exprs.append(expr);

    // Create a Block
    const block = try state.allocator.create(Block);
    block.* = Block{
        .body = block_exprs,
    };

    // Create and return an Expression containing the Block
    const result = try state.allocator.create(Expression);
    result.* = Expression.init(ExpressionData{ .Block = block });

    debug("wrapExpressionInBlock: Wrapped expression {*} in a Block {*}\n", .{ expr, result });
    return result;
}

// Add helper function to evaluate expressions using shunting yard and RPN
fn evaluateExpression(state: *ParserState) ParserError!*Expression {
    debug("evaluateExpression: Starting\n", .{});

    // Save the current output stack
    const old_output_stack = state.outputStack;
    state.outputStack = std.ArrayList(usize).init(state.allocator);
    defer {
        state.outputStack.deinit();
        state.outputStack = old_output_stack;
    }

    // Run shunting yard to produce RPN
    try parseShuntingYard(state);

    // Check if shunting yard produced anything
    if (state.outputStack.items.len == 0) {
        debug("evaluateExpression: Empty output stack after shunting yard\n", .{});
        return createLiteralExpression(state, Value{ .unit = {} });
    }

    // Evaluate the RPN stack to build the final expression tree
    const result = try evaluateRPN(state);
    debug("evaluateExpression: Successfully evaluated to expression type {s}\n", .{@tagName(std.meta.activeTag(result.data))});
    return result;
}
