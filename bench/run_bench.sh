#!/bin/bash
echo "VAR v0.1.0 — Volume-Adaptive Routing Benchmark"
echo "------------------------------------------------"
echo "World volume: 1,000,000,000 (1km³)"
echo "Queries: 1,000,000 (50% narrow, 50% broad)"
echo "Machine: $(uname -a)"
echo "CPU: $(lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
echo "Zig version: $(zig version)"
echo

# Build the benchmark
echo "Building benchmark..."
zig build

if [ $? -ne 0 ]; then
    echo "Build failed!"
    exit 1
fi

echo "Build complete. Running hyperfine benchmark..."

# Run the hyperfine benchmark
hyperfine --warmup 5 --runs 10 'zig build run' \
  --export-json bench-results.json \
  --export-markdown bench-results.md

echo "Results saved to bench-results.md"
echo "Raw hyperfine output also saved to bench-results.md"