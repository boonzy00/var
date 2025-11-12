const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Reference the main var module from the parent project
    const var_module = b.createModule(.{
        .root_source_file = b.path("../src/var.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bench_module = b.createModule(.{
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });
    bench_module.addImport("var", var_module);

    const exe = b.addExecutable(.{
        .name = "var-bench",
        .root_module = bench_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    b.step("run", "Run benchmark").dependOn(&run_cmd.step);
}
