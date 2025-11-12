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
