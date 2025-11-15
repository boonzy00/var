# Quick Start Guide

Get VAR up and running in your project in 5 minutes.

## Prerequisites

- Zig 0.15.1 or later
- CPU with AVX2 support (Intel Haswell+, AMD Ryzen+)

## 1. Add VAR to Your Project

### Option A: Zig Package Manager

Add to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .var = .{
            .url = "https://github.com/boonzy00/var/archive/v1.0.0.tar.gz",
            .hash = "TODO: Add actual hash",
        },
    },
}
```

Fetch the dependency:

```bash
zig fetch --save https://github.com/boonzy00/var/archive/v1.0.0.tar.gz
```

### Option B: Direct Download

```bash
curl -L https://github.com/boonzy00/var/archive/v1.0.0.tar.gz -o var.tar.gz
tar -xzf var.tar.gz
cp var-1.0.0/src/var.zig src/
```

## 2. Configure Your Build

Update your `build.zig`:

```zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add VAR module
    const var_mod = b.createModule(.{
        .root_source_file = b.path("src/var.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Your executable
    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    // Import VAR
    exe.root_module.addImport("var", var_mod);

    b.installArtifact(exe);
}
```

## 3. Basic Usage

### Single Query Routing

```zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    // Create router with default settings
    const router = var_mod.VAR.init(null);

    // Route a single query
    // query_vol: estimated result size
    // world_vol: table/index size
    const decision = router.route(100.0, 10000.0);

    std.debug.print("Route to: {}\n", .{decision});
    // Output: Route to: cpu (because selectivity = 100/10000 = 0.01 < 0.01 threshold)
}
```

### Batch Routing (High Performance)

```zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    // Create router
    const router = var_mod.VAR.init(null);

    // Prepare batch data
    var queries = [_]f32{ 1.0, 100.0, 1000.0 };     // Query volumes
    var worlds = [_]f32{ 1000.0, 1000.0, 1000.0 };  // World volumes
    var decisions: [3]var_mod.Decision = undefined;  // Results

    // Route entire batch at once (SIMD accelerated)
    try router.routeBatch(&queries, &worlds, &decisions);

    // Print results
    for (decisions, 0..) |decision, i| {
        std.debug.print("Query {}: {}\n", .{ i, decision });
    }
    // Output:
    // Query 0: gpu (selectivity = 1/1000 = 0.001 < 0.01)
    // Query 1: cpu (selectivity = 100/1000 = 0.1 > 0.01)
    // Query 2: cpu (selectivity = 1000/1000 = 1.0 > 0.01)
}
```

## 4. Configuration Options

### Custom Threshold

```zig
const config = var_mod.Config{
    .gpu_threshold = 0.05,  // More aggressive GPU routing
    .simd_enabled = true,   // Use SIMD acceleration
};

const router = var_mod.VAR.init(config);
```

### Disable SIMD (for testing)

```zig
const router = var_mod.VAR.init(.{ .simd_enabled = false });
```

## 5. Integration Patterns

### Spatial Query Engine

```zig
const SpatialEngine = struct {
    router: var_mod.VAR,

    pub fn query(self: *SpatialEngine, query_vol: f32, world_vol: f32) Result {
        const decision = self.router.route(query_vol, world_vol);

        return switch (decision) {
            .gpu => self.gpuQuery(query_vol, world_vol),
            .cpu => self.cpuQuery(query_vol, world_vol),
        };
    }
};
```

### Compile-Time Routing

```zig
// When volumes are known at compile time
const result = var_mod.varRoute(
    50.0,    // query volume
    1000.0,  // world volume
    gpuFunction,
    cpuFunction
);
// Automatically calls gpuFunction() at compile time
```

## 6. Performance Verification

### Run Benchmarks

```bash
# Build and run performance tests
zig build benchmark -Doptimize=ReleaseFast
```

Expected output: `1.19B/sec test: ~1.32B decisions/sec`

### Quick Performance Test

```zig
// Quick throughput test
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const router = var_mod.VAR.init(null);

    // Create large batch
    const batch_size = 1_000_000;
    var queries = try std.ArrayList(f32).initCapacity(std.heap.page_allocator, batch_size);
    var worlds = try std.ArrayList(f32).initCapacity(std.heap.page_allocator, batch_size);
    var decisions = try std.ArrayList(var_mod.Decision).initCapacity(std.heap.page_allocator, batch_size);

    // Fill with test data
    var i: usize = 0;
    while (i < batch_size) : (i += 1) {
        queries.appendAssumeCapacity(10.0);
        worlds.appendAssumeCapacity(1000.0);
        decisions.appendAssumeCapacity(.cpu);
    }

    // Time the routing
    const start = std.time.nanoTimestamp();
    try router.routeBatch(queries.items, worlds.items, decisions.items);
    const end = std.time.nanoTimestamp();

    const throughput = @as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0 / @as(f64, @floatFromInt(end - start));
    std.debug.print("Throughput: {d:.1} M/sec\n", .{throughput / 1_000_000.0});
}
```

## 7. Next Steps

- 📚 Read the [API Reference](API.md) for detailed documentation
- ⚡ Learn about [Performance Tuning](PERFORMANCE.md)
- 🔧 Check [Installation Guide](INSTALL.md) for advanced setup
- 🏗️ Understand the [Architecture](ARCHITECTURE.md)

## Troubleshooting

### Common Issues

**"SIMD vectorization requires AVX2"**
- Your CPU doesn't support AVX2. Use: `.{ .simd_enabled = false }`

**Slow performance**
- Use ReleaseFast: `zig build -Doptimize=ReleaseFast`

**Inconsistent benchmarks**
- Pin CPU cores: `taskset -c 0-7 zig build benchmark`

Need help? Check the [Troubleshooting Guide](TROUBLESHOOTING.md) or [FAQ](FAQ.md).