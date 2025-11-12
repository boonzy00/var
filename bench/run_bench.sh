#!/bin/bash
cd /home/boonzy/dev/projects/contributing/volume-adaptive-routing

# Build the benchmark binary in ReleaseFast
zig build -Doptimize=ReleaseFast benchmark

# Benchmark the binary directly (no build overhead)
hyperfine --warmup 3 --runs 10 './zig-out/bin/var_benchmark' --export-json bench/bench-results.json --export-markdown bench/bench-results.md