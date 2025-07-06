⚡ opcode - Zero-copy binary serialization with compile-time guarantees 🎩
A blazing fast binary serialization library that uses opcode-based dispatch for maximum performance. Unlike traditional serialization formats, opcode generates fixed binary layouts with compile-time size calculation, zero-copy deserialization, and automatic protocol versioning.
Key Features:

🚀 Opcode dispatch - Single byte reads for enum variants
📐 Compile-time sizes - Know your message sizes at compile time
🔥 Zero-copy deserialization - Borrow data directly from buffers
🔄 Protocol versioning - Evolve schemas without breaking compatibility
📦 Varint encoding - Automatic space-efficient integer encoding
🌊 Streaming support - Process large messages without buffering
⚙️ SIMD optimizations - Hardware-accelerated encoding/decoding
🛡️ Wire format stability - Guaranteed binary compatibility

Perfect for high-performance network protocols, game networking, embedded systems, and anywhere you need predictable, fast binary serialization.

Currently being ported and teased out from another library I am working on. Nothing to use yet, check back in very soon!