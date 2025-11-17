// src/var.zig
const std = @import("std");

pub const Decision = enum(u32) { cpu, gpu };

pub const Path = enum { scalar, avx2, neon };

fn detectPath() Path {
    const builtin = @import("builtin");
    if (builtin.cpu.arch == .x86_64) {
        if (hasAvx2()) return .avx2;
    } else if (builtin.cpu.arch == .aarch64) {
        return .neon;
    }
    return .scalar;
}

fn computeAutoTuneThreshold() f32 {
    const cpu_count = std.Thread.getCpuCount() catch 8;
    if (cpu_count > 16) {
        return 0.015; // 1.5% for big servers
    }
    return 0.01; // 1% default
}

fn hasAvx2() bool {
    // Check AVX2 support via CPUID
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    // CPUID with EAX=7, ECX=0 for extended features
    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
        : [input] "{eax}" (7),
          [input2] "{ecx}" (0),
    );

    // AVX2 is bit 5 in EBX
    return (ebx & (1 << 5)) != 0;
}

pub const Config = struct {
    gpu_threshold: f32 = 0.01,
    cpu_cores: u32 = 8,
    gpu_available: bool = true,
    auto_tune: bool = false,
    force_path: ?Path = null,
};

pub const VAR = struct {
    config: Config,
    path: Path,

    pub fn init(config: ?Config) VAR {
        var cfg = config orelse Config{};
        if (cfg.auto_tune) {
            cfg.gpu_threshold = computeAutoTuneThreshold();
        }
        const path = cfg.force_path orelse detectPath();
        return .{ .config = cfg, .path = path };
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

        switch (self.path) {
            .scalar => {
                for (query_vols, world_vols, 0..) |q, w, i| {
                    decisions[i] = self.route(q, w);
                }
            },
            .avx2 => {
                const Vec8f32 = @Vector(8, f32);
                const Vec8Bool = @Vector(8, bool);
                var i: usize = 0;
                const len = query_vols.len;

                while (i + 8 <= len) : (i += 8) {
                    // Load raw
                    const q_raw: Vec8f32 = .{
                        query_vols[i],     query_vols[i + 1], query_vols[i + 2], query_vols[i + 3],
                        query_vols[i + 4], query_vols[i + 5], query_vols[i + 6], query_vols[i + 7],
                    };
                    const w_raw: Vec8f32 = .{
                        world_vols[i],     world_vols[i + 1], world_vols[i + 2], world_vols[i + 3],
                        world_vols[i + 4], world_vols[i + 5], world_vols[i + 6], world_vols[i + 7],
                    };

                    // Clamp negatives → 0
                    const q_clamped = @max(q_raw, @as(Vec8f32, @splat(0.0)));
                    const w_clamped = @max(w_raw, @as(Vec8f32, @splat(0.0)));

                    // Handle div0: force selectivity = 1.0 → CPU
                    const w_zero_mask = w_clamped == @as(Vec8f32, @splat(0.0));
                    const sel_vec = @select(f32, w_zero_mask, @as(Vec8f32, @splat(1.0)), q_clamped / w_clamped);

                    // GPU if: selectivity < threshold AND GPU available
                    const thresh_vec = @as(Vec8f32, @splat(self.config.gpu_threshold));
                    const gpu_selectivity = sel_vec < thresh_vec;
                    const gpu_available = @as(Vec8Bool, @splat(self.config.gpu_available));
                    const temp = gpu_selectivity & gpu_available;
                    const gpu_mask = temp & ~w_zero_mask;

                    // Store decisions
                    inline for (0..8) |j| {
                        decisions[i + j] = if (gpu_mask[j]) .gpu else .cpu;
                    }
                }

                // Scalar tail
                while (i < len) : (i += 1) {
                    decisions[i] = self.route(query_vols[i], world_vols[i]);
                }
            },
            .neon => {
                const Vec4f32 = @Vector(4, f32);
                const Vec4Bool = @Vector(4, bool);
                var i: usize = 0;
                const len = query_vols.len;

                while (i + 4 <= len) : (i += 4) {
                    // Load raw
                    const q_raw: Vec4f32 = .{
                        query_vols[i], query_vols[i + 1], query_vols[i + 2], query_vols[i + 3],
                    };
                    const w_raw: Vec4f32 = .{
                        world_vols[i], world_vols[i + 1], world_vols[i + 2], world_vols[i + 3],
                    };

                    // Clamp negatives → 0
                    const q_clamped = @max(q_raw, @as(Vec4f32, @splat(0.0)));
                    const w_clamped = @max(w_raw, @as(Vec4f32, @splat(0.0)));

                    // Handle div0: force selectivity = 1.0 → CPU
                    const w_zero_mask = w_clamped == @as(Vec4f32, @splat(0.0));
                    const sel_vec = @select(f32, w_zero_mask, @as(Vec4f32, @splat(1.0)), q_clamped / w_clamped);

                    // GPU if: selectivity < threshold AND GPU available
                    const thresh_vec = @as(Vec4f32, @splat(self.config.gpu_threshold));
                    const gpu_selectivity = sel_vec < thresh_vec;
                    const gpu_available = @as(Vec4Bool, @splat(self.config.gpu_available));
                    const temp = gpu_selectivity & gpu_available;
                    const gpu_mask = temp & ~w_zero_mask;

                    // Store decisions
                    inline for (0..4) |j| {
                        decisions[i + j] = if (gpu_mask[j]) .gpu else .cpu;
                    }
                }

                // Scalar tail
                while (i < len) : (i += 1) {
                    decisions[i] = self.route(query_vols[i], world_vols[i]);
                }
            },
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

export fn route(query_size: f32, world_size: f32) callconv(.c) Decision {
    return VAR.init(null).route(query_size, world_size);
}
