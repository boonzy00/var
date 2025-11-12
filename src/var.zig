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
};

/// Optional helper: estimate frustum volume (tetrahedral approximation)
pub fn frustumVolume(near: f32, far: f32, fov_y: f32, aspect: f32) f32 {
    const h = 2.0 * near * std.math.tan(fov_y * 0.5);
    const w = h * aspect;
    const avg_area = (w * h + (w * far / near) * (h * far / near)) * 0.5;
    return avg_area * (far - near) / 3.0;
}
