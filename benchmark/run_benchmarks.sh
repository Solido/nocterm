#!/bin/bash

# TUI Framework Benchmark Runner
# Compares Ink (Node.js) vs Nocterm (Dart) performance

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
RESULTS_DIR="$SCRIPT_DIR/results"
RUNS_PER_TEST=${RUNS_PER_TEST:-3}

# Create results directory
mkdir -p "$RESULTS_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_status() {
    echo -e "${BLUE}[BENCHMARK]${NC} $1"
}

echo_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

echo_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Get system information
get_system_info() {
    local os=$(uname -s)
    local arch=$(uname -m)
    local cpu_model=""
    local cpu_cores=""
    local memory_gb=""

    if [[ "$os" == "Darwin" ]]; then
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
        cpu_cores=$(sysctl -n hw.ncpu 2>/dev/null || echo "0")
        memory_gb=$(echo "scale=2; $(sysctl -n hw.memsize 2>/dev/null || echo "0") / 1073741824" | bc)
    else
        cpu_model=$(cat /proc/cpuinfo 2>/dev/null | grep "model name" | head -1 | cut -d: -f2 | xargs || echo "Unknown")
        cpu_cores=$(nproc 2>/dev/null || echo "0")
        memory_gb=$(echo "scale=2; $(cat /proc/meminfo 2>/dev/null | grep MemTotal | awk '{print $2}') / 1048576" | bc 2>/dev/null || echo "0")
    fi

    local node_version=$(node --version 2>/dev/null || echo "N/A")
    local dart_version=$(dart --version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "N/A")

    cat << EOF
{
    "os": "$os",
    "arch": "$arch",
    "cpuModel": "$cpu_model",
    "cpuCores": $cpu_cores,
    "memoryGb": $memory_gb,
    "nodeVersion": "$node_version",
    "dartVersion": "$dart_version"
}
EOF
}

# Get directory size in bytes
get_dir_size() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        # macOS uses -k for kilobytes, Linux has -b for bytes
        if [[ "$(uname -s)" == "Darwin" ]]; then
            local kb=$(du -sk "$dir" 2>/dev/null | cut -f1)
            echo $((kb * 1024))
        else
            du -sb "$dir" 2>/dev/null | cut -f1 || echo "0"
        fi
    else
        echo "0"
    fi
}

# Get file size in bytes
get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Run a command and capture memory usage (macOS)
run_with_memory() {
    local cmd="$1"
    local output_file="$2"
    local timeout_sec="${3:-30}"

    # Use /usr/bin/time for memory measurement on macOS
    if [[ "$(uname -s)" == "Darwin" ]]; then
        /usr/bin/time -l timeout "$timeout_sec" $cmd 2>&1 | tee "$output_file.time" || true
        # Extract max RSS from time output (in bytes on macOS)
        local max_rss=$(grep "maximum resident set size" "$output_file.time" 2>/dev/null | awk '{print $1}' || echo "0")
        echo "$max_rss"
    else
        /usr/bin/time -v timeout "$timeout_sec" $cmd 2>&1 | tee "$output_file.time" || true
        local max_rss=$(grep "Maximum resident set size" "$output_file.time" 2>/dev/null | awk '{print $NF}' || echo "0")
        # Convert from KB to bytes
        echo $((max_rss * 1024))
    fi
}

# Build Ink app
build_ink() {
    local app_dir="$1"
    echo_status "Building Ink app in $app_dir"

    cd "$app_dir"

    # Install dependencies if needed
    if [[ ! -d "node_modules" ]]; then
        npm install --silent 2>/dev/null || npm install
    fi

    # Build TypeScript
    npm run build --silent 2>/dev/null || npm run build

    echo_success "Ink app built successfully"
}

# Build Nocterm app
build_nocterm() {
    local app_dir="$1"
    local app_name="$2"
    echo_status "Building Nocterm app in $app_dir"

    cd "$app_dir"

    # Get dependencies
    dart pub get --no-precompile 2>/dev/null || dart pub get

    # Compile to native executable
    dart compile exe bin/app.dart -o "app_exe" 2>/dev/null || dart compile exe bin/app.dart -o "app_exe"

    echo_success "Nocterm app built successfully"
}

