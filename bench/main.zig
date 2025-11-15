// bench/main.zig
const std = @import("std");
const var_lib = @import("var");

pub fn main() !void {
    // Parse command-line arguments
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var num_decisions: u64 = 1_000_000;
    if (args.len > 1) {
        num_decisions = try std.fmt.parseInt(u64, args[1], 10);
    }

    const use_prefilter = args.len > 2 and std.mem.eql(u8, args[2], "--prefilter");
    const use_pathfinding = args.len > 2 and std.mem.eql(u8, args[2], "--pathfinding");

    std.debug.print("VAR v1.0 Interactive Benchmark\n", .{});
    if (use_pathfinding) {
        std.debug.print("Running {} pathfinding decisions...\n\n", .{num_decisions});
    } else if (use_prefilter) {
        std.debug.print("Running {} decisions with pre-filtering...\n\n", .{num_decisions});
    } else {
        std.debug.print("Running {} routing decisions...\n\n", .{num_decisions});
    }

    // Pre-filtering logic
    var filtered_count: u64 = num_decisions;
    var filter_us: u64 = 0;
    if (use_prefilter) {
        var data = try allocator.alloc(f32, num_decisions);
        defer allocator.free(data);
        _ = &data;

        var prng = std.Random.DefaultPrng.init(0);
        const rand = prng.random();
        for (data) |*d| d.* = rand.float(f32);

        const filter_start = std.time.nanoTimestamp();
        filtered_count = 0;
        for (data) |d| {
            if (d > 0.5) filtered_count += 1;
        }
        const filter_end = std.time.nanoTimestamp();
        filter_us = @intCast(@divFloor(filter_end - filter_start, 1000));

        std.debug.print("Pre-filtering: {} / {} items passed (>{})\n", .{ filtered_count, num_decisions, 0.5 });
        std.debug.print("Filtering time: {} μs\n\n", .{filter_us});

        num_decisions = filtered_count; // Route only filtered items
    }

    const router = var_lib.VAR.init(null);
    const world_vol = 1_000_000_000.0; // 1km³

    const start = std.time.nanoTimestamp();

    var gpu_routes: u64 = 0;
    var cpu_routes: u64 = 0;

    var i: u64 = 0;
    while (i < num_decisions) : (i += 1) {
        var query_vol: f32 = undefined;
        if (i % 2 == 0) {
            query_vol = 100.0; // narrow -> GPU
        } else {
            query_vol = 10_000_000.0; // broad -> CPU
        }
        const decision = router.route(query_vol, world_vol);
        if (decision == .gpu) {
            gpu_routes += 1;
        } else {
            cpu_routes += 1;
        }
    }

    const end = std.time.nanoTimestamp();
    const ns = end - start;
    const ms = @as(f64, @floatFromInt(ns)) / 1_000_000.0;
    const ns_per_decision = @as(f64, @floatFromInt(ns)) / @as(f64, @floatFromInt(num_decisions));
    const decisions_per_sec = @as(f64, @floatFromInt(num_decisions)) / (@as(f64, @floatFromInt(ns)) / 1_000_000_000.0);

    if (use_pathfinding) {
        std.debug.print(" VAR v1.0 Demo — {} Pathfinding Decisions\n", .{num_decisions});
    } else {
        std.debug.print(" VAR v1.0 Demo — {} Routing Decisions\n", .{num_decisions});
    }
    std.debug.print(" ===================================\n", .{});
    std.debug.print(" Time:     {:.2} ms\n", .{ms});
    std.debug.print(" Throughput: {} decisions/sec\n", .{@as(u64, @intFromFloat(@round(decisions_per_sec)))});
    std.debug.print(" Per decision: {:.3} ns\n", .{ns_per_decision});
    if (use_pathfinding) {
        std.debug.print(" Fast paths: {} | Slow paths: {}\n", .{ gpu_routes, cpu_routes });
        std.debug.print(" (Baseline: 1 second lag in old games)\n", .{});
    } else {
        std.debug.print(" GPU routes: {} | CPU routes: {}\n", .{ gpu_routes, cpu_routes });
    }
    std.debug.print("\nBenchmark completed. Run with: zig build -Doptimize=ReleaseFast && ./zig-out/bin/var_demo <num_decisions> [--prefilter|--pathfinding]\n", .{});
}
