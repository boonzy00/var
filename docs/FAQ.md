# Frequently Asked Questions

## General

### What is VAR?

VAR (Volume Adaptive Routing) is a high-performance routing engine that automatically selects between CPU and GPU execution backends based on query selectivity. It achieves **1.32 billion routing decisions per second** through AVX2 SIMD vectorization.

### Why "Volume Adaptive"?

The routing decision is based on data volumes:
- **Query volume**: Estimated result size
- **World volume**: Table/index size
- **Selectivity** = query_volume / world_volume

Low selectivity queries (<1%) route to GPU, high selectivity queries (≥1%) route to CPU.

### What's special about VAR?

- **Pure SIMD performance**: 1100x faster than scalar implementations
- **Zero tuning required**: Works out-of-the-box
- **Simple API**: Just `routeBatch(&queries, &worlds, &decisions)`
- **Production ready**: Comprehensive testing and documentation

## Performance

### How fast is VAR?

| Configuration | Throughput | Latency | Improvement |
|---------------|------------|---------|-------------|
| SIMD (AVX2)   | 1.32 B/sec | 0.76 ns | 1100x      |
| Scalar        | 1.2 M/sec  | 833 ns  | 1x         |

### What hardware do I need?

**Minimum requirements**:
- CPU with AVX2 support (Intel Haswell 2013+, AMD Ryzen+)
- 4GB RAM
- Linux, macOS, or Windows

**Recommended**:
- Modern x86_64 CPU (Intel i5/i7/i9, AMD Ryzen)
- 8GB+ RAM
- SSD storage

### Does it work on ARM?

Currently, VAR requires x86_64 with AVX2. ARM support (NEON SIMD) is planned for future releases.

### Can I use it without SIMD?

Yes! VAR automatically falls back to scalar mode on CPUs without AVX2:

```zig
const router = var_mod.VAR.init(.{ .simd_enabled = false });
```

Performance will be ~1M/sec instead of 1.32B/sec.

## Usage

### How do I add VAR to my project?

**Option 1: Zig Package Manager**
```zig
// build.zig.zon
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .var = .{
            .url = "https://github.com/boonzy00/var/archive/v1.0.0.tar.gz",
            .hash = "TODO: Add hash",
        },
    },
}
```

**Option 2: Direct download**
```bash
curl -L https://github.com/boonzy00/var/archive/v1.0.0.tar.gz -o var.tar.gz
tar -xzf var.tar.gz
cp var-1.0.0/src/var.zig src/
```

### What's the basic usage?

```zig
const var_mod = @import("var");

// Create router
const router = var_mod.VAR.init(null);

// Single query
const decision = router.route(100.0, 1000.0); // Returns .cpu or .gpu

// Batch processing (fast!)
var queries = [_]f32{1.0, 100.0, 1000.0};
var worlds = [_]f32{1000.0, 1000.0, 1000.0};
var decisions: [3]var_mod.Decision = undefined;

try router.routeBatch(&queries, &worlds, &decisions);
```

### How do I choose the GPU threshold?

The default threshold (0.01 = 1%) works for most use cases:

- **Lower threshold** (e.g., 0.001): More queries route to GPU
- **Higher threshold** (e.g., 0.1): More queries route to CPU

```zig
const config = var_mod.Config{
    .gpu_threshold = 0.05,  // 5% selectivity threshold
};
const router = var_mod.VAR.init(config);
```

### Can I use it at compile time?

Yes! For queries with known volumes:

```zig
const result = var_mod.varRoute(
    50.0,    // query volume (compile-time known)
    1000.0,  // world volume (compile-time known)
    gpuFunction,
    cpuFunction
);
// Automatically calls gpuFunction() at compile time
```

## Technical

### How does SIMD acceleration work?

VAR uses AVX2 instructions to process 8 routing decisions simultaneously:

```zig
const Vec8f32 = @Vector(8, f32);
const q_vec: Vec8f32 = .{q0, q1, q2, q3, q4, q5, q6, q7};
const w_vec: Vec8f32 = .{w0, w1, w2, w3, w4, w5, w6, w7};
const sel_vec = q_vec / w_vec;  // SIMD division
const gpu_mask = sel_vec < @splat(threshold);  // SIMD comparison
```

### Why 8-wide vectors?

AVX2 registers are 256 bits wide. Since `f32` is 32 bits, this gives us 8 elements per vector operation.

### What's the memory layout?

