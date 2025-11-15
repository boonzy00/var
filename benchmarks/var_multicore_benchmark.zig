const std = @import("std");
const var_mod = @import("var");

// Force link routeBatch to prevent dead code elimination
comptime {
    _ = var_mod.MultiCoreVAR.routeBatch;
}

pub fn main() !void {
    std.debug.print("🚀 BENCHMARK STARTED\n", .{});

    std.debug.print("VAR Multi-Core Routing Performance Benchmark\n", .{});
    std.debug.print("Hardware: Ryzen 7 5700 (8 cores/16 threads)\n", .{});
    std.debug.print("Date: 2025-11-14\n\n", .{});

    // Now do the full benchmark with fresh allocator
    var gpa2 = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa2.deinit();
    const allocator_main = gpa2.allocator();

    // Test configurations
    const configs = [_]var_mod.Config{
        .{ .multi_core = false, .cpu_cores = 8 }, // Single-threaded baseline
        .{ .multi_core = true, .cpu_cores = 8, .thread_pool_size = 8 }, // Multi-core 8 threads
        .{ .multi_core = true, .cpu_cores = 16, .thread_pool_size = 16 }, // Multi-core 16 threads
    };

    const batch_sizes = [_]usize{ 1000, 10000, 100000, 1000000 };

    for (configs) |config| {
        std.debug.print("Configuration: multi_core={}, cpu_cores={}, thread_pool_size={}\n", .{ config.multi_core, config.cpu_cores, config.thread_pool_size });

        for (batch_sizes) |batch_size| {
            try benchmarkBatchRouting(allocator_main, config, batch_size);
        }
        std.debug.print("\n", .{});
    }

    // TEST: Exit here
    // @panic("TEST: Reached end of configs loop");
    // return;

    std.debug.print("🔥 ENTERING SIMD BENCHMARK SECTION\n", .{});
    // SIMD benchmark
    std.debug.print("\nConfiguration: SIMD-accelerated, cpu_cores=8\n", .{});
    for (batch_sizes) |batch_size| {
        std.debug.print("⚡ RUNNING SIMD BATCH: {d}\n", .{batch_size});
        try benchmarkSIMDRouting(allocator_main, batch_size);
    }

    // 🔥 FINAL TEST: Run SIMD test at the very end
    std.debug.print("\n🧪 FINAL SIMD TEST AT END OF MAIN\n", .{});
    testSIMDFunctionality(allocator_main);
    std.debug.print("✅ FINAL SIMD test completed!\n", .{});
}

fn testSIMDFunctionality(allocator: std.mem.Allocator) void {
    std.debug.print("   ENTERING testSIMDFunctionality\n", .{});
    // Create a small test batch
    const test_size = 16; // Multiple of 8 for SIMD
    var query_volumes = allocator.alloc(f32, test_size) catch return;
    defer allocator.free(query_volumes);
    var world_volumes = allocator.alloc(f32, test_size) catch return;
    defer allocator.free(world_volumes);
    var decisions = allocator.alloc(var_mod.Decision, test_size) catch return;
    defer allocator.free(decisions);
    // These arrays are modified through pointers, linter doesn't detect this
    _ = &query_volumes;
    _ = &world_volumes;
    _ = &decisions;

    // Initialize test data
    for (query_volumes, world_volumes, 0..) |*q, *w, i| {
        q.* = @as(f32, @floatFromInt(i)) + 1.0;
        w.* = 100.0; // Fixed world volume
    }

    std.debug.print("   INITIALIZED test data\n", .{});

    // Test SIMD routing
    const config = var_mod.Config{
        .multi_core = true,
        .cpu_cores = 8,
        .thread_pool_size = 8,
        .gpu_available = false, // CPU-only for test
    };

    var router = var_mod.MultiCoreVAR.init(allocator, config) catch return;
    defer router.deinit();

    std.debug.print("   CREATED MultiCoreVAR router\n", .{});

    router.routeBatch(query_volumes, world_volumes, decisions) catch return;

    std.debug.print("   SUCCESS: routeBatch completed\n", .{});

    // Verify results (first 8 should be GPU due to low selectivity, rest CPU)
    var gpu_count: usize = 0;
    var cpu_count: usize = 0;
    for (decisions) |decision| {
        switch (decision) {
            .gpu => gpu_count += 1,
            .cpu => cpu_count += 1,
        }
    }

    std.debug.print("   SIMD Test Results: GPU={}, CPU={} (expected: GPU=8, CPU=8)\n", .{ gpu_count, cpu_count });
}

