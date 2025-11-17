#!/bin/bash
# run_bench.sh — Scalar vs SIMD VAR Benchmark
set -e

cd ..

FORCE_PATH=""
if [ "$1" = "--force-path=scalar" ]; then
    FORCE_PATH="scalar"
elif [ "$1" = "--force-path=avx2" ]; then
    FORCE_PATH="avx2"
elif [ "$1" = "--force-path=neon" ]; then
    FORCE_PATH="neon"
fi

echo "=== VAR Benchmark: Scalar vs SIMD ==="

if [ -n "$FORCE_PATH" ]; then
    echo "Forcing path: $FORCE_PATH"
    # Modify main.zig to set force_path
    sed -i "s/\.force_path = \..*/\.force_path = .$FORCE_PATH,/" bench/main.zig
else
    echo "Using auto-detection"
    sed -i "s/\.force_path = \..*/\.force_path = null,/" bench/main.zig
fi

# Build
echo "Building..."
zig build -Doptimize=ReleaseFast benchmark

# Bench
echo "Benchmarking..."
hyperfine --warmup 3 --min-runs 10 './zig-out/bin/var_benchmark' \
  --export-json=bench/results.json \
  --export-markdown=bench/results.md \
  --command-name="VAR Benchmark"

echo "Results in bench/results.*"