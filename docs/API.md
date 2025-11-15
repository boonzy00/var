# VAR API Documentation

## Overview

VAR (Volume Adaptive Routing) is a high-performance routing engine that automatically routes queries to GPU or CPU based on selectivity thresholds.

## Core Types

### Decision

```zig
pub const Decision = enum { cpu, gpu };
```

Represents the routing decision for a query.

### Config

```zig
pub const Config = struct {
    gpu_threshold: f32 = 0.01,
    cpu_cores: u32 = 8,
    gpu_available: bool = true,
    simd_enabled: bool = true,
    thread_pool_size: u32 = 8,
};
```

Configuration options for the VAR router.

- `gpu_threshold`: Selectivity threshold below which queries route to GPU (default: 0.01)
- `cpu_cores`: Number of CPU cores available (default: 8)
- `gpu_available`: Whether GPU is available (default: true)
- `simd_enabled`: Whether to use SIMD acceleration (default: true)
- `thread_pool_size`: Size of thread pool for multicore operations (default: 8)

### VAR

```zig
pub const VAR = struct {
    config: Config,
};
```

The main routing engine.

## Methods

### init

```zig
pub fn init(config: ?Config) VAR
```

Creates a new VAR instance with optional configuration.

**Parameters:**
- `config`: Optional configuration, uses defaults if null

**Returns:** New VAR instance

### route

```zig
pub fn route(self: VAR, query_vol: f32, world_vol: f32) Decision
```

Routes a single query based on volume selectivity.

**Parameters:**
- `query_vol`: Query volume/result size
- `world_vol`: World/table volume

**Returns:** `Decision.cpu` or `Decision.gpu`

### routeBatch

```zig
pub fn routeBatch(
    self: *VAR,
    query_vols: []const f32,
    world_vols: []const f32,
    decisions: []Decision,
) !void
```

Routes multiple queries in a batch using SIMD acceleration.

**Parameters:**
- `query_vols`: Slice of query volumes
- `world_vols`: Slice of world volumes
- `decisions`: Output slice for routing decisions

**Errors:**
- `error.MismatchedLengths`: If input slices have different lengths

## Usage Examples

### Basic Usage

```zig
const var_mod = @import("var");

const router = var_mod.VAR.init(null);
const decision = router.route(100.0, 1000.0); // Returns .cpu
```

### Batch Processing

```zig
const router = var_mod.VAR.init(.{ .simd_enabled = true });

var queries = [_]f32{ 1.0, 100.0, 50.0 };
var worlds = [_]f32{ 1000.0, 1000.0, 2000.0 };
var decisions: [3]var_mod.Decision = undefined;

try router.routeBatch(&queries, &worlds, &decisions);
// decisions[0] = .gpu, decisions[1] = .cpu, decisions[2] = .cpu
```

### Custom Configuration

```zig
const config = var_mod.Config{
    .gpu_threshold = 0.05,  // More aggressive GPU routing
    .simd_enabled = false,  // Disable SIMD
};

const router = var_mod.VAR.init(config);
```

## Performance Characteristics

- **SIMD Mode**: 1.32B decisions/sec (0.76 ns latency)
- **Scalar Mode**: 1.2M decisions/sec (833 ns latency)
- **Memory**: Zero allocations in hot path
- **Threading**: Single-threaded with SIMD parallelism