fn benchmarkBatchRouting(allocator: std.mem.Allocator, config: var_mod.Config, batch_size: usize) !void {
    // Generate test data
    var query_volumes = try allocator.alloc(f32, batch_size);
    defer allocator.free(query_volumes);
    var world_volumes = try allocator.alloc(f32, batch_size);
    defer allocator.free(world_volumes);
    // These arrays are modified through pointers, linter doesn't detect this
    _ = &query_volumes;
    _ = &world_volumes;

    // Initialize with varied data to prevent optimization
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const rand = prng.random();

    for (query_volumes, world_volumes) |*q, *w| {
        q.* = rand.float(f32) * 1000.0 + 1.0;
        w.* = 10000.0 + rand.float(f32) * 90000.0; // 10k to 100k range
    }

    // Benchmark multi-core routing
    const start_time = std.time.nanoTimestamp();

    if (config.multi_core) {
        var multi_var = try var_mod.MultiCoreVAR.init(allocator, config);
        defer multi_var.deinit();

        var decisions = try allocator.alloc(var_mod.Decision, batch_size);
        defer allocator.free(decisions);
        // decisions is modified by routeBatch, linter doesn't detect this
        _ = &decisions;

        const results = try var_mod.varRouteMultiCore(allocator, config, query_volumes, world_volumes, struct {
            fn gpu() u32 {
                return 42;
            }
        }.gpu, struct {
            fn cpu() u32 {
                return 24;
            }
        }.cpu);
        defer allocator.free(results);
    } else {
        // Single-threaded routing
        const router = var_mod.VAR.init(config);
        for (query_volumes, world_volumes) |q, w| {
            _ = router.route(q, w);
        }
    }

    const end_time = std.time.nanoTimestamp();
    const total_ns = end_time - start_time;
    const avg_ns_per_decision = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(batch_size));
    const decisions_per_sec = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(total_ns));

    std.debug.print("  Batch Size: {d:>8} | Time: {d:>8.2}ms | Avg: {d:>6.2}ns/decision | Throughput: {d:>10.0} decisions/sec\n", .{
        batch_size,
        @as(f64, @floatFromInt(total_ns)) / 1_000_000.0,
        avg_ns_per_decision,
        decisions_per_sec,
    });
    std.debug.print("✅ benchmarkBatchRouting completed for batch_size={}\n", .{batch_size});
}

fn benchmarkVarRouteMultiCore(allocator: std.mem.Allocator, config: var_mod.Config, batch_size: usize) !void {
    // Generate test data
    var query_volumes = try allocator.alloc(f32, batch_size);
    defer allocator.free(query_volumes);
    var world_volumes = try allocator.alloc(f32, batch_size);
    defer allocator.free(world_volumes);
    // These arrays are modified through pointers, linter doesn't detect this
    _ = &query_volumes;
    _ = &world_volumes;

    // Initialize with varied data
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const rand = prng.random();

    for (query_volumes, world_volumes) |*q, *w| {
        q.* = rand.float(f32) * 1000.0 + 1.0;
        w.* = 10000.0 + rand.float(f32) * 90000.0;
    }

    // Benchmark varRouteMultiCore
    const start_time = std.time.nanoTimestamp();

    const results = try var_mod.varRouteMultiCore(allocator, config, query_volumes, world_volumes, struct {
        fn gpu() u32 {
            return 42;
        }
    }.gpu, struct {
        fn cpu() u32 {
            return 24;
        }
    }.cpu);
    defer allocator.free(results);

    const end_time = std.time.nanoTimestamp();
    const total_ns = end_time - start_time;
    const avg_ns_per_decision = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(batch_size));
    const decisions_per_sec = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(total_ns));

    std.debug.print("  varRouteMultiCore Batch Size: {d:>8} | Time: {d:>8.2}ms | Avg: {d:>6.2}ns/decision | Throughput: {d:>10.0} decisions/sec\n", .{
        batch_size,
        @as(f64, @floatFromInt(total_ns)) / 1_000_000.0,
        avg_ns_per_decision,
        decisions_per_sec,
    });
}

fn benchmarkSIMDRouting(allocator: std.mem.Allocator, batch_size: usize) !void {
    std.debug.print("DEBUG: benchmarkSIMDRouting called with batch_size={}\n", .{batch_size});
    // Generate test data - must be multiple of 8 for SIMD
    const padded_size = (batch_size + 7) & ~@as(usize, 7); // Round up to multiple of 8
    var query_volumes = try allocator.alloc(f32, padded_size);
    defer allocator.free(query_volumes);
    var world_volumes = try allocator.alloc(f32, padded_size);
    defer allocator.free(world_volumes);
    var decisions = try allocator.alloc(var_mod.Decision, padded_size);
    defer allocator.free(decisions);
    // These arrays are modified through pointers, linter doesn't detect this
    _ = &query_volumes;
    _ = &world_volumes;
    _ = &decisions;

    // Initialize with varied data
    var prng = std.Random.DefaultPrng.init(0xdeadbeef);
    const rand = prng.random();

    for (query_volumes, world_volumes) |*q, *w| {
        q.* = rand.float(f32) * 1000.0 + 1.0;
        w.* = 10000.0 + rand.float(f32) * 90000.0;
    }

    // Benchmark SIMD routing
    const start_time = std.time.nanoTimestamp();

    // Create SIMD-enabled MultiCoreVAR instance
    const config = var_mod.Config{
        .multi_core = true,
        .cpu_cores = 8,
        .thread_pool_size = 8,
        .gpu_threshold = 0.01,
        .gpu_available = false, // CPU-only for SIMD testing
    };
    var router = try var_mod.MultiCoreVAR.init(allocator, config);
    defer router.deinit();

    try router.routeBatch(query_volumes, world_volumes, decisions);

    const end_time = std.time.nanoTimestamp();
    const total_ns = end_time - start_time;
    const avg_ns_per_decision = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(batch_size));
    const decisions_per_sec = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(total_ns));

    std.debug.print("  SIMD Batch Size: {d:>8} | Time: {d:>8.2}ms | Avg: {d:>6.2}ns/decision | Throughput: {d:>10.0} decisions/sec\n", .{
        batch_size,
        @as(f64, @floatFromInt(total_ns)) / 1_000_000.0,
        avg_ns_per_decision,
        decisions_per_sec,
    });
}
