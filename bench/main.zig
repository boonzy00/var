// bench/main.zig
const std = @import("std");
const var_lib = @import("var");
const timer = std.time.Timer;

pub fn main() !void {
    const router = var_lib.VAR.init(null);
    const world_vol = 1_000_000_000.0; // 1km³

    var t = try timer.start();

    var i: u64 = 0;
    while (i < 1_000_000) : (i += 1) {
        var query_vol: f32 = undefined;
        if (i % 2 == 0) {
            query_vol = 100.0;
        } else {
            query_vol = 100_000.0;
        }
        _ = router.route(query_vol, world_vol);
    }

    const end_time = t.read();
    const ms = @as(f64, @floatFromInt(end_time)) / 1_000_000.0;
    const ns_per_decision = @as(f64, @floatFromInt(end_time)) / 1_000_000.0; // 1M decisions
    const decisions_per_sec = 1_000_000.0 / (@as(f64, @floatFromInt(end_time)) / 1_000_000_000.0);

    std.debug.print("VAR Benchmark Results:\n", .{});
    std.debug.print("Time: {}ms for 1,000,000 decisions\n", .{ms});
    std.debug.print("Avg time per decision: {}ns\n", .{ns_per_decision});
    std.debug.print("Throughput: {} decisions/sec\n", .{decisions_per_sec});
}
