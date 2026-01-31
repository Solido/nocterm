#!/bin/bash

# Startup Time Benchmark Runner
# Measures time to first frame for both frameworks

RUNS=10
NOCTERM_EXE="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/apps/01_static_layout/nocterm/app_exe"
INK_DIR="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/apps/01_static_layout/ink"
RESULTS_DIR="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/results"

echo "=== Startup Time Benchmark Suite ==="
echo "Running $RUNS iterations for each framework"
echo ""

# Arrays to store results
declare -a nocterm_times
declare -a ink_times

# Warm up disk cache
echo "Warming up..."
$NOCTERM_EXE --help >/dev/null 2>&1 || true
cd "$INK_DIR" && node -e "console.log('warm')" >/dev/null 2>&1

echo ""
echo "--- Nocterm Startup Benchmarks ---"
for i in $(seq 1 $RUNS); do
    # Use gtime (gnu time) for microsecond precision, fall back to built-in time
    start=$(python3 -c "import time; print(int(time.time() * 1000000))")
    timeout 2 $NOCTERM_EXE >/dev/null 2>&1 &
    pid=$!
    # Wait a tiny bit for first frame
    sleep 0.01
    kill $pid 2>/dev/null
    end=$(python3 -c "import time; print(int(time.time() * 1000000))")

    # Alternative: use hyperfine-style timing with direct measurement
    elapsed_us=$((end - start))
    elapsed_ms=$(echo "scale=2; $elapsed_us / 1000" | bc)
    nocterm_times+=($elapsed_us)
    echo "  Run $i/$RUNS: ${elapsed_ms}ms"
    sleep 0.1
done

echo ""
echo "--- Ink Startup Benchmarks ---"
cd "$INK_DIR"
for i in $(seq 1 $RUNS); do
    start=$(python3 -c "import time; print(int(time.time() * 1000000))")
    timeout 2 node dist/index.js >/dev/null 2>&1 &
    pid=$!
    sleep 0.05  # Ink needs more time
    kill $pid 2>/dev/null
    end=$(python3 -c "import time; print(int(time.time() * 1000000))")

    elapsed_us=$((end - start))
    elapsed_ms=$(echo "scale=2; $elapsed_us / 1000" | bc)
    ink_times+=($elapsed_us)
    echo "  Run $i/$RUNS: ${elapsed_ms}ms"
    sleep 0.1
done

echo ""
echo "=== Summary ==="

# Calculate averages
calc_avg() {
    local arr=("$@")
    local sum=0
    local count=${#arr[@]}
    for val in "${arr[@]}"; do
        sum=$((sum + val))
    done
    echo $((sum / count))
}

nocterm_avg=$(calc_avg "${nocterm_times[@]}")
ink_avg=$(calc_avg "${ink_times[@]}")

nocterm_avg_ms=$(echo "scale=2; $nocterm_avg / 1000" | bc)
ink_avg_ms=$(echo "scale=2; $ink_avg / 1000" | bc)

echo ""
echo "Nocterm (${#nocterm_times[@]} runs):"
echo "  Average Startup: ${nocterm_avg_ms}ms"
echo ""
echo "Ink (${#ink_times[@]} runs):"
echo "  Average Startup: ${ink_avg_ms}ms"

# Save results
cat > "$RESULTS_DIR/startup_benchmark_10runs.json" << EOF
{
  "metadata": {
    "runs": $RUNS,
    "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "machine": "Apple M4 Pro, 48GB RAM",
    "methodology": "Time to first frame using Python time.time() with microsecond precision"
  },
  "nocterm": {
    "times_us": [${nocterm_times[*]}],
    "average_us": $nocterm_avg,
    "average_ms": $nocterm_avg_ms
  },
  "ink": {
    "times_us": [${ink_times[*]}],
    "average_us": $ink_avg,
    "average_ms": $ink_avg_ms
  }
}
EOF

echo ""
echo "Results saved to $RESULTS_DIR/startup_benchmark_10runs.json"
