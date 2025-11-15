# VAR v1.0 — **1.32B Routing Decisions/sec**

[![VAR v1.0.0](https://img.shields.io/badge/VAR-v1.0.0-brightgreen.svg)](https://github.com/boonzy00/var/releases/tag/v1.0.0)
[![CI](https://github.com/boonzy00/var/actions/workflows/ci.yml/badge.svg)](https://github.com/boonzy00/var/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Zig 0.15.1](https://img.shields.io/badge/Zig-0.15.1-blue.svg)](https://ziglang.org/)

**GPU for narrow. CPU for broad. Auto-routed in 0.76 ns.**

```zig
try router.routeBatch(&queries, &worlds, &decisions);
```

**AVX2 SIMD. 1100× faster. Zero tuning. Pure Zig.**

---

## Performance

| Impl   | Throughput     | Latency    | Speedup |
|--------|----------------|------------|---------|
| **SIMD** | **1.32 B/sec** | **0.76 ns** | **1100×** |
| Scalar | 1.2 M/sec      | 833 ns     | 1×      |

[Proof → benchmarks/results/bench-results.json](benchmarks/results/bench-results.json)

---

## Install

```bash
zig fetch --save https://github.com/boonzy00/var/archive/v1.0.0.tar.gz
```

---

## Documentation

- [Quick Start](docs/QUICKSTART.md)
- [API Reference](docs/API.md)
- [Performance Guide](docs/PERFORMANCE.md)

---

## License

MIT
