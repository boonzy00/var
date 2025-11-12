const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const VAR = var_mod.VAR;

    var router = VAR.init(.{
        .gpu_threshold = 0.01,
        .cpu_cores = 8,
        .gpu_available = true,
    });

    const query_vol: f32 = 100.0;
    const world_vol: f32 = 1_000_000.0;

    const iterations = 1_000_000;
    var i: usize = 0;
    var decision: var_mod.Decision = undefined;

    var timer = try std.time.Timer.start();
    while (i < iterations) : (i += 1) {
        decision = router.route(query_vol, world_vol);
    }
    const elapsed_ns = timer.read();

    std.mem.doNotOptimizeAway(&decision);

    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const throughput = (@as(f64, @floatFromInt(iterations)) * 1_000_000_000.0 / @as(f64, @floatFromInt(elapsed_ns))) / 1_000_000.0; // M decisions/sec

    std.debug.print("Time: {d:.2} ms for {d} decisions\n" ++
        "Avg per decision: {d:.2} ns\n" ++
        "Throughput: {d:.2} M decisions/sec\n", .{ @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0, iterations, avg_ns, throughput });
}
