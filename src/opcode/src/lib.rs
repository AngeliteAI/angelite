#![no_std]

use alloc::{boxed::Box, vec::Vec};
use core::{ marker::PhantomData, mem::MaybeUninit};
extern crate core;
extern crate alloc;

pub struct VirtualMemory(Vec<u8>);

pub struct VirtualPtr(u64);

pub enum Ownership {
    Owned,
    Ref,
    Mut,
    Moved
}

pub struct Lifetime(pub u64);

pub struct Ref {
    addr: VirtualPtr,
    pointee: TypeId,
    owner: Ownership,
    lifetime: Option<Lifetime>,
}

pub struct StackPtr {
    base: VirtualPtr,
    active: VirtualPtr,
}

pub struct Variant {

}

pub struct TypeId(u128);

pub enum TypeKind {
    // Primitives
    Integer { width: u8, signed: bool },
    Float { width: u8 },
    Pointer,
    Array { element_type: u32, len: u32 },
    Struct { field_count: u32 },
    Sum {
        tag_type: Option<TypeId>,
        variants: Vec<Variant>,
        safety: SumSafety,
    },
}

#[derive(Debug, Clone)]
pub enum SumSafety {
    Untagged,    // C union - no safety
    Tagged,      // Zig union - manual checking
    Safe,        // Rust enum - compiler checking
}

pub struct TypeInfo {
    internal_id: TypeId,
    kind: TypeKind,
    size: u64,
    alignment: u64,
}



pub struct Error {

}

pub struct Int(VirtualPtr);
pub struct Float(VirtualPtr);

pub struct Seq {
    data: VirtualPtr,
    len: usize,
    capacity: Option<usize>,
    element: TypeInfo,
    owner: Ownership
}

pub enum FuncKind {
    Bytecode {
        addr: VirtualPtr,
    },
    Closure {
        addr: VirtualPtr,
        capture: VirtualPtr,
        capture_size: u64,
    },
    Builtin {
        name: &'static str,
    },
    Foreign {
        entry_point: *const u8
    }
}

pub struct FuncSig {
    pub params: Vec<TypeId>,
    pub ret: Option<TypeId>,
}

pub struct Func {
    pub kind: FuncKind,
    pub sig: FuncSig,
}

pub enum Value {
    Int(Int),
    Float(Float),
    Seq(Seq),
    Ref(Ref),
    Err(Error),
    Func(Func),
    Unit,
    Never,
}

pub struct VirtualMachine {
    pub memory: VirtualMemory,
    pub heap: VirtualPtr,
    pub stack: StackPtr,
    pub call_stack: Vec<CallFrame>,
    pub function_table: Vec<Function>,
    pub builtins: Vec<BuiltinFunction>,
}

pub struct BuiltinFunction {
    name: &'static str,
    imp: fn(&mut VirtualMachine, &[Value]) -> Result<Value, Error>,
    sig: FuncSig
}