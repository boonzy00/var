// src/var.zig
const std = @import("std");

pub const Decision = enum { cpu, gpu };

pub const Config = struct {
    gpu_threshold: f32 = 0.01,
    cpu_cores: u32 = 8,
    gpu_available: bool = true,
    simd_enabled: bool = true,
    thread_pool_size: u32 = 8,
};

pub const VAR = struct {
    config: Config,

    pub fn init(config: ?Config) VAR {
        return .{ .config = config orelse .{} };
    }

    pub fn route(self: VAR, query_vol: f32, world_vol: f32) Decision {
        if (world_vol <= 0.0 or !self.config.gpu_available) return .cpu;
        const selectivity = query_vol / world_vol;
        return if (selectivity < self.config.gpu_threshold) .gpu else .cpu;
    }

    pub fn routeBatch(
        self: *VAR,
        query_vols: []const f32,
        world_vols: []const f32,
        decisions: []Decision,
    ) !void {
        if (query_vols.len != world_vols.len or query_vols.len != decisions.len) {
            return error.MismatchedLengths;
        }
        if (!self.config.simd_enabled or query_vols.len < 8) {
            for (query_vols, world_vols, 0..) |q, w, i| {
                decisions[i] = self.route(q, w);
            }
            return;
        }

        const Vec8f32 = @Vector(8, f32);
        const Vec8u32 = @Vector(8, u32);

        var i: usize = 0;
        const len = query_vols.len;
        while (i + 8 <= len) : (i += 8) {
            const q_vec: Vec8f32 = .{
                query_vols[i],
                query_vols[i + 1],
                query_vols[i + 2],
                query_vols[i + 3],
                query_vols[i + 4],
                query_vols[i + 5],
                query_vols[i + 6],
                query_vols[i + 7],
            };

            const w_vec: Vec8f32 = .{
                world_vols[i],
                world_vols[i + 1],
                world_vols[i + 2],
                world_vols[i + 3],
                world_vols[i + 4],
                world_vols[i + 5],
                world_vols[i + 6],
                world_vols[i + 7],
            };

            const sel_vec = q_vec / w_vec;
            const thresh_vec = @as(Vec8f32, @splat(self.config.gpu_threshold));
            const gpu_mask = sel_vec < thresh_vec;

            // Convert mask to decisions
            const gpu_int: Vec8u32 = @select(u32, gpu_mask, @as(Vec8u32, @splat(1)), @as(Vec8u32, @splat(0)));

            decisions[i] = if (gpu_int[0] == 1) .gpu else .cpu;
            decisions[i + 1] = if (gpu_int[1] == 1) .gpu else .cpu;
            decisions[i + 2] = if (gpu_int[2] == 1) .gpu else .cpu;
            decisions[i + 3] = if (gpu_int[3] == 1) .gpu else .cpu;
            decisions[i + 4] = if (gpu_int[4] == 1) .gpu else .cpu;
            decisions[i + 5] = if (gpu_int[5] == 1) .gpu else .cpu;
            decisions[i + 6] = if (gpu_int[6] == 1) .gpu else .cpu;
            decisions[i + 7] = if (gpu_int[7] == 1) .gpu else .cpu;
        }
        // Tail
        while (i < len) : (i += 1) {
            decisions[i] = self.route(query_vols[i], world_vols[i]);
        }
    }
};

pub fn varRoute(
    comptime query_vol: f32,
    comptime world_vol: f32,
    gpu_fn: anytype,
    cpu_fn: anytype,
) @typeInfo(@TypeOf(gpu_fn)).Fn.return_type.? {
    const decision = VAR.init(null).route(query_vol, world_vol);
    return switch (decision) {
        .gpu => gpu_fn(),
        .cpu => cpu_fn(),
    };
}
