const std = @import("std");
const v = @import("var");

test "VAR routes correctly" {
    const router = v.VAR.init(null);

    // Narrow query
    try std.testing.expect(router.route(1.0, 1000.0) == .gpu);

    // Broad query
    try std.testing.expect(router.route(100.0, 1000.0) == .cpu);

    // No GPU
    const no_gpu = v.VAR.init(.{ .gpu_available = false });
    try std.testing.expect(no_gpu.route(1.0, 1000.0) == .cpu);
}

test "frustumVolume calculation" {
    // Test with known values: near=1, far=2, fov_y=π/2 (90°), aspect=1
    const vol = v.frustumVolume(1.0, 2.0, std.math.pi / 2.0, 1.0);
    // Expected: near area = 4, far area = 16, avg = 10, vol = 10/3 ≈ 3.333
    try std.testing.expectApproxEqAbs(vol, 10.0 / 3.0, 0.001);
}

test "varRoute comptime evaluation" {
    // Test compile-time routing with comptime-known volumes
    const result = v.varRoute(1.0, 1000.0, struct {
        fn gpu() u32 {
            return 42;
        }
    }.gpu, struct {
        fn cpu() u32 {
            return 24;
        }
    }.cpu);
    try std.testing.expect(result == 42); // Should route to GPU

    const result2 = v.varRoute(100.0, 1000.0, struct {
        fn gpu() u32 {
            return 42;
        }
    }.gpu, struct {
        fn cpu() u32 {
            return 24;
        }
    }.cpu);
    try std.testing.expect(result2 == 24); // Should route to CPU
}

test "varRoute runtime evaluation" {
    // Test runtime routing
    const query_vol: f32 = 1.0;
    const world_vol: f32 = 1000.0;

    const result = v.varRoute(query_vol, world_vol, struct {
        fn gpu() u32 {
            return 42;
        }
    }.gpu, struct {
        fn cpu() u32 {
            return 24;
        }
    }.cpu);
    try std.testing.expect(result == 42); // Should route to GPU

    const query_vol2: f32 = 100.0;
    const result2 = v.varRoute(query_vol2, world_vol, struct {
        fn gpu() u32 {
            return 42;
        }
    }.gpu, struct {
        fn cpu() u32 {
            return 24;
        }
    }.cpu);
    try std.testing.expect(result2 == 24); // Should route to CPU
}

test "estimateCost calculation" {
    const config = v.Config{
        .gpu_threshold = 0.01,
        .cpu_cores = 8,
        .gpu_available = true,
    };

    // Low selectivity (narrow query) - GPU should be cheaper
    const narrow_cost = v.estimateCost(0.005, config);
    try std.testing.expect(narrow_cost.gpu < narrow_cost.cpu);

    // High selectivity (broad query) - CPU should be cheaper
    const broad_cost = v.estimateCost(0.1, config);
    try std.testing.expect(broad_cost.cpu < broad_cost.gpu);

    // Test CPU core scaling
    const single_core_config = v.Config{
        .gpu_threshold = 0.01,
        .cpu_cores = 1,
        .gpu_available = true,
    };
    const single_core_cost = v.estimateCost(0.1, single_core_config);
    const multi_core_cost = v.estimateCost(0.1, config);
    try std.testing.expect(single_core_cost.cpu > multi_core_cost.cpu); // More cores = lower CPU cost
}

test "VAR-Powered branding" {
    // Test that the branding function can be called
    v.markAsVarPowered("0.2.0");
    // The symbol should be exported and detectable
    // This is mainly a compile-time test
}
