# Installation Guide

This guide covers how to install and set up VAR (Volume Adaptive Routing) in your project.

## Prerequisites

### System Requirements

- **Operating System**: Linux, macOS, or Windows
- **CPU**: x86_64 with AVX2 support (Intel Haswell or later, AMD Ryzen or later)
- **Memory**: 4GB RAM minimum (8GB recommended for development)
- **Storage**: 100MB free space

### Software Requirements

- **Zig**: Version 0.15.1 or later
- **Git**: For cloning the repository (optional)

## Installation Methods

### Method 1: Zig Package Manager (Recommended)

Add VAR as a dependency to your `build.zig.zon` file:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .var = .{
            .url = "https://github.com/boonzy00/var/archive/v1.0.0.tar.gz",
            .hash = "TODO: Add actual hash after first release",
        },
    },
}
```

Then fetch and build:

```bash
zig fetch --save https://github.com/boonzy00/var/archive/v1.0.0.tar.gz
zig build
```

### Method 2: Git Submodule

Add VAR as a git submodule:

```bash
git submodule add https://github.com/boonzy00/var.git vendor/var
```

Then reference it in your `build.zig`:

```zig
const var_dep = b.dependency("var", .{});
const var_mod = var_dep.module("var");
```

### Method 3: Manual Download

Download the latest release from GitHub:

```bash
curl -L https://github.com/boonzy00/var/archive/v1.0.0.tar.gz -o var-v1.0.0.tar.gz
tar -xzf var-v1.0.0.tar.gz
```

Copy `src/var.zig` to your project's source directory.

## Build Configuration

### Basic Setup

In your `build.zig`, add VAR as a module:

```zig
const var_mod = b.createModule(.{
    .root_source_file = b.path("path/to/var.zig"),
    .target = target,
    .optimize = optimize,
});

const my_exe = b.addExecutable(.{
    .name = "my-app",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});

my_exe.root_module.addImport("var", var_mod);
```

### Release Builds

For maximum performance, use ReleaseFast optimization:

```bash
zig build -Doptimize=ReleaseFast
```

### SIMD Detection

VAR automatically detects AVX2 support at compile time. To force scalar mode:

```zig
const router = var_mod.VAR.init(.{ .simd_enabled = false });
```

## Testing Installation

### Run Tests

Verify your installation by running the test suite:

```bash
zig build test
```

### Run Benchmarks

Test performance with the built-in benchmarks:

```bash
zig build benchmark -Doptimize=ReleaseFast
```

Expected output: `1.19B/sec test: ~1.32B decisions/sec`

### Example Program

Create a simple test program:

```zig
// test_var.zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const router = var_mod.VAR.init(null);

    // Test single routing
    const decision = router.route(1.0, 1000.0);
    std.debug.print("Decision: {}\n", .{decision});

    // Test batch routing
    var queries = [_]f32{1.0, 100.0};
    var worlds = [_]f32{1000.0, 1000.0};
    var decisions: [2]var_mod.Decision = undefined;

    try router.routeBatch(&queries, &worlds, &decisions);
    std.debug.print("Batch decisions: {any}\n", .{decisions});
}
```

Run it:

```bash
zig run test_var.zig
```

## Platform-Specific Notes

### Linux

- Ensure AVX2 support: `grep avx2 /proc/cpuinfo`
- For best performance, pin to specific CPU cores: `taskset -c 0-7 zig build benchmark`

### macOS

- AVX2 is supported on Intel Macs and Apple Silicon (with Rosetta)
- Use Activity Monitor to verify CPU usage during benchmarking

### Windows

- AVX2 support required (Windows 8.1 or later recommended)
- Use Task Manager to monitor CPU usage
- Power settings may affect benchmark consistency

## Troubleshooting

### Compilation Errors

**Error**: `error: SIMD vectorization requires AVX2`

- **Solution**: Your CPU doesn't support AVX2. Use scalar mode: `.{ .simd_enabled = false }`

**Error**: `error: unable to find 'var' module`

- **Solution**: Check your `build.zig` module imports and paths

### Performance Issues

**Slow performance**: Ensure you're using ReleaseFast optimization:

```bash
zig build -Doptimize=ReleaseFast
```

**Inconsistent benchmarks**: Pin CPU cores for stable results:

```bash
taskset -c 0-7 zig build benchmark -Doptimize=ReleaseFast
```

### AVX2 Detection

To check if your system supports AVX2:

**Linux/macOS**:
```bash
grep avx2 /proc/cpuinfo  # Linux
sysctl -a | grep avx     # macOS
```

**Windows**:
```cmd
wmic cpu get caption, name
# Look for Intel Haswell or later, or AMD Ryzen
```

## Next Steps

- 📖 Read the [API Documentation](API.md)
- 🚀 Follow the [Quick Start Guide](QUICKSTART.md)
- ⚡ Learn about [Performance Tuning](PERFORMANCE.md)