# Run Ink benchmark
run_ink_benchmark() {
    local app_dir="$1"
    local test_name="$2"
    local run_index="$3"
    local output_file="$RESULTS_DIR/${test_name}_ink_run${run_index}.json"

    cd "$app_dir"

    echo_status "Running Ink $test_name (run $run_index)"

    local start_time=$(python3 -c "import time; print(int(time.time() * 1000000))")

    # Run the app with timeout, capturing stderr (which has measurements)
    local stderr_file="$output_file.stderr"
    timeout 10 node dist/index.js 2>"$stderr_file" </dev/null || true

    local end_time=$(python3 -c "import time; print(int(time.time() * 1000000))")
    local total_time_us=$((end_time - start_time))

    # Extract first_frame event from stderr
    local first_frame_ms=$(grep '"event":"first_frame"' "$stderr_file" 2>/dev/null | head -1 | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('timeMs', 0))" 2>/dev/null || echo "0")
    local first_frame_us=$(python3 -c "print(int($first_frame_ms * 1000))")

    # Memory info
    local mem_info=$(grep '"event":"memory"' "$stderr_file" 2>/dev/null | tail -1)
    local heap_mb=$(echo "$mem_info" | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('heapUsedMb', 0))" 2>/dev/null || echo "0")
    local rss_mb=$(echo "$mem_info" | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('rssMb', 0))" 2>/dev/null || echo "0")

    # Write result
    cat > "$output_file" << EOF
{
    "runIndex": $run_index,
    "startup": {
        "firstFrameUs": $first_frame_us,
        "processStartToReadyUs": $first_frame_us
    },
    "memory": {
        "heapUsedMb": $heap_mb,
        "peakMb": $rss_mb
    },
    "totalTimeUs": $total_time_us
}
EOF

    echo_success "Ink $test_name run $run_index complete (first frame: ${first_frame_ms}ms)"
}

# Run Nocterm benchmark
run_nocterm_benchmark() {
    local app_dir="$1"
    local test_name="$2"
    local run_index="$3"
    local output_file="$RESULTS_DIR/${test_name}_nocterm_run${run_index}.json"

    cd "$app_dir"

    echo_status "Running Nocterm $test_name (run $run_index)"

    local start_time=$(python3 -c "import time; print(int(time.time() * 1000000))")

    # Run the compiled executable with timeout
    local stderr_file="$output_file.stderr"

    # Send 'q' after a short delay to quit the app
    (sleep 2 && echo "q") | timeout 10 ./app_exe 2>"$stderr_file" || true

    local end_time=$(python3 -c "import time; print(int(time.time() * 1000000))")
    local total_time_us=$((end_time - start_time))

    # Extract first_frame event from stderr
    local first_frame_ms=$(grep '"event":"first_frame"' "$stderr_file" 2>/dev/null | head -1 | python3 -c "import sys, json; d=json.loads(sys.stdin.read()); print(d.get('timeMs', 0))" 2>/dev/null || echo "0")
    local first_frame_us=$(python3 -c "print(int($first_frame_ms * 1000))")

    # Write result
    cat > "$output_file" << EOF
{
    "runIndex": $run_index,
    "startup": {
        "firstFrameUs": $first_frame_us,
        "processStartToReadyUs": $first_frame_us
    },
    "totalTimeUs": $total_time_us
}
EOF

    echo_success "Nocterm $test_name run $run_index complete (first frame: ${first_frame_ms}ms)"
}

# Collect binary sizes
collect_binary_sizes() {
    local test_name="$1"
    local ink_dir="$2"
    local nocterm_dir="$3"

    echo_status "Collecting binary sizes for $test_name"

    # Ink: measure dist folder and node_modules
    local ink_dist_size=$(get_dir_size "$ink_dir/dist")
    local ink_modules_size=$(get_dir_size "$ink_dir/node_modules")
    local ink_total=$((ink_dist_size + ink_modules_size))

    # Nocterm: measure compiled executable
    local nocterm_exe_size=$(get_file_size "$nocterm_dir/app_exe")

    cat > "$RESULTS_DIR/${test_name}_sizes.json" << EOF
{
    "ink": {
        "distBytes": $ink_dist_size,
        "nodeModulesBytes": $ink_modules_size,
        "totalBytes": $ink_total
    },
    "nocterm": {
        "exeBytes": $nocterm_exe_size
    }
}
EOF

    echo_success "Binary sizes: Ink=${ink_total} bytes, Nocterm=${nocterm_exe_size} bytes"
}

