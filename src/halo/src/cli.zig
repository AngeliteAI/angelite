const std = @import("std");
const lexer = @import("lexer.zig").lexer;
const parser = @import("parser.zig");
const parse = parser.parse;
const Expression = parser.Expression;

/// Recursively prints an AST node with proper indentation
fn printAstNode(node: *const Expression, depth: usize, is_last: bool, prefix: []const u8) void {
    // Print the current line's prefix
    std.debug.print("{s}", .{prefix});

    // Print the appropriate branch symbol based on whether this is the last child
    if (depth > 0) {
        if (is_last) {
            std.debug.print("\\-- ", .{});
        } else {
            std.debug.print("|-- ", .{});
        }
    }

    // Print the node type
    std.debug.print("{s}", .{@tagName(node.*)});

    // Print additional node-specific details if needed
    switch (node.*) {
        .Literal => |val| {
            std.debug.print(": {any}", .{val});
        },
        .Variable => |var_node| {
            std.debug.print(": {s}", .{var_node.identifier});
        },
        .Function => |func| {
            std.debug.print(": {s} (params: {d})", .{ func.identifier, func.parameters.items.len });
            if (func.parameters.items.len > 0) {
                std.debug.print(" [", .{});
                for (func.parameters.items, 0..) |param, i| {
                    std.debug.print("{s}", .{param.identifier});
                    std.debug.print("{} {any} ", .{ i, param });
                    std.debug.print(", ", .{});
                }
            }
            std.debug.print("]", .{});
        },
        .Call => |call| {
            std.debug.print(": {s} (args: {d})", .{ call.identifier, call.arguments.items.len });
        },
        .Global => |global| {
            std.debug.print(": {s} (type: {s})", .{ global.identifier, @tagName(global.type) });
        },
        .Operator => |op| {
            std.debug.print(": {s}", .{@tagName(op)});
        },
        .CompoundAssign => |ca| {
            std.debug.print(": {s}", .{@tagName(ca.op)});
        },
        .Loop => |loop| {
            std.debug.print(": {s}", .{@tagName(loop.type)});
            if (loop.variable) |var_name| {
                std.debug.print(" variable: {s}", .{var_name});
            }
            if (loop.tail_expression != null) {
                std.debug.print(" (has tail expr)", .{});
            }
        },
        .Conditional => |cond| {
            std.debug.print(" (has else: {s})", .{if (cond.else_body != null) "yes" else "no"});
        },
        .Logical => |logical| {
            std.debug.print(": {s}", .{@tagName(logical.op)});
        },
        .Index => |_| {
            std.debug.print(" (array indexing)", .{});
        },
        .Range => |range| {
            std.debug.print(" (start: {s}, end: {s})", .{
                if (range.start != null) "yes" else "no",
                if (range.end != null) "yes" else "no",
            });
        },
        .Flow => |flow| {
            std.debug.print(": {s}", .{@tagName(flow.type)});
        },
        .Tensor => |tensor| {
            std.debug.print(" (elements: {d})", .{tensor.elements.items.len});
        },
        .Expansion => |_| {
            std.debug.print(" (spread operator)", .{});
        },
        .Block => |block| {
            std.debug.print(" (statements: {d})", .{block.body.items.len});
        },
        .Object => |obj| {
            std.debug.print(" (properties: {d})", .{obj.properties.items.len});
        },
        .Property => |prop| {
            std.debug.print(": {s}", .{prop.key});
        },
        .Binary => |bin| {
            std.debug.print(": {s}", .{@tagName(bin.op)});
        },
        .Unary => |un| {
            std.debug.print(": {s}", .{@tagName(un.op)});
        },
        .PointerMember => |pm| {
            std.debug.print(": .*{s}", .{pm.member});
        },
    }
    std.debug.print("\n", .{});

    // Prepare the new prefix for child nodes
    var new_prefix: []const u8 = undefined;
    if (depth > 0) {
        if (is_last) {
            new_prefix = std.fmt.allocPrint(std.heap.page_allocator, "{s}    ", .{prefix}) catch "    ";
        } else {
            new_prefix = std.fmt.allocPrint(std.heap.page_allocator, "{s}|   ", .{prefix}) catch "|   ";
        }
    } else {
        new_prefix = prefix;
    }

    // Recursively print child nodes based on the node type
    switch (node.*) {
        .Loop => |loop| {
            if (loop.condition) |condition| {
                printAstNode(condition, depth + 1, loop.tail_expression == null, new_prefix);
            }
            if (loop.tail_expression) |tail| {
                printAstNode(tail, depth + 1, false, new_prefix);
            }
            printAstNode(loop.body, depth + 1, true, new_prefix);
        },
        .Conditional => |cond| {
            printAstNode(cond.condition, depth + 1, cond.else_body == null, new_prefix);
            printAstNode(cond.body, depth + 1, cond.else_body == null, new_prefix);
            if (cond.else_body) |else_body| {
                printAstNode(else_body, depth + 1, true, new_prefix);
            }
        },
        .Logical => |logical| {
            printAstNode(logical.left, depth + 1, false, new_prefix);
            printAstNode(logical.right, depth + 1, true, new_prefix);
        },
        .Index => |idx| {
            printAstNode(idx.array, depth + 1, false, new_prefix);
            printAstNode(idx.index, depth + 1, true, new_prefix);
        },
        .Call => |call| {
            var i: usize = 0;
            for (call.arguments.items) |arg| {
                printAstNode(arg, depth + 1, i == call.arguments.items.len - 1, new_prefix);
                i += 1;
            }
        },
        .Function => |func| {
            printAstNode(func.body, depth + 1, true, new_prefix);
        },
        .Range => |range| {
            if (range.start) |start| {
                printAstNode(start, depth + 1, range.end == null, new_prefix);
            }
            if (range.end) |end| {
                printAstNode(end, depth + 1, true, new_prefix);
            }
        },
        .Flow => |flow| {
            if (flow.body) |body| {
                printAstNode(body, depth + 1, true, new_prefix);
            }
        },
        .Global => |global| {
            if (global.value) |value| {
                printAstNode(value, depth + 1, true, new_prefix);
            }
        },
        .CompoundAssign => |ca| {
            printAstNode(ca.target, depth + 1, false, new_prefix);
            printAstNode(ca.value, depth + 1, true, new_prefix);
        },
        .Tensor => |tensor| {
            var i: usize = 0;
            for (tensor.elements.items) |elem| {
                printAstNode(elem, depth + 1, i == tensor.elements.items.len - 1, new_prefix);
                i += 1;
            }
        },
        .Expansion => |expansion| {
            printAstNode(expansion.expr, depth + 1, true, new_prefix);
        },
        .Block => |block| {
            var i: usize = 0;
            for (block.body.items) |stmt| {
                printAstNode(stmt, depth + 1, i == block.body.items.len - 1, new_prefix);
                i += 1;
            }
        },
        .Object => |obj| {
            var i: usize = 0;
            for (obj.properties.items) |prop| {
                // Cast Property pointer to Expression
                const expr = @as(*const Expression, @ptrCast(prop));
                printAstNode(expr, depth + 1, i == obj.properties.items.len - 1, new_prefix);
                i += 1;
            }
        },
        .Property => |prop| {
            printAstNode(prop.value, depth + 1, true, new_prefix);
        },
        .Binary => |bin| {
            printAstNode(bin.left, depth + 1, false, new_prefix);
            printAstNode(bin.right, depth + 1, true, new_prefix);
        },
        .Unary => |un| {
            printAstNode(un.operand, depth + 1, true, new_prefix);
        },
        .PointerMember => |pm| {
            // Print the object expression that we're dereferencing and accessing
            printAstNode(pm.object, depth + 1, true, new_prefix);
        },
        else => {},
    }

    // Free the allocated prefix for this level
    if (depth > 0 and new_prefix.len > 0) {
        std.heap.page_allocator.free(new_prefix);
    }
}

