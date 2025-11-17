#!/bin/bash
# run_bench.sh — Scalar vs SIMD VAR Benchmark
set -e

cd ..

echo "=== VAR Benchmark: Scalar vs SIMD ==="

# Build scalar
echo "Building scalar variant..."
sed -i 's/const SIMD_ENABLED = true;/const SIMD_ENABLED = false;/' bench/main.zig
zig build -Doptimize=ReleaseFast benchmark

# Bench scalar
echo "Benchmarking scalar..."
hyperfine --warmup 3 --min-runs 10 './zig-out/bin/var_benchmark' \
  --export-json=bench/scalar-results.json \
  --export-markdown=bench/scalar-results.md \
  --command-name="Scalar VAR (1M decisions)"

# Build SIMD
echo "Building SIMD variant..."
sed -i 's/const SIMD_ENABLED = false;/const SIMD_ENABLED = true;/' bench/main.zig
zig build -Doptimize=ReleaseFast benchmark

# Bench SIMD
echo "Benchmarking SIMD..."
hyperfine --warmup 3 --min-runs 10 './zig-out/bin/var_benchmark' \
  --export-json=bench/simd-results.json \
  --export-markdown=bench/simd-results.md \
  --command-name="SIMD VAR (1M decisions)"

# Calculate speedup
SCALAR_MEAN=$(jq -r '.results[0].mean' bench/scalar-results.json)
SIMD_MEAN=$(jq -r '.results[0].mean' bench/simd-results.json)
SPEEDUP=$(echo "scale=2; $SCALAR_MEAN / $SIMD_MEAN" | bc -l)

echo ""
echo "=== RESULTS ==="
echo "Scalar: ${SCALAR_MEAN}s"
echo "SIMD:   ${SIMD_MEAN}s"
echo "Speedup: ${SPEEDUP}x"
echo ""
echo "Files: bench/scalar-results.* | bench/simd-results.*"