# Changelog

## [1.0.0] - 2025-11-15

### Added
- AVX2 SIMD vectorization (`routeBatch`) — **1.32B decisions/sec**
- 1100× speedup over scalar
- Full enterprise documentation (10 guides)
- Cross-platform CI/CD
- `varRoute()` compile-time dispatch

### Changed
- API frozen for v1.x
- Scalar baseline: 1.2M/sec → 833 ns

### Performance
- SIMD: 1.32B/sec (0.76 ns)
- Scalar: 1.2M/sec (833 ns)
