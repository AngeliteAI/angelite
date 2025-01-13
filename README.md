# FAST
Zero-cost, hyper-optimized computation.

## Features
### Requires nightly rust.

- ⚡️ Zero-overhead abstractions
- 🚀 SIMD-first design
- 🎯 Cache-optimal algorithms
- 🧮 Vectorized operations
- 🎲 Flexible random number generation
- 🛡️ Compile-time validation

## Performance

Raw computational speed is a core principle:
- Direct SIMD mapping
- Cache-line alignment
- Vectorized processing
- Minimal runtime overhead
- Deterministic and repeatable results

## Installation

```toml
[dependencies]
fast = "0.1.0"
```
## Why Fast?
*   **SIMD Vectorization:** Leverages SIMD intrinsics for parallel operations on data arrays, boosting performance by processing multiple elements simultaneously.

*   **Compile-Time Shuffle:** Utilizes compile-time constants and `const fn` to define SIMD data shuffle patterns, minimizing runtime overhead.

*  **PCG Randomness:** Employs a SIMD-optimized PCG generator for fast, high-quality pseudorandom number generation. Weyl sequences are added for increased entropy.

*   **Probability Distributions:** Provides optimized sampling for Normal, Exponential, Gamma, Poisson, and Beta distributions using math intrinsics.

*   **Distribution Transforms:** Enables composition of distributions via transforms, additions, mixes, and multiplies allowing for the building of complex simulations.

## Requirements

- Rust 1.70+
- CPU with SIMD support

## Platform Support

- x86_64 (AVX, AVX2, AVX-512)
- ARM (NEON, SVE)

## Safety

- Compile-time validation
- Bounds checking elimination
- Alignment verification
- Type safety guarantees
- Architecture validation

## Contributing

FAST is a low-level crate for high-performance computation. We welcome:

1. Performance improvements
2. Architecture optimizations
3. New algorithms
4. Documentation
5. Benchmarks

## License

Apache 2.0 / MIT dual license

## FAQ

### Why FAST?

- **Zero Cost:** No runtime overhead
- **SIMD First:** Built for vector instructions
- **Cache Optimal:** Memory layout tuned
- **Repeatable:** Results are deterministic given the same inputs.

### FAST vs Others?

- Focus on raw performance
- SIMD by default
- Designed for low-level control
- Minimal abstractions

### What about random numbers?

- Provides flexible and performant random number generation
- Useful for simulation and statistical applications
