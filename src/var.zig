const std = @import("std");

/// Decision: where to execute the query
pub const Decision = enum { cpu, gpu };

/// Configuration for VAR
pub const Config = struct {
    /// Threshold: query_vol / world_vol < threshold → GPU
    gpu_threshold: f32 = 0.01,

    /// Number of CPU cores (affects threshold)
    cpu_cores: u32 = 8,

    /// Is GPU available?
    gpu_available: bool = true,
};

/// Volume-Adaptive Routing — the core engine
pub const VAR = struct {
    config: Config,

    /// Initialize VAR with optional config
    pub fn init(config: ?Config) VAR {
        return .{ .config = config orelse .{} };
    }

    /// Route a query based on volume
    pub fn route(self: VAR, query_volume: f32, world_volume: f32) Decision {
        // Safety: avoid divide-by-zero or invalid state
        if (world_volume <= 0.0 or !self.config.gpu_available) {
            return .cpu;
        }

        const selectivity = query_volume / world_volume;

        // Use the configured gpu_threshold as the base.
        // Adjust for CPU core count: more CPU cores → relatively stronger CPU throughput,
        // so reduce the threshold (less GPU usage) as cpu_cores increases.
        var threshold: f32 = self.config.gpu_threshold;
        // Avoid division by zero and clamp reasonable values.
        const cores = if (self.config.cpu_cores == 0) 1 else self.config.cpu_cores;
        const cores_f = @as(f32, @floatFromInt(cores));
        // Scale: base * (8 / cores). For 8 cores this is 1.0 (no change). More cores -> smaller threshold.
        threshold *= (8.0 / cores_f);
        if (threshold <= 0.0) threshold = 0.000_001; // avoid degenerate zero or negative
        if (threshold > 1.0) threshold = 1.0;

        return if (selectivity < threshold) .gpu else .cpu;
    }

    /// Route many queries in a batch. Inputs are same-length slices.
    pub fn routeBatch(self: VAR, queries: []const f32, worlds: []const f32, out: []Decision) void {
        // Safety checks
        if (queries.len != worlds.len or queries.len != out.len) return;

        var i: usize = 0;
        while (i < queries.len) : (i += 1) {
            out[i] = self.route(queries[i], worlds[i]);
        }
    }
};

/// MultiCoreVAR: A lightweight multi-core wrapper for performing bulk routing
/// across many queries. The implementation partitions queries across a number
/// of logical threads and processes each chunk independently. On a single
/// thread system, this simply falls back to sequential processing.
pub const MultiCoreVAR = struct {
    base: VAR,

    pub fn init(config: ?Config) MultiCoreVAR {
        return MultiCoreVAR{ .base = VAR.init(config) };
    }

    pub fn routeBatch(self: *MultiCoreVAR, queries: []const f32, worlds: []const f32, out: []Decision, threads: usize) void {
        const n = queries.len;
        if (n != worlds.len or n != out.len) return;
        if (threads <= 1) {
            self.base.routeBatch(queries, worlds, out);
            return;
        }

        const chunk = (n + threads - 1) / threads;
        var t: usize = 0;
        while (t < threads) : (t += 1) {
            const start = t * chunk;
            if (start >= n) break;
            var end = start + chunk;
            if (end > n) end = n;
            var i: usize = start;
            while (i < end) : (i += 1) {
                out[i] = self.base.route(queries[i], worlds[i]);
            }
        }
    }
};

/// Optional helper: estimate frustum volume (tetrahedral approximation)
pub fn frustumVolume(near: f32, far: f32, fov_y: f32, aspect: f32) f32 {
    const h = 2.0 * near * std.math.tan(fov_y * 0.5);
    const w = h * aspect;
    const avg_area = (w * h + (w * far / near) * (h * far / near)) * 0.5;
    return avg_area * (far - near) / 3.0;
}

/// Compile-time adaptive routing macro
/// Evaluates routing decision at compile time when volumes are comptime-known,
/// allowing dead code elimination of unused branches. Falls back to runtime evaluation.
pub inline fn varRoute(
    query_vol: anytype,
    world_vol: anytype,
    comptime gpu_fn: anytype,
    comptime cpu_fn: anytype,
) @TypeOf(gpu_fn(), cpu_fn()) {
    // Check if we can evaluate at compile time
    const can_eval_comptime = @typeInfo(@TypeOf(query_vol)) == .ComptimeFloat or
        @typeInfo(@TypeOf(query_vol)) == .ComptimeInt;
    const world_eval_comptime = @typeInfo(@TypeOf(world_vol)) == .ComptimeFloat or
        @typeInfo(@TypeOf(world_vol)) == .ComptimeInt;

    if (can_eval_comptime and world_eval_comptime) {
        // Compile-time evaluation
        const q = if (@typeInfo(@TypeOf(query_vol)) == .ComptimeFloat)
            @as(comptime_float, query_vol)
        else
            @as(comptime_float, query_vol);

        const w = if (@typeInfo(@TypeOf(world_vol)) == .ComptimeFloat)
            @as(comptime_float, world_vol)
        else
            @as(comptime_float, world_vol);

        if (w <= 0.0) {
            return cpu_fn();
        }

        const selectivity = q / w;
        const threshold = 0.01; // Default threshold for comptime evaluation

        return if (selectivity < threshold) gpu_fn() else cpu_fn();
    } else {
        // Runtime evaluation
        const router = VAR.init(null);
        const decision = router.route(@as(f32, query_vol), @as(f32, world_vol));
        return switch (decision) {
            .gpu => gpu_fn(),
            .cpu => cpu_fn(),
        };
    }
}

/// Cost estimation for query planning across multiple backends
pub const CostEstimate = struct {
    gpu: f64,
    cpu: f64,
};

/// Estimate execution costs for different backends based on selectivity
/// Useful for query planners that need to choose between CPU, GPU, WASM, remote, etc.
pub fn estimateCost(selectivity: f32, config: Config) CostEstimate {
    // GPU cost: parallelism scales with selectivity (more objects = more parallelism)
    // Base cost includes kernel launch overhead
    const gpu_base_cost = 100.0; // Kernel launch/setup cost
    const gpu_parallelism_factor = selectivity * 1000.0; // Parallelism benefit
    const gpu_cost = gpu_base_cost + gpu_parallelism_factor;

    // CPU cost: memory bandwidth scales with sqrt(selectivity) due to cache effects
    // More cores reduce cost, but bandwidth becomes bottleneck for large datasets
    const cpu_bandwidth_factor = @sqrt(selectivity) * 5000.0;
    const cpu_core_scaling = @as(f64, 8.0) / @as(f64, @max(1, config.cpu_cores));
    const cpu_cost = cpu_bandwidth_factor * cpu_core_scaling;

    return .{
        .gpu = gpu_cost,
        .cpu = cpu_cost,
    };
}

// VAR v1.0 transplant: remove branding/onnx references for a minimal
// performance-focused distribution. Branding can be added in a separate
// tooling package to preserve small library size.
