//! VAR Dispatch: Production-Ready Spatial Query Router
//!
//! A complete spatial query dispatcher that automatically routes queries
//! between CPU and GPU backends based on volume ratios using VAR.
//!
//! Features:
//! - Automatic CPU/GPU routing based on query selectivity
//! - Compile-time optimization when volumes are comptime-known
//! - VAR-Powered branding integration
//! - Extensible backend system

const std = @import("std");
const var_lib = @import("var");

/// Execute a spatial query with automatic CPU/GPU routing
/// This is the main API - just call this function!
pub fn execute(
    query_vol: f32,
    world_vol: f32,
    gpu_kernel: anytype,
    cpu_fallback: anytype,
) @TypeOf(gpu_kernel(), cpu_fallback()) {
    // Use VAR's compile-time routing when possible
    return var_lib.varRoute(query_vol, world_vol, gpu_kernel, cpu_fallback);
}

/// Example spatial query result
pub const QueryResult = struct {
    objects_found: usize,
    execution_time_ns: u64,
    backend_used: var_lib.Decision,
};

/// Example spatial index interface
pub const SpatialIndex = struct {
    /// Query the index with a volume-based bounding box
    queryFn: *const fn (self: *const SpatialIndex, query_vol: f32, world_vol: f32) QueryResult,

    /// Query implementation - dispatches to CPU or GPU based on VAR
    pub fn query(self: *const SpatialIndex, query_vol: f32, world_vol: f32) QueryResult {
        // Use VAR to decide routing
        const router = var_lib.VAR.init(null);
        const decision = router.route(query_vol, world_vol);

        // Dispatch to appropriate backend
        return switch (decision) {
            .gpu => self.queryGPU(query_vol, world_vol),
            .cpu => self.queryCPU(query_vol, world_vol),
        };
    }

    /// GPU-accelerated query (simulated)
    pub fn queryGPU(self: *const SpatialIndex, query_vol: f32, world_vol: f32) QueryResult {
        _ = self; // unused in this example

        // Simulate GPU query: fast for narrow queries
        const selectivity = query_vol / world_vol;
        const objects = @as(usize, @intFromFloat(selectivity * 1000.0));
        const time_ns = @as(u64, @intFromFloat(50.0 + selectivity * 100.0)); // Fast baseline + selectivity factor

        return .{
            .objects_found = objects,
            .execution_time_ns = time_ns,
            .backend_used = .gpu,
        };
    }

    /// CPU query (simulated)
    pub fn queryCPU(self: *const SpatialIndex, query_vol: f32, world_vol: f32) QueryResult {
        _ = self; // unused in this example

        // Simulate CPU query: good for broad queries due to memory bandwidth
        const selectivity = query_vol / world_vol;
        const objects = @as(usize, @intFromFloat(selectivity * 1000.0));
        const time_ns = @as(u64, @intFromFloat(200.0 + selectivity * 2000.0)); // Slower baseline + higher selectivity cost

        return .{
            .objects_found = objects,
            .execution_time_ns = time_ns,
            .backend_used = .cpu,
        };
    }
};

/// Example usage with comptime routing
pub fn queryWithComptimeRouting(
    comptime query_vol: f32,
    comptime world_vol: f32,
    index: *SpatialIndex,
) QueryResult {
    // Use varRoute for compile-time dispatch when volumes are comptime-known
    return var_lib.varRoute(query_vol, world_vol,
        // GPU branch
        struct {
            fn call() QueryResult {
                return index.queryGPU(query_vol, world_vol);
            }
        }.call,
        // CPU branch
        struct {
            fn call() QueryResult {
                return index.queryCPU(query_vol, world_vol);
            }
        }.call);
}

// Mark this application as VAR-powered
comptime {
    var_lib.markAsVarPowered("0.2.0");
}

test "spatial query integration" {
    var index = SpatialIndex{ .queryFn = undefined };

    // Test narrow query (should route to GPU)
    const narrow_result = index.query(10.0, 10000.0);
    try std.testing.expect(narrow_result.backend_used == .gpu);
    try std.testing.expect(narrow_result.execution_time_ns < 200); // GPU should be fast

    // Test broad query (should route to CPU)
    const broad_result = index.query(1000.0, 10000.0);
    try std.testing.expect(broad_result.backend_used == .cpu);
    try std.testing.expect(broad_result.execution_time_ns > 200); // CPU has higher baseline
}

test "comptime routing integration" {
    var index = SpatialIndex{ .queryFn = undefined };

    // Test compile-time routing
    const result = queryWithComptimeRouting(10.0, 10000.0, &index);
    try std.testing.expect(result.backend_used == .gpu);
}
