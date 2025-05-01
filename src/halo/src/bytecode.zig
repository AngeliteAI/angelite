pub const Op = enum(u8) {
    Add,
    Sub,
    Mul,
    Div,
    Mod,
    Pow,
    Sin,
    Cos,
    Tan,
    Asin,
    Acos,
    Atan,
    Exp,
    Log,
    Sqrt,
    Cbrt,
    Abs,
    Neg,
    Not,
    And,
    Or,
    Xor,
    Shl,
    Shr,
    Eq,
    Ne,
    Lt,
    Gt,
    Le,
    Ge,
    Test,
    Set,
    Load,
    Store,
    Jump,
    Call,
    Label,
    If,
    Else,
    While,
    For,
    Break,
    Continue,
    Return,
    Yield,
};

pub fn Dispatch(stackSize: comptime_int, comptime DispatchTable: []const fn (dispatch: *Dispatch) void) type {
    return struct { size: usize = stackSize, stack: *[stackSize]Value, programCounter: *usize, index: *usize, dispatchTable: *DispatchTable, jump: *const fn (dispatch: *anyopaque) void = dispatchJump };
}

pub fn dispatchJump(dispatch: *anyopaque) void {
    const dispatcher = @as(Dispatcher, @ptrCast(dispatch));
    dispatcher.dispatchTable[dispatcher.programCounter](dispatch);
}

pub const Dispatcher = struct {
    stackSize: usize,
    stackIndex: *usize,
    stack: *Value,
    programAddress: usize,
    programCounter: *usize,
    dispatchTable: *[]const fn (dispatch: *anyopaque) void,
    jump: *const fn (dispatch: *anyopaque) void,

    fn push(self: *Dispatcher, value: Value) void {
        self.stack[self.index] = value;
        self.index += 1;
        if (self.index >= self.stackSize) {
            @panic("Stack overflow");
        }
    }

    fn pop(self: *Dispatcher) Value {
        if (self.index == 0) {
            @panic("Stack underflow");
        }
        self.index -= 1;
        return self.stack[self.index];
    }
};

pub fn interpret(bytecode: []const u8, dispatch: *anyopaque) void {
    const dispatcher = @as(Dispatcher, @ptrCast(dispatch));
    dispatcher.programCounter = 0;
    for (dispatcher.stack) |item| {
        item = Value.unit;
    }
    dispatcher.index = 0;
    dispatcher.codeAddress = 0;
    //put bytecode on the stack
    for (bytecode) |b| {
        dispatcher.push(Value{ .byte = b });
    }
    while (dispatcher.programCounter < bytecode.len) : (dispatcher.programCounter += 1) {
        dispatcher.jump(dispatch);
    }
}