- **Input arrays**: Separate arrays for query volumes and world volumes
- **Output array**: Decisions enum array
- **No intermediate allocations**: Everything happens in registers
- **Cache-friendly**: Sequential memory access patterns

### Is it thread-safe?

VAR instances are not thread-safe by design. Create one router per thread:

```zig
// Thread 1
const router1 = var_mod.VAR.init(null);

// Thread 2
const router2 = var_mod.VAR.init(null);
```

### What's the error model?

VAR uses Zig's error system:

```zig
try router.routeBatch(&queries, &worlds, &decisions);
// May return error.MismatchedLengths
```

## Integration

### Can I use it with existing databases?

Yes! VAR is designed to integrate with any system that needs routing decisions:

- **Database query optimizers**
- **Spatial indexes**
- **Machine learning pipelines**
- **Data processing engines**

### Example: Database Integration

```zig
const QueryEngine = struct {
    router: var_mod.VAR,

    pub fn executeQuery(self: *QueryEngine, query_vol: f32, world_vol: f32) Result {
        const decision = self.router.route(query_vol, world_vol);

        return switch (decision) {
            .gpu => self.executeOnGPU(query_vol, world_vol),
            .cpu => self.executeOnCPU(query_vol, world_vol),
        };
    }
};
```

### What about other languages?

VAR is Zig-native, but you can:

1. **Call from C**: Use Zig's C ABI
2. **Embed in other systems**: Compile to static library
3. **Use as CLI tool**: Process data files

## Troubleshooting

### Why am I getting slow performance?

**Check these**:

1. **Use ReleaseFast**:
   ```bash
   zig build -Doptimize=ReleaseFast
   ```

2. **Enable SIMD**:
   ```zig
   const router = var_mod.VAR.init(.{ .simd_enabled = true });
   ```

3. **Check AVX2 support**:
   ```bash
   grep avx2 /proc/cpuinfo
   ```

4. **Pin CPU cores**:
   ```bash
   taskset -c 0-7 your_program
   ```

### SIMD compilation errors?

If you get "SIMD vectorization requires AVX2":

1. **Check CPU**: `grep avx2 /proc/cpuinfo`
2. **Disable SIMD**: `.{ .simd_enabled = false }`
3. **Use newer CPU**: AVX2 required for SIMD mode

### Memory issues?

VAR uses zero heap allocations in the hot path. Memory issues are usually in user code:

```zig
// Correct: Pre-allocate everything
var decisions = try allocator.alloc(var_mod.Decision, batch_size);
defer allocator.free(decisions);

// Wrong: Don't allocate in loop
for (queries) |q| {
    var decision = try allocator.create(var_mod.Decision); // Leak!
}
```

## Development

### How do I contribute?

1. **Fork** the repository
2. **Create** a feature branch
3. **Make** your changes
4. **Test**: `zig build test && zig build benchmark`
5. **Format**: `zig fmt .`
6. **Submit** a pull request

### What's the development workflow?

```bash
git checkout -b feature/my-feature
# Make changes...
zig build test
zig build benchmark -Doptimize=ReleaseFast
zig fmt .
git commit -m "feat: my feature"
git push origin feature/my-feature
# Create PR
```

### How do I run benchmarks?

```bash
# Quick benchmark
zig build benchmark -Doptimize=ReleaseFast

# Statistical analysis
hyperfine --warmup 3 --runs 10 "zig build benchmark -Doptimize=ReleaseFast"

# Custom benchmark
zig run benchmarks/var_benchmark.zig
```

### Can I modify the routing algorithm?

Yes, but carefully! The routing logic is in `src/var.zig`:

```zig
pub fn route(self: VAR, query_vol: f32, world_vol: f32) Decision {
    // Modify this logic
    const selectivity = query_vol / world_vol;
    return if (selectivity < self.config.gpu_threshold) .gpu else .cpu;
}
```

**Important**: Keep SIMD and scalar implementations in sync!

## Future

### What's planned for v2.0?

- **Multi-threading** support
- **AVX-512** support (16-wide vectors)
- **ARM/NEON** support
- **GPU acceleration** integration
- **Machine learning** optimization

### Can I sponsor development?

VAR is MIT licensed and free to use. For commercial support or custom features, please contact the maintainers.

## License

VAR is licensed under the MIT License. See the main README for details.

---

**Still have questions?** Check the [documentation](README.md) or [open an issue](https://github.com/boonzy00/var/issues).