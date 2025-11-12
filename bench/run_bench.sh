#!/bin/bash
cd /home/boonzy/dev/projects/contributing/volume-adaptive-routing/bench
hyperfine --runs 10 'zig build run' --export-json bench-results.json --export-markdown bench-results.md