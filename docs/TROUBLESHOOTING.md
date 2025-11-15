# Troubleshooting Guide

This guide helps you resolve common issues with VAR (Volume Adaptive Routing).

## Quick Diagnosis

### Check Your Setup

```bash
# Verify Zig version
zig version  # Should be 0.15.1 or later

# Check AVX2 support
grep avx2 /proc/cpuinfo  # Linux
sysctl -a | grep avx     # macOS

# Test basic functionality
zig build
zig build test
zig build benchmark -Doptimize=ReleaseFast
```

## Common Issues

### 1. Compilation Errors

#### "SIMD vectorization requires AVX2"

**Symptoms**:
```
error: SIMD vectorization requires AVX2
```

**Causes**:
- CPU doesn't support AVX2 (pre-2013 Intel, pre-Ryzen AMD)
- SIMD explicitly disabled but code assumes AVX2

**Solutions**:

1. **Check CPU support**:
   ```bash
   # Linux
   grep avx2 /proc/cpuinfo

   # macOS
   sysctl -a | grep avx

   # Windows (PowerShell)
   Get-WmiObject -Class Win32_Processor | Select-Object -Property Name
   ```

2. **Disable SIMD**:
   ```zig
   const router = var_mod.VAR.init(.{ .simd_enabled = false });
   ```

3. **Use scalar-only build** (if needed):
   ```zig
   // Modify build.zig to force scalar mode
   const config = var_mod.Config{ .simd_enabled = false };
   ```

#### "unable to find 'var' module"

**Symptoms**:
```
error: unable to find 'var' module
```

**Causes**:
- Incorrect module import path
- Missing dependency in build.zig
- Wrong file structure

**Solutions**:

1. **Check build.zig**:
   ```zig
   // Ensure VAR module is properly configured
   const var_mod = b.createModule(.{
       .root_source_file = b.path("src/var.zig"),
       .target = target,
       .optimize = optimize,
   });

   exe.root_module.addImport("var", var_mod);
   ```

2. **Verify import**:
   ```zig
   const var_mod = @import("var");  // Correct
   // NOT: const var_mod = @import("VAR");
   ```

3. **Check file paths**:
   ```bash
   find . -name "var.zig"  # Should be in src/var.zig
   ```

### 2. Performance Issues

#### Lower than expected throughput

**Symptoms**:
- Getting <500M/sec instead of 1.32B/sec
- Inconsistent benchmark results

**Causes**:
- Wrong optimization level
- CPU frequency scaling
- System load interference
- Memory bandwidth limits

**Solutions**:

1. **Use ReleaseFast**:
   ```bash
   zig build benchmark -Doptimize=ReleaseFast  # NOT Debug
   ```

2. **Pin CPU cores**:
   ```bash
   taskset -c 0-7 zig build benchmark -Doptimize=ReleaseFast
   ```

3. **Disable frequency scaling**:
   ```bash
   # Linux
   sudo cpupower frequency-set -g performance

   # Check current governor
   cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
   ```

4. **Run on idle system**:
   ```bash
   uptime  # Check load average
   top -bn1 | head -10  # Check processes
   ```

#### SIMD not working

**Symptoms**:
- Performance same in SIMD and scalar modes
- Debug prints show scalar path taken

**Causes**:
- SIMD disabled in config
- Batch size too small (< 8 elements)
- AVX2 not supported

**Solutions**:

1. **Enable SIMD**:
   ```zig
   const router = var_mod.VAR.init(.{ .simd_enabled = true });
   ```

2. **Check batch size**:
   ```zig
   // SIMD requires len >= 8
   if (queries.len >= 8) {
       try router.routeBatch(&queries, &worlds, &decisions);
   }
   ```

3. **Verify AVX2**:
   ```bash
   lscpu | grep avx2  # Should show 'avx2'
   ```

### 3. Runtime Errors

#### "MismatchedLengths"

**Symptoms**:
```
error.MismatchedLengths
```

**Causes**:
- Input arrays have different lengths
- Output array doesn't match input length

**Solutions**:

```zig
// Ensure all arrays have same length
const len = 1000;
var queries = try allocator.alloc(f32, len);
var worlds = try allocator.alloc(f32, len);
var decisions = try allocator.alloc(Decision, len);

// All must be same length
try router.routeBatch(queries[0..len], worlds[0..len], decisions[0..len]);
```

#### Memory allocation failures

**Symptoms**:
- Out of memory errors
- Stack overflow

**Causes**:
- Large batch sizes
- Memory leaks in user code
- Stack allocation limits

**Solutions**:

1. **Use heap allocation**:
   ```zig
   var queries = try std.ArrayList(f32).initCapacity(allocator, batch_size);
   defer queries.deinit();
   ```

2. **Process in chunks**:
   ```zig
   const chunk_size = 1_000_000;
   var i: usize = 0;
   while (i < total_size) {
       const end = @min(i + chunk_size, total_size);
       try router.routeBatch(
           queries[i..end],
           worlds[i..end],
           decisions[i..end]
       );
       i = end;
   }
   ```

### 4. Testing Issues

#### Tests failing

**Symptoms**:
- `zig build test` fails
- Unexpected routing decisions

**Causes**:
- Logic errors in routing algorithm
- Incorrect test expectations
- Configuration issues

**Solutions**:

1. **Debug routing logic**:
   ```zig
   // Add debug prints
   const selectivity = query_vol / world_vol;
   std.debug.print("q={d}, w={d}, sel={d}, thresh={d}\n",
                  .{query_vol, world_vol, selectivity, config.gpu_threshold});
   ```

2. **Check test data**:
   ```zig
   // Verify test inputs
   try std.testing.expect(query_vol > 0);
   try std.testing.expect(world_vol > 0);
   ```

3. **Run single test**:
   ```bash
   zig build test -Dtest-filter="route with"
   ```

### 5. Integration Issues

#### Package manager problems

**Symptoms**:
- Cannot fetch VAR package
- Dependency resolution fails

**Solutions**:

1. **Check build.zig.zon**:
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

2. **Update hash**:
   ```bash
   # Get actual hash
   zig fetch --save https://github.com/boonzy00/var/archive/v1.0.0.tar.gz
   ```

#### Cross-compilation issues

**Symptoms**:
- Builds fail on different platforms
- SIMD not available on target

**Solutions**:

1. **Check target support**:
   ```bash
   zig targets  # List supported targets
   ```

2. **Conditional SIMD**:
   ```zig
   // Check target CPU features
   const has_avx2 = std.Target.x86.featureSetHas(target.cpu.features, .avx2);
   const config = if (has_avx2) .{} else .{ .simd_enabled = false };
   ```

## Advanced Debugging

### Profiling Performance

```bash
# CPU profiling (Linux)
sudo apt install linux-tools-common
perf record -g zig build benchmark -Doptimize=ReleaseFast
perf report

# Memory profiling
valgrind --tool=cachegrind zig build benchmark -Doptimize=ReleaseFast
```

### Analyzing SIMD Code

```zig
// Add instrumentation
pub fn routeBatch(...) !void {
    const start_time = std.time.nanoTimestamp();

    // Your SIMD code here

    const end_time = std.time.nanoTimestamp();
    const batch_time = end_time - start_time;
    const per_decision = @divTrunc(batch_time, query_vols.len);

    std.debug.print("Batch: {d} decisions, {d} ns total, {d} ns/decision\n",
                   .{query_vols.len, batch_time, per_decision});
}
```

### Memory Analysis

```bash
# Check for memory leaks
valgrind --leak-check=full zig build test

# Memory usage profiling
valgrind --tool=massif zig build benchmark -Doptimize=ReleaseFast
ms_print massif.out.*
```

## Getting Help

### Information to Provide

When reporting issues, include:

1. **System information**:
   ```bash
   zig version
   uname -a
   lscpu | head -20
   ```

2. **Error messages** (complete output)

3. **Code snippet** that reproduces the issue

4. **Expected vs actual behavior**

### Debug Build

For debugging, use Debug optimization:

```bash
zig build -Doptimize=Debug
zig build test -Doptimize=Debug
```

### Minimal Reproduction

Create a minimal example that reproduces the issue:

```zig
// minimal_repro.zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const router = var_mod.VAR.init(null);

    // Minimal code that shows the problem
    const decision = router.route(1.0, 1000.0);
    std.debug.print("Decision: {}\n", .{decision});
}
```

## Prevention

### Best Practices

1. **Test on multiple platforms**
2. **Use CI/CD** for automated testing
3. **Profile performance** regularly
4. **Keep dependencies minimal**
5. **Document platform requirements**

### CI/CD Setup

```yaml
# .github/workflows/ci.yml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: goto-bus-stop/setup-zig@v2
        with:
          version: 0.15.1
      - run: zig build
      - run: zig build test
      - run: zig build benchmark -Doptimize=ReleaseFast
```

This comprehensive troubleshooting guide should help resolve most issues. If you encounter problems not covered here, please [open an issue](https://github.com/boonzy00/var/issues) with detailed information.