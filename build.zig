const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared module for library and tests
    const var_mod = b.createModule(.{
        .root_source_file = b.path("src/var.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Library
    const lib = b.addLibrary(.{
        .name = "var",
        .root_module = var_mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Unit tests
    const tests = b.addTest(.{
        .root_module = var_mod,
    });
    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    // === BENCHMARK ===
    const benchmark_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/var_benchmark.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_mod.addImport("var", var_mod);

    const benchmark = b.addExecutable(.{
        .name = "var_benchmark",
        .root_module = benchmark_mod,
    });
    b.installArtifact(benchmark);

    const run_benchmark = b.addRunArtifact(benchmark);
    const benchmark_step = b.step("benchmark", "Run VAR performance benchmark");
    benchmark_step.dependOn(&run_benchmark.step);
}
