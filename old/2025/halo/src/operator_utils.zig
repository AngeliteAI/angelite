// operator_utils.zig - Utility functions for operator precedence and context handling
pub const std = @import("std");
pub const Operator = @import("lexer.zig").Operator;

// Helper function to determine if an operator is being used as a pointer dereference in a given context
pub fn isPointerDereference(operator: Operator, context: u512) bool {
    _ = context; // Context will be used in the full implementation
    
    // For now, just check if it's the * operator
    return operator == .@"*";
}

// Helper function to determine if an operator is being used as a pointer reference in a given context
pub fn isPointerReference(operator: Operator, context: u512) bool {
    _ = context; // Context will be used in the full implementation
    
    // For now, just check if it's the & operator
    return operator == .@"&";
}

// Get the precedence of an operator considering the context it's used in
pub fn getContextualPrecedence(operator: Operator, context: u512) u8 {
    // Special handling for operators with multiple meanings
    switch (operator) {
        .@"*" => {
            // Check if it's being used as a dereference operator
            if (isPointerDereference(operator, context)) {
                return 15; // Higher precedence for dereference
            } else {
                return 11; // Normal multiplication precedence
            }
        },
        .@"&" => {
            // Check if it's being used as a reference operator
            if (isPointerReference(operator, context)) {
                return 15; // Higher precedence for reference
            } else {
                return 6; // Normal bitwise AND precedence
            }
        },
        // Other operators can be added here as needed
        else => {
            // Default to the standard precedence
            return operator.precedence();
        }
    }
}