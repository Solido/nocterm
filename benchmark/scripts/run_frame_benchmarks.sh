#!/bin/bash

# Frame Time Benchmark Runner
# Runs both Nocterm and Ink frame time benchmarks multiple times

RUNS=10
NOCTERM_DIR="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/apps/06_max_fps/nocterm"
INK_DIR="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/apps/06_max_fps/ink"
RESULTS_DIR="/Users/norbertkozsir/IdeaProjects/nocterm/benchmark/results"

echo "=== Frame Time Benchmark Suite ==="
echo "Running $RUNS iterations for each framework"
echo ""

# Arrays to store results
declare -a nocterm_fps nocterm_mean nocterm_median
declare -a ink_fps ink_mean ink_median

# Run Nocterm benchmarks
echo "--- Nocterm Benchmarks ---"
for i in $(seq 1 $RUNS); do
    echo -n "  Run $i/$RUNS: "
    cd "$NOCTERM_DIR"
    timeout 5 dart run bin/app.dart >/dev/null 2>&1
    if [ -f /tmp/nocterm_frame_time_results.json ]; then
        fps=$(cat /tmp/nocterm_frame_time_results.json | jq '.fps')
        mean=$(cat /tmp/nocterm_frame_time_results.json | jq '.totalFrameTime.mean')
        median=$(cat /tmp/nocterm_frame_time_results.json | jq '.totalFrameTime.median')
        nocterm_fps+=($fps)
        nocterm_mean+=($mean)
        nocterm_median+=($median)
        echo "FPS: $fps, Mean: ${mean}µs, Median: ${median}µs"
    else
        echo "FAILED"
    fi
    sleep 0.5
done

echo ""

# Run Ink benchmarks
echo "--- Ink Benchmarks ---"
cd "$INK_DIR"
for i in $(seq 1 $RUNS); do
    echo -n "  Run $i/$RUNS: "
    timeout 5 node dist/index.js >/dev/null 2>&1
    if [ -f /tmp/ink_frame_time_results.json ]; then
        fps=$(cat /tmp/ink_frame_time_results.json | jq '.fps')
        mean=$(cat /tmp/ink_frame_time_results.json | jq '.totalFrameTime.mean')
        median=$(cat /tmp/ink_frame_time_results.json | jq '.totalFrameTime.median')
        ink_fps+=($fps)
        ink_mean+=($mean)
        ink_median+=($median)
        echo "FPS: $fps, Mean: ${mean}µs, Median: ${median}µs"
    else
        echo "FAILED"
    fi
    sleep 0.5
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

nocterm_fps_avg=$(calc_avg "${nocterm_fps[@]}")
nocterm_mean_avg=$(calc_avg "${nocterm_mean[@]}")
ink_fps_avg=$(calc_avg "${ink_fps[@]}")
ink_mean_avg=$(calc_avg "${ink_mean[@]}")

echo ""
echo "Nocterm (${#nocterm_fps[@]} runs):"
echo "  Average FPS: $nocterm_fps_avg"
echo "  Average Frame Time: ${nocterm_mean_avg}µs"
echo ""
echo "Ink (${#ink_fps[@]} runs):"
echo "  Average FPS: $ink_fps_avg"
echo "  Average Frame Time: ${ink_mean_avg}µs"
echo ""

# Save raw results
cat > "$RESULTS_DIR/frame_time_benchmark_10runs.json" << EOF
{
  "metadata": {
    "runs": $RUNS,
    "date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "machine": "Apple M4 Pro, 48GB RAM"
  },
  "nocterm": {
    "fps": [${nocterm_fps[*]}],
    "mean_us": [${nocterm_mean[*]}],
    "median_us": [${nocterm_median[*]}],
    "averages": {
      "fps": $nocterm_fps_avg,
      "mean_us": $nocterm_mean_avg
    }
  },
  "ink": {
    "fps": [${ink_fps[*]}],
    "mean_us": [${ink_mean[*]}],
    "median_us": [${ink_median[*]}],
    "averages": {
      "fps": $ink_fps_avg,
      "mean_us": $ink_mean_avg
    }
  }
}
EOF

echo "Results saved to $RESULTS_DIR/frame_time_benchmark_10runs.json"
