const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    var m = var_mod.MultiCoreVAR.init(.{
        .gpu_threshold = 0.01,
        .cpu_cores = 8,
        .gpu_available = true,
    });

    const iterations: usize = 100_000_000;
    var queries = try std.heap.page_allocator.alloc(f32, iterations);
    var worlds = try std.heap.page_allocator.alloc(f32, iterations);
    var out = try std.heap.page_allocator.alloc(var_mod.Decision, iterations);

    // Generate pseudo-random test data
    var seed: u64 = 0xabad1dea;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        queries[i] = @as(f32, @floatFromInt(seed % 1000)) + 1.0;
        worlds[i] = 1_000_000.0 + @as(f32, @floatFromInt(seed & 0xFF));
        seed = seed *% 6364136223846793005 +% 1;
    }

    var timer = try std.time.Timer.start();
    // Logical 8 threads
    m.routeBatch(queries[0..], worlds[0..], out[0..], 8);
    const elapsed_ns = timer.read();

    std.mem.doNotOptimizeAway(&out);

    const avg_ns = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, @floatFromInt(iterations));
    const throughput = (@as(f64, @floatFromInt(iterations)) * 1_000_000_000.0 / @as(f64, @floatFromInt(elapsed_ns))) / 1_000_000.0; // M decisions/sec

    std.debug.print("Time: {d:.2} ms for {d} decisions\n" ++
        "Avg per decision: {d:.2} ns\n" ++
        "Throughput: {d:.2} M decisions/sec\n", .{ @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000.0, iterations, avg_ns, throughput });

    std.heap.page_allocator.free(queries);
    std.heap.page_allocator.free(worlds);
    std.heap.page_allocator.free(out);
}
