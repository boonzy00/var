#!/bin/bash
hyperfine --warmup 3 --runs 10 \
  'zig build benchmark -Doptimize=ReleaseFast && taskset -c 0-7 ./zig-out/bin/var_benchmark' \
  --export-json=benchmarks/results/simd-report.json \
  --export-markdown=benchmarks/results/bench-results.md