/// Prints the full AST in a tree-like format
fn printAst(expressions: []const *Expression) void {
    std.debug.print("AST:\n", .{});
    for (expressions, 0..) |expr, i| {
        const is_last = i == expressions.len - 1;
        // For top-level expressions, print a header with the expression number
        std.debug.print("\nExpression {d}:\n", .{i + 1});
        printAstNode(expr, 0, is_last, "");

        // Add an extra newline between root expressions for better readability
        if (!is_last) {
            std.debug.print("\n", .{});
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get command line arguments
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    // Skip the program name
    _ = args.next();

    // Get the filename from arguments
    const filename = args.next() orelse {
        std.debug.print("Usage: {s} <filename>\n", .{args.next().?});
        std.process.exit(1);
    };

    // Read the file
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const source = try file.readToEndAlloc(allocator, 1024 * 1024); // 1MB limit
    defer allocator.free(source);

    // Run the lexer on the file contents
    var tokens = try lexer(allocator, source);
    defer tokens.deinit();

    for (tokens.list.items) |token| {
        //print detailed information for each token
        //implement correctly for all tokens
        switch (token) {
            .identifier => {
                std.debug.print("  Identifier: {s}\n", .{token.identifier});
            },
            .literal => {
                switch (token.literal) {
                    .string => {
                        std.debug.print("  Literal: {s}\n", .{token.literal.string});
                    },
                    .boolean => {
                        std.debug.print("  Literal: {}\n", .{token.literal.boolean});
                    },
                    .scalar => {
                        std.debug.print("  Literal: {}\n", .{token.literal.scalar});
                    },
                    .real => {
                        std.debug.print("  Literal: {}\n", .{token.literal.real});
                    },
                    else => {},
                }
            },
            .indent => {
                std.debug.print("  Indent\n", .{});
            },
            .newline => {
                std.debug.print("  Newline\n", .{});
            },
            .comment => {
                std.debug.print("  Comment: {s}\n", .{token.comment});
            },
            .punctuation => {
                std.debug.print("  Punctuation: {s}\n", .{@tagName(token.punctuation)});
            },
            .space => {
                std.debug.print("  Space\n", .{});
            },
            .operator => {
                std.debug.print("  Operator: {s}\n", .{@tagName(token.operator)});
            },
            .keyword => {
                std.debug.print("  Keyword: {s}\n", .{@tagName(token.keyword)});
            },
        }
    }

    const expressions = try parse(allocator, tokens.list);
    defer parser.deinitExpressions(expressions, allocator);

    // Print the AST in a tree format
    printAst(expressions);
}
