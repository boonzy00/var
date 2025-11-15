// bench/main.zig
const std = @import("std");
const var_lib = @import("var");

pub fn main() !void {
    const router = var_lib.VAR.init(null);
    const world_vol = 1_000_000_000.0; // 1km³

    const start = std.time.nanoTimestamp();

    var gpu_routes: u64 = 0;
    var cpu_routes: u64 = 0;

    var i: u64 = 0;
    while (i < 1_000_000) : (i += 1) {
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
    const ns_per_decision = @as(f64, @floatFromInt(ns)) / 1_000_000.0; // 1M decisions
    const decisions_per_sec = 1_000_000.0 / (@as(f64, @floatFromInt(ns)) / 1_000_000_000.0);

    std.debug.print(" VAR v1.0 Demo — 1M Routing Decisions\n", .{});
    std.debug.print(" ===================================\n", .{});
    std.debug.print(" Time:     {:.2} ms\n", .{ms});
    std.debug.print(" Throughput: {} decisions/sec\n", .{@as(u64, @intFromFloat(@round(decisions_per_sec)))});
    std.debug.print(" Per decision: {:.3} ns\n", .{ns_per_decision});
    std.debug.print(" GPU routes: {} | CPU routes: {}\n", .{ gpu_routes, cpu_routes });
}
