// benchmarks/var_benchmark.zig
const std = @import("std");
const var_mod = @import("var");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const batch_size = 100_000_000;
    const queries = try allocator.alloc(f32, batch_size);
    const worlds = try allocator.alloc(f32, batch_size);
    const decisions = try allocator.alloc(var_mod.Decision, batch_size);
    defer {
        allocator.free(queries);
        allocator.free(worlds);
        allocator.free(decisions);
    }

    var prng = std.Random.DefaultPrng.init(0);
    const rand = prng.random();
    for (queries, worlds) |*q, *w| {
        q.* = rand.float(f32) * 1000.0 + 1.0;
        w.* = 100_000.0 + rand.float(f32) * 900_000.0;
    }

    var router = var_mod.VAR.init(.{ .simd_enabled = true });
    const start = std.time.nanoTimestamp();
    try router.routeBatch(queries, worlds, decisions);
    const end = std.time.nanoTimestamp();
    const ns = end - start;
    const per_sec = (@as(f64, @floatFromInt(batch_size)) * 1_000_000_000.0) / @as(f64, @floatFromInt(ns));
    std.debug.print("1.19B/sec test: {d:.2} decisions/sec ({d} ns total)\n", .{ per_sec, ns });
}
