# Ink vs Nocterm Benchmark Suite

A comprehensive benchmark comparison between [Ink](https://github.com/vadimdemedes/ink) (React-based Node.js TUI) and [Nocterm](https://github.com/your-repo/nocterm) (Flutter-inspired Dart TUI).

## Quick Start

```bash
# Install dependencies
cd benchmark/harness/node && npm install
cd ../dart && dart pub get

# Run all benchmarks
./run_benchmarks.sh

# Generate charts
cd charts && npm run generate
```

## Test Applications

| # | Test | Purpose | Key Metrics |
|---|------|---------|-------------|
| 01 | Static Layout | Baseline render performance | First frame, memory baseline |
| 02 | Counter | Minimal state change | Diff efficiency, update latency |
| 03 | Scrolling List | Virtualization & scroll | Frame time under load, memory |
| 04 | Rapid Input | Input-to-render latency | Keystroke latency distribution |
| 05 | Dashboard | Stress test | Sustained performance, jank |

## Methodology

### Measurement Approach

- **Frame Timing**: Internal instrumentation in both frameworks
  - Nocterm: `NoctermTimeline` API
  - Ink: React profiler hooks + custom timing

- **Memory**: Process-level measurement
  - Node.js: `process.memoryUsage()`
  - Dart: `ProcessInfo.currentRss`

- **Binary Size**:
  - Ink: `node_modules` size + bundled output
  - Nocterm: AOT-compiled binary size

### Test Protocol

1. **Warmup**: 100 frames discarded before measurement
2. **Runs**: 10 runs per test for statistical significance
3. **Environment**: Same machine, terminal size (80x24), no background processes
4. **Reporting**: Mean, median, p95, p99, stddev

## Folder Structure

```
benchmark/
├── harness/
│   ├── metrics_schema.json    # Shared result schema
│   ├── node/                  # Node.js measurement utilities
│   └── dart/                  # Dart measurement utilities
├── apps/
│   ├── 01_static_layout/
│   │   ├── SPEC.md           # Test specification
│   │   ├── ink/              # Ink implementation
│   │   └── nocterm/          # Nocterm implementation
│   └── ...
├── results/                   # Benchmark output (JSON)
├── charts/                    # Generated visualizations
└── blog/                      # Blog post draft
```

## Results

Results are output to `results/` in JSON format matching `harness/metrics_schema.json`.

Charts are generated in `charts/output/`.