# Main benchmark for a single test
run_test_benchmark() {
    local test_dir="$1"
    local test_name=$(basename "$test_dir")

    echo ""
    echo "=========================================="
    echo "  Benchmarking: $test_name"
    echo "=========================================="

    local ink_dir="$test_dir/ink"
    local nocterm_dir="$test_dir/nocterm"

    # Build both apps
    if [[ -d "$ink_dir" ]]; then
        build_ink "$ink_dir"
    else
        echo_warning "No Ink app found for $test_name"
    fi

    if [[ -d "$nocterm_dir" ]]; then
        build_nocterm "$nocterm_dir" "$test_name"
    else
        echo_warning "No Nocterm app found for $test_name"
    fi

    # Collect binary sizes
    if [[ -d "$ink_dir" ]] && [[ -d "$nocterm_dir" ]]; then
        collect_binary_sizes "$test_name" "$ink_dir" "$nocterm_dir"
    fi

    # Run benchmarks
    for i in $(seq 1 $RUNS_PER_TEST); do
        if [[ -d "$ink_dir" ]]; then
            run_ink_benchmark "$ink_dir" "$test_name" "$i"
        fi

        if [[ -d "$nocterm_dir" ]]; then
            run_nocterm_benchmark "$nocterm_dir" "$test_name" "$i"
        fi

        # Small delay between runs
        sleep 0.5
    done
}

