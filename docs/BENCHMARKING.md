# Benchmarking Guide

This guide explains how to run benchmarks, interpret results, and ensure accurate performance measurements for VAR.

## Quick Start

### Run Built-in Benchmarks

```bash
# Fast benchmark (100M decisions)
zig build benchmark -Doptimize=ReleaseFast

# Statistical analysis with hyperfine
hyperfine --warmup 3 --runs 10 "zig build benchmark -Doptimize=ReleaseFast"
```

### Expected Output

```
1.19B/sec test: 1323125403.21 decisions/sec (75578626 ns total)
```

## Benchmark Methodology

### Test Configuration

- **Batch size**: 100M decisions for stable measurement
- **Data distribution**:
  - Query volumes: 1.0 - 1000.0 (uniform random)
  - World volumes: 100K - 1M (uniform random)
- **PRNG seed**: 0 (deterministic results)

### Performance Metrics

- **Throughput**: Decisions per second (higher is better)
- **Latency**: Nanoseconds per decision (lower is better)
- **Total time**: Wall-clock time for entire batch

### Calculation

```zig
const throughput = batch_size / (end_time - start_time) * 1e9;
const latency = (end_time - start_time) / batch_size;
```

## Statistical Analysis

### Using Hyperfine

```bash
# Install hyperfine
# Ubuntu/Debian: sudo apt install hyperfine
# macOS: brew install hyperfine
# Windows: winget install sharkdp.hyperfine

# Run statistical benchmark
hyperfine \
  --warmup 3 \
  --runs 10 \
  --export-json results.json \
  "zig build benchmark -Doptimize=ReleaseFast"
```

### Interpreting Results

```
Benchmark 1: zig build benchmark -Doptimize=ReleaseFast
  Time (mean ± σ):     75.6 ms ±   2.1 ms
  Range (min … max):   72.8 ms …  79.2 ms

  Mean: 75.6 ms (75,600,000 ns)
  Throughput: 100M / 0.0756s = 1.32B/sec
  Latency: 0.0756s / 100M = 0.76 ns/decision
```

## Performance Validation

### Consistency Checks

1. **Multiple runs**: Results should vary <5%
2. **CPU pinning**: Use `taskset` for stable results
3. **System load**: Run on idle system
4. **Power settings**: Ensure performance mode

### CPU Affinity (Linux)

```bash
# Pin to cores 0-7 for consistent results
taskset -c 0-7 zig build benchmark -Doptimize=ReleaseFast

# Check available cores
nproc
lscpu | grep "CPU(s)"
```

### System Preparation

```bash
# Disable CPU frequency scaling (Linux)
sudo cpupower frequency-set -g performance

# Check AVX2 support
grep avx2 /proc/cpuinfo

# Monitor system load
uptime
top -bn1 | head -10
```

## Custom Benchmarks

### Creating Benchmark Programs

```zig
// custom_benchmark.zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Custom batch size
    const batch_size = 10_000_000;

    // Allocate data
    var queries = try allocator.alloc(f32, batch_size);
    defer allocator.free(queries);
    var worlds = try allocator.alloc(f32, batch_size);
    defer allocator.free(worlds);
    var decisions = try allocator.alloc(var_mod.Decision, batch_size);
    defer allocator.free(decisions);

    // Generate test data
    var prng = std.Random.DefaultPrng.init(42);
    const rand = prng.random();

    for (queries, worlds) |*q, *w| {
        q.* = rand.float(f32) * 1000.0 + 1.0;
        w.* = 100_000.0 + rand.float(f32) * 900_000.0;
    }

    // Benchmark different configurations
    const configs = [_]var_mod.Config{
        .{ .simd_enabled = true },   // SIMD mode
        .{ .simd_enabled = false },  // Scalar mode
    };

    for (configs, 0..) |config, i| {
        const router = var_mod.VAR.init(config);

        // Warmup
        _ = router.route(100.0, 1000.0);

        // Timed run
        const start = std.time.nanoTimestamp();
        try router.routeBatch(queries, worlds, decisions);
        const end = std.time.nanoTimestamp();

        const ns_total = end - start;
        const throughput = @as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0 / @as(f64, @floatFromInt(ns_total));
        const latency = @as(f64, @floatFromInt(ns_total)) / @as(f64, @floatFromInt(batch_size));

        const mode = if (i == 0) "SIMD" else "Scalar";
        std.debug.print("{s}: {d:.1} M/sec, {d:.1} ns/decision\n",
                       .{mode, throughput / 1_000_000.0, latency});
    }
}
```

### Running Custom Benchmarks

```bash
zig run custom_benchmark.zig
```

## Comparative Analysis

### SIMD vs Scalar Performance

| Configuration | Throughput | Latency | Speedup |
|---------------|------------|---------|---------|
| SIMD (AVX2)   | 1.32 B/sec | 0.76 ns | 1100x  |
| Scalar        | 1.2 M/sec  | 833 ns  | 1x     |

### Batch Size Impact

