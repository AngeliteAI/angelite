// File: angelite/src/halo/src/lexer_ext.zig
// This file extends the lexer functionality with context-aware operator precedence

pub const std = @import("std");
pub const Operator = @import("lexer.zig").Operator;
pub const operator_utils = @import("operator_utils.zig");

// Extension function for Operator to handle context-aware precedence
pub fn contextualPrecedence(op: Operator, context: u512) u8 {
    return operator_utils.getContextualPrecedence(op, context);
}