# Generate final results JSON
generate_results_json() {
    echo_status "Generating final results JSON"

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local machine_info=$(get_system_info)

    # Start JSON
    cat > "$RESULTS_DIR/benchmark_results.json" << EOF
{
  "metadata": {
    "timestamp": "$timestamp",
    "machine": $machine_info,
    "terminalSize": {
      "cols": 80,
      "rows": 24
    },
    "runsPerTest": $RUNS_PER_TEST
  },
  "results": [
EOF

    # Process each test
    local first_result=true
    for test_dir in "$APPS_DIR"/*/; do
        local test_name=$(basename "$test_dir")
        # Map directory names to schema enum values
        local schema_test_name=$(echo "$test_name" | sed 's/^[0-9]*_//')

        # Process Ink results
        if ls "$RESULTS_DIR/${test_name}_ink_run"*.json 1>/dev/null 2>&1; then
            if [[ "$first_result" != "true" ]]; then
                echo "," >> "$RESULTS_DIR/benchmark_results.json"
            fi
            first_result=false

            # Collect runs
            local runs="["
            local first_run=true
            local total_startup=0
            local run_count=0

            for run_file in "$RESULTS_DIR/${test_name}_ink_run"*.json; do
                if [[ "$first_run" != "true" ]]; then
                    runs="$runs,"
                fi
                first_run=false
                runs="$runs$(cat "$run_file")"

                # Accumulate for statistics
                local startup=$(python3 -c "import json; d=json.load(open('$run_file')); print(d.get('startup', {}).get('firstFrameUs', 0))")
                total_startup=$((total_startup + startup))
                run_count=$((run_count + 1))
            done
            runs="$runs]"

            # Get binary size
            local ink_size=0
            local ink_bundle=0
            if [[ -f "$RESULTS_DIR/${test_name}_sizes.json" ]]; then
                ink_size=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/${test_name}_sizes.json')); print(d.get('ink', {}).get('distBytes', 0))")
                ink_bundle=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/${test_name}_sizes.json')); print(d.get('ink', {}).get('nodeModulesBytes', 0))")
            fi

            # Calculate mean
            local mean_startup=0
            if [[ $run_count -gt 0 ]]; then
                mean_startup=$((total_startup / run_count))
            fi

            cat >> "$RESULTS_DIR/benchmark_results.json" << EOF
    {
      "framework": "ink",
      "testName": "$schema_test_name",
      "variant": "cold_start",
      "binarySize": {
        "bytes": $ink_size,
        "bundleSizeBytes": $ink_bundle
      },
      "runs": $runs,
      "statistics": {
        "startupTime": {
          "mean": $mean_startup
        }
      }
    }
EOF
        fi

        # Process Nocterm results
        if ls "$RESULTS_DIR/${test_name}_nocterm_run"*.json 1>/dev/null 2>&1; then
            if [[ "$first_result" != "true" ]]; then
                echo "," >> "$RESULTS_DIR/benchmark_results.json"
            fi
            first_result=false

            # Collect runs
            local runs="["
            local first_run=true
            local total_startup=0
            local run_count=0

            for run_file in "$RESULTS_DIR/${test_name}_nocterm_run"*.json; do
                if [[ "$first_run" != "true" ]]; then
                    runs="$runs,"
                fi
                first_run=false
                runs="$runs$(cat "$run_file")"

                # Accumulate for statistics
                local startup=$(python3 -c "import json; d=json.load(open('$run_file')); print(d.get('startup', {}).get('firstFrameUs', 0))")
                total_startup=$((total_startup + startup))
                run_count=$((run_count + 1))
            done
            runs="$runs]"

            # Get binary size
            local nocterm_size=0
            if [[ -f "$RESULTS_DIR/${test_name}_sizes.json" ]]; then
                nocterm_size=$(python3 -c "import json; d=json.load(open('$RESULTS_DIR/${test_name}_sizes.json')); print(d.get('nocterm', {}).get('exeBytes', 0))")
            fi

            # Calculate mean
            local mean_startup=0
            if [[ $run_count -gt 0 ]]; then
                mean_startup=$((total_startup / run_count))
            fi

            cat >> "$RESULTS_DIR/benchmark_results.json" << EOF
    {
      "framework": "nocterm",
      "testName": "$schema_test_name",
      "variant": "cold_start",
      "binarySize": {
        "bytes": $nocterm_size
      },
      "runs": $runs,
      "statistics": {
        "startupTime": {
          "mean": $mean_startup
        }
      }
    }
EOF
        fi
    done

    # Close JSON
    cat >> "$RESULTS_DIR/benchmark_results.json" << EOF

  ]
}
EOF

    echo_success "Results written to $RESULTS_DIR/benchmark_results.json"
}

# Print summary
print_summary() {
    echo ""
    echo "=========================================="
    echo "  BENCHMARK SUMMARY"
    echo "=========================================="

    python3 << 'PYEOF'
import json
import os

results_file = os.environ.get('RESULTS_DIR', 'results') + '/benchmark_results.json'
try:
    with open(results_file) as f:
        data = json.load(f)

    print(f"\nMachine: {data['metadata']['machine']['os']} {data['metadata']['machine']['arch']}")
    print(f"Runs per test: {data['metadata']['runsPerTest']}")
    print()

    # Group by test name
    tests = {}
    for result in data['results']:
        test = result['testName']
        framework = result['framework']
        if test not in tests:
            tests[test] = {}
        tests[test][framework] = result

    print(f"{'Test':<20} {'Metric':<15} {'Ink':<15} {'Nocterm':<15} {'Winner':<10}")
    print("-" * 75)

    for test, frameworks in sorted(tests.items()):
        ink = frameworks.get('ink', {})
        nocterm = frameworks.get('nocterm', {})

        # Startup time
        ink_startup = ink.get('statistics', {}).get('startupTime', {}).get('mean', 0)
        nocterm_startup = nocterm.get('statistics', {}).get('startupTime', {}).get('mean', 0)

        ink_startup_ms = ink_startup / 1000 if ink_startup else 0
        nocterm_startup_ms = nocterm_startup / 1000 if nocterm_startup else 0

        winner = "Nocterm" if nocterm_startup_ms < ink_startup_ms else "Ink"
        if ink_startup_ms == 0 or nocterm_startup_ms == 0:
            winner = "N/A"

        print(f"{test:<20} {'Startup (ms)':<15} {ink_startup_ms:<15.2f} {nocterm_startup_ms:<15.2f} {winner:<10}")

        # Binary size
        ink_size = ink.get('binarySize', {}).get('bytes', 0)
        ink_bundle = ink.get('binarySize', {}).get('bundleSizeBytes', 0)
        nocterm_size = nocterm.get('binarySize', {}).get('bytes', 0)

        ink_total_mb = (ink_size + ink_bundle) / 1024 / 1024
        nocterm_mb = nocterm_size / 1024 / 1024

        size_winner = "Nocterm" if nocterm_mb < ink_total_mb else "Ink"
        if ink_total_mb == 0 or nocterm_mb == 0:
            size_winner = "N/A"

        print(f"{'':<20} {'Size (MB)':<15} {ink_total_mb:<15.2f} {nocterm_mb:<15.2f} {size_winner:<10}")
        print()

except Exception as e:
    print(f"Error reading results: {e}")
PYEOF
}

# Main execution
main() {
    echo "=========================================="
    echo "  TUI Framework Benchmark Suite"
    echo "  Ink (Node.js) vs Nocterm (Dart)"
    echo "=========================================="
    echo ""
    echo "Configuration:"
    echo "  - Runs per test: $RUNS_PER_TEST"
    echo "  - Results directory: $RESULTS_DIR"
    echo ""

    # Run benchmarks for each test
    for test_dir in "$APPS_DIR"/*/; do
        if [[ -d "$test_dir" ]]; then
            run_test_benchmark "$test_dir"
        fi
    done

    # Generate final results
    generate_results_json

    # Print summary
    RESULTS_DIR="$RESULTS_DIR" print_summary

    echo ""
    echo_success "Benchmarks complete! Results saved to $RESULTS_DIR/benchmark_results.json"
}

# Export RESULTS_DIR for subshells
export RESULTS_DIR

# Run main
main "$@"
