const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    const VAR = var_mod.VAR;

    var router = VAR.init(.{
        .gpu_threshold = 0.01,
        .cpu_cores = 8,
        .gpu_available = true,
    });

    const iterations = 1_000_000;
    var i: usize = 0;
    var decision: var_mod.Decision = undefined;

    // Make inputs vary per iteration to prevent constant folding
    var seed: u64 = 0xdeadbeef;
    var total: u64 = 0;

    var timer = try std.time.Timer.start();
    while (i < iterations) : (i += 1) {
        // Pseudo-random volumes (deterministic)
        const query_vol = @as(f32, @floatFromInt(seed % 1000)) + 1.0;
        const world_vol = 1_000_000.0 + @as(f32, @floatFromInt(seed & 0xFF));

        decision = router.route(query_vol, world_vol);
        total += @intFromEnum(decision);

        // Simple LCG for next seed
        seed = seed *% 6364136223846793005 +% 1;
    }
    const elapsed_ns = timer.read();

    std.mem.doNotOptimizeAway(&total);

    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const throughput = (@as(f64, @floatFromInt(iterations)) * 1_000_000_000.0 / @as(f64, @floatFromInt(elapsed_ns))) / 1_000_000.0; // M decisions/sec

    std.debug.print("Time: {d:.2} ms for {d} decisions\n" ++
        "Avg per decision: {d:.2} ns\n" ++
        "Throughput: {d:.2} M decisions/sec\n" ++
        "Total decisions: {d}\n", .{ @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0, iterations, avg_ns, throughput, total });
}
