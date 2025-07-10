# ⚡ opcode

**Zero-copy binary serialization where your wire format is your instruction set** 🚀

opcode is a blazing fast binary serialization library that unifies data encoding with execution logic. Unlike traditional formats that just move bytes, opcode uses single-byte dispatch to create protocols that are simultaneously data formats and executable specifications. 🎯


## 🎯 Why opcode?

Stop parsing, start executing. When your wire format encodes both data and operations, every network call becomes as safe and fast as a local function call. ⚡

Built out of pure frustration with existing serialization libraries while trying to make a game. Why are they all so mid? opcode is what happens when you realize protocols can be smart, not just fast. 🛡️


## 🚀 Key Features

- [ ] **🔥 Opcode dispatch** - Single byte reads determine both type and operation
- [ ] **📐 Compile-time guarantees** - Know message sizes and validity at compile time  
- [ ] **⚡ Zero-copy by default** - Borrow data directly from buffers, no allocations
- [ ] **🧠 Executable serialization** - Encode validation and execution logic in the wire format
- [ ] **🔄 Protocol versioning** - Evolve schemas without breaking compatibility
- [ ] **📦 Varint encoding** - Automatic space-efficient integer encoding
- [ ] **🌊 Streaming support** - Process gigabytes without buffering
- [ ] **⚙️ SIMD optimizations** - Hardware-accelerated encoding/decoding
- [ ] **🛡️ Wire format stability** - Guaranteed binary compatibility


## 💡 Perfect For

- **🔐 Secure remote execution** - Build VPN control planes where the protocol itself prevents invalid operations
- **📈 High-frequency trading** - Single-digit nanosecond dispatch for millions of messages/sec
- **🖥️ Fleet management** - Control 10K machines with the overhead of local function calls
- **🎮 Authoritative game servers** - Validate player actions in <1ms with zero allocations
- **🔧 Embedded systems** - Predictable memory usage, no heap allocations required
- **🏗️ Distributed databases** - Consensus protocols with built-in operation validation
- **🚦 Real-time control systems** - Deterministic latency for safety-critical operations
- **☁️ Cloud orchestration** - Manage entire data centers with minimal protocol overhead


## 🔥 What Makes opcode Different?

Traditional serialization libraries separate data encoding from business logic. opcode fuses them: 🎯

```rust
// Define executable operations with the #[op] macro 🧠
#[op]
enum VMControl {
    #[code(0x10)] Start { vm_id: u64, config: VMConfig },
    #[code(0x11)] Stop { vm_id: u64, force: bool },
    #[code(0x12)] Status { vm_id: u64 },
}

// Zero-cost dispatch - the protocol IS the implementation ⚡
match opcode!(VMControl, stream) {
    VMControl::Start { vm_id, config } => vm.start(vm_id, config),
    VMControl::Stop { vm_id, force } => vm.stop(vm_id, force),
    VMControl::Status { vm_id } => vm.status(vm_id),
}
```


## 🛠️ Coming Soon

Currently extracting battle-tested patterns from production systems. This isn't another weekend project - it's designed to be the foundation for the next generation of distributed systems. 🏗️

**🎯 v0.1 target: 2026**

Good infrastructure takes time to build right. opcode is being carefully extracted from production code handling millions of operations daily. 💪


## 🌟 Part of Something Bigger

opcode is the first component of a new ecosystem for building secure, distributed infrastructure. Where traditional tools separate networking, serialization, and execution, we're building unified primitives that make distributed systems as easy to reason about as local programs. 🚀

---

*Currently being extracted from production systems. ⭐ Star/watch to be notified when the first release drops! 🔔*