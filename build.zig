const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.createModule(.{
        .root_source_file = b.path("src/var.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "var",
        .root_module = mod,
        .linkage = .static,
    });

    b.installArtifact(lib);

    // Add unit tests
    const tests = b.addTest(.{
        .root_module = mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // Add benchmark
    const benchmark_module = b.createModule(.{
        .root_source_file = b.path("benchmarks/var_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_module.addImport("var", mod);

    const benchmark = b.addExecutable(.{
        .name = "var_benchmark",
        .root_module = benchmark_module,
    });

    const run_benchmark = b.addRunArtifact(benchmark);
    const benchmark_step = b.step("benchmark", "Run performance benchmark");
    benchmark_step.dependOn(&run_benchmark.step);
}