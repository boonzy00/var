# VAR — Volume-Adaptive Routing

![VAR](https://img.shields.io/badge/Routing-VAR-brightgreen)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Zig Version](https://img.shields.io/badge/zig-0.15.1-blue.svg)](https://ziglang.org/)
[![CI](https://github.com/boonzy00/var/actions/workflows/ci.yml/badge.svg)](https://github.com/boonzy00/var/actions)

**GPU for narrow. CPU for broad. Auto-routed by query volume.**

```zig
const var = @import("var");
const router = var.VAR.init(null);

const decision = router.route(query_volume, world_volume);
```

## What It Is

VAR is a single-function decision engine that tells you whether a spatial query should run on the CPU or GPU, based on how much of the world it touches.

- **Input:** query_volume + world_volume
- **Output:** .gpu or .cpu
- **Rule:**

```zig
if (query_volume / world_volume < threshold) {
    return .gpu;
} else {
    return .cpu;
}
```

That’s it.

## Why It Works

| Query Type                     | Expected Hits | Best Processor | Why                     |
|--------------------------------|---------------|----------------|-------------------------|
| Narrow (frustum, point, small box)      | < 100 objects | GPU            | Parallelism wins        |
| Broad (proximity, physics, large region)    | > 1,000 objects| CPU            | Memory bandwidth wins    |

Manual routing = bugs, tuning, inconsistency.  
VAR = one line, zero tuning, deterministically correct.

VAR routes correctly based on selectivity, optimizing for parallelism (GPU) vs. memory bandwidth (CPU).  
Validated with comprehensive unit tests covering edge cases.

## When to Use It

Use VAR any time you:

- Have a spatial index (any kind)
- Run mixed query workloads
- Want zero-tuning performance

**Examples:**

- Game engine: frustum culling (narrow) + AI perception (broad)
- Robotics: LiDAR obstacle check (narrow) + path planning (broad)
- GIS: map zoom (narrow) + region query (broad)

## How to Use It

1. **Install**

   ```bash
   zig fetch --save https://github.com/boonzy00/var/archive/v0.1.0.tar.gz
   ```

2. **Basic**

   ```zig
   const var = @import("var");
   const router = var.VAR.init(null);

   const world_vol = 1000.0 * 1000.0 * 1000.0; // 1km³
   const query_vol = 10.0 * 10.0 * 10.0;       // 10m box

   const decision = router.route(query_vol, world_vol);
   // → .gpu
   ```

3. **With Your Own Volume Logic**

   ```zig
   fn boxVolume(size: @Vector(3, f32)) f32 {
       return size[0] * size[1] * size[2];
   }

   const query_vol = boxVolume(.{10, 10, 10});
   const decision = router.route(query_vol, world_vol);
   ```

## Configuration

```zig
const router = var.VAR.init(.{
    .gpu_threshold = 0.005,     // More aggressive GPU usage
    .cpu_cores = 16,            // Adjusts threshold slightly
    .gpu_available = true,      // Set false on CPU-only systems
});
```

## How It Decides (The Math)

```zig
selectivity = query_volume / world_volume

if (selectivity < threshold) {
    return .gpu;
} else {
    return .cpu;
}
```

- **Threshold:** 0.005 (0.5%) by default
- **Why 0.005?** Reasonable default based on typical GPU/CPU performance characteristics. Balances parallelism (GPU wins below 0.5%) vs. memory bandwidth (CPU wins above).
- Adjusted for CPU core count (more cores → slightly higher threshold, less GPU usage)
- **Threshold:** 0.01 (1%) by default
- **Why 0.01?** A sensible default that balances GPU parallelism vs CPU memory bandwidth on common hardware.
- **Configurable:** Use `Config.gpu_threshold` to override the default.
- **CPU core scaling:** VAR scales the effective threshold by CPU cores so more CPU cores reduce the threshold (making GPU usage less likely). For example, with the default 8 cores, the configured threshold is used unchanged; 16 cores halve the effective threshold.

## Safety & Edge Cases

| Case                        | Behavior          |
|-----------------------------|-------------------|
| world_volume == 0          | → .cpu            |
| gpu_available = false      | → .cpu            |
| Negative volumes            | → clamped to 0    |
| Infinite / NaN             | → .cpu            |

## Benchmarks

Run the official benchmark script for reproducible, statistically rigorous results:

```bash
cd bench
./run_bench.sh
```

This generates `bench-results.md` with raw hyperfine output including mean, standard deviation, range, and system info.

**Latest results (AMD Ryzen 7 5700, Zig 0.15.1):**
- Workload: 1M queries (20% narrow, 80% broad)
- Mean time: ~50ms for 1M decisions
- Throughput: ~20M decisions/sec
- Avg latency: ~50ns per decision
- Note: Narrow queries leverage GPU acceleration; broad queries are CPU-bound
- Full report: `bench/bench-results.md` 
- Memory overhead: <1KB per router instance

Full benchmark report: [bench-results.md](bench/bench-results.md)

## Build & Test

```bash
zig build test
```

For performance benchmarks:
```bash
cd bench && ./run_bench.sh
```

## Limitations

- Does not build or run the query
- Assumes you compute query_volume correctly
- GPU memory may limit concurrent narrow queries

## Future Ideas (Not in v0.1)

- ML-based threshold tuning
- Multi-GPU load balancing
- Ray-tracing core routing

## License

MIT
