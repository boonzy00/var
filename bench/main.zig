// bench/main.zig
const std = @import("std");
const var_lib = @import("var");
const timer = std.time.Timer;

const SIMD_ENABLED = true; // Set to false for scalar bench

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const num_decisions = 1_000_000;
    const world_vol = 1_000_000_000.0; // 1km³

    // Prepare data
    const query_vols = try allocator.alloc(f32, num_decisions);
    defer allocator.free(query_vols);
    const decisions = try allocator.alloc(var_lib.Decision, num_decisions);
    defer allocator.free(decisions);

    for (0..num_decisions) |i| {
        if (i % 5 == 0) {
            query_vols[i] = 100.0; // 20% narrow
        } else {
            query_vols[i] = 100_000.0; // 80% broad
        }
    }

    const world_vols = try allocator.alloc(f32, num_decisions);
    defer allocator.free(world_vols);
    @memset(world_vols, world_vol);

    const config = var_lib.Config{
        .simd_enabled = SIMD_ENABLED,
        .gpu_available = true,
        .gpu_threshold = 0.01,
    };
    var router = var_lib.VAR.init(config);

    var t = try timer.start();

    try router.routeBatch(query_vols, world_vols, decisions);

    const end_time = t.read();
    const ms = @as(f64, @floatFromInt(end_time)) / 1_000_000.0;
    const ns_per_decision = @as(f64, @floatFromInt(end_time)) / @as(f64, @floatFromInt(num_decisions));
    const decisions_per_sec = @as(f64, @floatFromInt(num_decisions)) / (@as(f64, @floatFromInt(end_time)) / 1_000_000_000.0);

    std.debug.print("VAR Benchmark Results:\n", .{});
    std.debug.print("Time: {}ms for {} decisions\n", .{ ms, num_decisions });
    std.debug.print("Avg time per decision: {}ns\n", .{ns_per_decision});
    std.debug.print("Throughput: {} decisions/sec\n", .{decisions_per_sec});
}