```bash
# Test different batch sizes
for size in 1000 10000 100000 1000000 10000000; do
    echo "Batch size: $size"
    sed -i "s/const batch_size = .*/const batch_size = ${size};/" benchmarks/var_benchmark.zig
    zig build benchmark -Doptimize=ReleaseFast
done
```

### Threshold Tuning

```zig
// Test different GPU thresholds
const thresholds = [_]f32{ 0.001, 0.01, 0.05, 0.1 };

for (thresholds) |thresh| {
    const config = var_mod.Config{ .gpu_threshold = thresh };
    const router = var_mod.VAR.init(config);

    // Benchmark with this threshold
    // Measure both throughput and routing distribution
}
```

## Profiling and Analysis

### CPU Profiling (Linux)

```bash
# Install perf
sudo apt install linux-tools-common linux-tools-generic

# Profile benchmark
perf record -g zig build benchmark -Doptimize=ReleaseFast
perf report
```

### Memory Profiling

```bash
# Use Valgrind for memory analysis
valgrind --tool=cachegrind zig build benchmark -Doptimize=ReleaseFast
cg_annotate cachegrind.out.*
```

### Flame Graphs

```bash
# Install FlameGraph tools
git clone https://github.com/brendangregg/FlameGraph

# Generate flame graph
perf record -F 99 -g -- zig build benchmark -Doptimize=ReleaseFast
perf script | FlameGraph/stackcollapse-perf.pl | FlameGraph/flamegraph.pl > flame.svg
```

## Troubleshooting Benchmarks

### Inconsistent Results

**Problem**: Throughput varies between runs

**Solutions**:
- Pin CPU cores: `taskset -c 0-7`
- Disable frequency scaling
- Run on idle system
- Increase warmup iterations

### Lower Than Expected Performance

**Problem**: Getting <1B/sec on modern hardware

**Causes**:
- SIMD disabled: Check `simd_enabled = true`
- Wrong optimization: Use `ReleaseFast`
- CPU doesn't support AVX2: Check `grep avx2 /proc/cpuinfo`
- Memory bandwidth limited: Try smaller batches

### Validation

**Verify SIMD is working**:

```zig
// Add debug prints to routeBatch
std.debug.print("SIMD enabled: {}\n", .{self.config.simd_enabled});
std.debug.print("Batch size: {}\n", .{query_vols.len});
```

**Check AVX2 support**:

```bash
# Linux
grep avx2 /proc/cpuinfo

# macOS
sysctl -a | grep avx

# Windows (PowerShell)
Get-WmiObject -Class Win32_Processor | Select-Object -Property Name
```

## Performance Regression Testing

### Baseline Establishment

```bash
# Establish baseline
hyperfine --warmup 5 --runs 20 \
  --export-json baseline.json \
  "zig build benchmark -Doptimize=ReleaseFast"
```

### Regression Detection

```bash
# Compare against baseline
hyperfine --warmup 5 --runs 20 \
  --export-json current.json \
  "zig build benchmark -Doptimize=ReleaseFast"

# Analyze difference
jq '.results[0].mean' baseline.json current.json
```

### Automated Regression Testing

```bash
#!/bin/bash
# regression_test.sh

BASELINE_FILE="baseline.json"
CURRENT_FILE="current.json"

# Run current benchmark
hyperfine --warmup 5 --runs 20 \
  --export-json "$CURRENT_FILE" \
  "zig build benchmark -Doptimize=ReleaseFast"

# Compare with baseline
if [ -f "$BASELINE_FILE" ]; then
    BASELINE=$(jq '.results[0].mean' "$BASELINE_FILE")
    CURRENT=$(jq '.results[0].mean' "$CURRENT_FILE")

    # Allow 5% regression tolerance
    THRESHOLD=$(echo "$BASELINE * 1.05" | bc -l)

    if (( $(echo "$CURRENT > $THRESHOLD" | bc -l) )); then
        echo "⚠️  Performance regression detected!"
        echo "Baseline: ${BASELINE}s"
        echo "Current:  ${CURRENT}s"
        exit 1
    else
        echo "✅ Performance within tolerance"
    fi
else
    echo "📊 Establishing new baseline"
    cp "$CURRENT_FILE" "$BASELINE_FILE"
fi
```

## Advanced Benchmarking

### Multi-threaded Benchmarks

```zig
// Future: multi-threaded benchmarking
const num_threads = try std.Thread.getCpuCount();
var threads = try allocator.alloc(std.Thread, num_threads);

// Partition work across threads
// Measure total throughput
```

### Memory Bandwidth Testing

```zig
// Test memory bandwidth impact
const sizes = [_]usize{ 1_000, 10_000, 100_000, 1_000_000, 10_000_000, 100_000_000 };

for (sizes) |size| {
    // Benchmark with different batch sizes
    // Plot throughput vs batch size
}
```

### Cache Performance Analysis

```zig
// Test cache effects
// Vary data access patterns
// Measure L1/L2/L3 cache impact
```

This comprehensive benchmarking approach ensures accurate, reproducible performance measurements and helps detect regressions early in development.