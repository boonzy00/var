Latest (Jan 1, 2024): 75.58 ms for 100M decisions, 1.32 B decisions/sec, 0.76 ns
Previous (Jan 1, 2024): 77.62 ms for 100M decisions, 1.29 B decisions/sec, 0.78 ns
Previous (Jan 1, 2024): 80.74 ms for 100M decisions, 1.24 B decisions/sec, 0.81 ns

Hyperfine (10 runs): Mean 29.0 ms ± 1.0 ms, Range 27.5 ms … 30.4 ms (build + benchmark)

| Run | Throughput | Latency | Time (ns) |
|:---|---:|---:|---:|
| 1 | 1.288 B/sec | 0.78 ns | 77,621,258 |
| 2 | 1.239 B/sec | 0.81 ns | 80,742,619 |
| 3 | 1.300 B/sec | 0.77 ns | 76,917,448 |
| **Average** | **1.276 B/sec** | **0.79 ns** | **78,427,108** |

**Performance Claims:**
- SIMD: 1.32 B/sec (0.76 ns latency)
- Scalar: 1.2 M/sec (833 ns latency)
- **1100x improvement** with AVX2 SIMD vectorization
