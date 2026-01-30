#!/bin/bash

# Simple TUI Framework Benchmark Runner
# Focuses on startup time and binary sizes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS_DIR="$SCRIPT_DIR/apps"
RESULTS_DIR="$SCRIPT_DIR/results"
RUNS_PER_TEST=${RUNS_PER_TEST:-3}

mkdir -p "$RESULTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[BENCH]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERR]${NC} $1"; }

# Get system info
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
        cpu_model=$(grep "model name" /proc/cpuinfo 2>/dev/null | head -1 | cut -d: -f2 | xargs || echo "Unknown")
        cpu_cores=$(nproc 2>/dev/null || echo "0")
        memory_gb=$(echo "scale=2; $(grep MemTotal /proc/meminfo 2>/dev/null | awk '{print $2}') / 1048576" | bc 2>/dev/null || echo "0")
    fi

    cat << EOF
{
    "os": "$os",
    "arch": "$arch",
    "cpuModel": "$cpu_model",
    "cpuCores": $cpu_cores,
    "memoryGb": $memory_gb,
    "nodeVersion": "$(node --version 2>/dev/null || echo 'N/A')",
    "dartVersion": "$(dart --version 2>&1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo 'N/A')"
}
EOF
}

# Build all apps first
build_all() {
    log "Building all benchmark applications..."

    for test_dir in "$APPS_DIR"/*/; do
        local test_name=$(basename "$test_dir")

        # Build Ink
        if [[ -d "$test_dir/ink" ]]; then
            log "Building Ink $test_name..."
            cd "$test_dir/ink"
            if [[ ! -d "node_modules" ]]; then
                npm install --silent 2>/dev/null || npm install
            fi
            npm run build --silent 2>/dev/null || npm run build
            success "Ink $test_name built"
        fi

        # Build Nocterm
        if [[ -d "$test_dir/nocterm" ]]; then
            log "Building Nocterm $test_name..."
            cd "$test_dir/nocterm"
            dart pub get --no-precompile 2>/dev/null || dart pub get
            dart compile exe bin/app.dart -o app_exe 2>/dev/null || dart compile exe bin/app.dart -o app_exe
            success "Nocterm $test_name built"
        fi
    done
}

# Measure binary sizes
measure_sizes() {
    log "Measuring binary sizes..."

    for test_dir in "$APPS_DIR"/*/; do
        local test_name=$(basename "$test_dir")
        local ink_dir="$test_dir/ink"
        local nocterm_dir="$test_dir/nocterm"

        # Ink sizes
        local ink_dist=0
        local ink_modules=0
        if [[ -d "$ink_dir/dist" ]]; then
            ink_dist=$(du -sk "$ink_dir/dist" 2>/dev/null | cut -f1)
            ink_dist=$((ink_dist * 1024))
        fi
        if [[ -d "$ink_dir/node_modules" ]]; then
            ink_modules=$(du -sk "$ink_dir/node_modules" 2>/dev/null | cut -f1)
            ink_modules=$((ink_modules * 1024))
        fi

        # Nocterm size
        local nocterm_exe=0
        if [[ -f "$nocterm_dir/app_exe" ]]; then
            nocterm_exe=$(stat -f%z "$nocterm_dir/app_exe" 2>/dev/null || stat -c%s "$nocterm_dir/app_exe" 2>/dev/null || echo 0)
        fi

        cat > "$RESULTS_DIR/${test_name}_sizes.json" << EOF
{
    "ink": {
        "distBytes": $ink_dist,
        "nodeModulesBytes": $ink_modules,
        "totalBytes": $((ink_dist + ink_modules))
    },
    "nocterm": {
        "exeBytes": $nocterm_exe
    }
}
EOF

        local ink_mb=$(echo "scale=2; ($ink_dist + $ink_modules) / 1048576" | bc)
        local nocterm_mb=$(echo "scale=2; $nocterm_exe / 1048576" | bc)
        success "$test_name sizes: Ink=${ink_mb}MB, Nocterm=${nocterm_mb}MB"
    done
}

# Run Ink benchmark
run_ink() {
    local app_dir="$1"
    local test_name="$2"
    local run_idx="$3"
    local output="$RESULTS_DIR/${test_name}_ink_run${run_idx}.json"

    cd "$app_dir"
    local stderr_file="${output}.stderr"

    # Run with timeout, capture stderr
    timeout 10 node dist/index.js 2>"$stderr_file" </dev/null || true

    # Parse first_frame event
    local first_frame_ms=$(grep -o '"event":"first_frame".*"timeMs":[0-9.]*' "$stderr_file" 2>/dev/null | grep -oE '[0-9.]+$' | head -1 || echo "0")
    local first_frame_us=$(python3 -c "print(int(float('${first_frame_ms}') * 1000))" 2>/dev/null || echo "0")

    # Parse memory
    local heap_mb=$(grep -o '"heapUsedMb":[0-9.]*' "$stderr_file" 2>/dev/null | tail -1 | grep -oE '[0-9.]+' || echo "0")
    local rss_mb=$(grep -o '"rssMb":[0-9.]*' "$stderr_file" 2>/dev/null | tail -1 | grep -oE '[0-9.]+' || echo "0")

    cat > "$output" << EOF
{
    "runIndex": $run_idx,
    "startup": {
        "firstFrameUs": $first_frame_us,
        "processStartToReadyUs": $first_frame_us
    },
    "memory": {
        "heapUsedMb": $heap_mb,
        "peakMb": $rss_mb
    }
}
EOF

    echo "$first_frame_us"
}

# Run Nocterm benchmark
run_nocterm() {
    local app_dir="$1"
    local test_name="$2"
    local run_idx="$3"
    local output="$RESULTS_DIR/${test_name}_nocterm_run${run_idx}.json"

    cd "$app_dir"
    local stderr_file="${output}.stderr"

    # Run with 'q' input to quit, with timeout
    (sleep 1 && echo "q") | timeout 10 ./app_exe 2>"$stderr_file" || true

    # Parse first_frame event
    local first_frame_ms=$(grep -o '"event":"first_frame".*"timeMs":[0-9.]*' "$stderr_file" 2>/dev/null | grep -oE '[0-9.]+$' | head -1 || echo "0")
    local first_frame_us=$(python3 -c "print(int(float('${first_frame_ms}') * 1000))" 2>/dev/null || echo "0")

    cat > "$output" << EOF
{
    "runIndex": $run_idx,
    "startup": {
        "firstFrameUs": $first_frame_us,
        "processStartToReadyUs": $first_frame_us
    }
}
EOF

    echo "$first_frame_us"
}

# Run all benchmarks
run_benchmarks() {
    log "Running benchmarks ($RUNS_PER_TEST runs per test)..."

    for test_dir in "$APPS_DIR"/*/; do
        local test_name=$(basename "$test_dir")
        log "Benchmarking $test_name..."

        for i in $(seq 1 $RUNS_PER_TEST); do
            # Ink
            if [[ -d "$test_dir/ink" ]]; then
                run_ink "$test_dir/ink" "$test_name" "$i" >/dev/null 2>&1
                log "  Ink run $i complete"
            fi

            # Nocterm
            if [[ -d "$test_dir/nocterm" ]]; then
                run_nocterm "$test_dir/nocterm" "$test_name" "$i" >/dev/null 2>&1
                log "  Nocterm run $i complete"
            fi

            sleep 0.3
        done

        success "$test_name benchmarks complete"
    done
}

# Generate final JSON
generate_results() {
    log "Generating results JSON..."

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local machine_info=$(get_system_info)

    # Build results array using Python for proper JSON handling
    python3 << PYEOF
import json
import os
import glob

results_dir = "$RESULTS_DIR"
apps_dir = "$APPS_DIR"
runs_per_test = $RUNS_PER_TEST

# Machine info
machine = $machine_info

# Collect results
results = []

# Get test directories
test_dirs = sorted(glob.glob(os.path.join(apps_dir, "*/")))

for test_dir in test_dirs:
    test_name = os.path.basename(test_dir.rstrip('/'))
    schema_name = test_name.split('_', 1)[1] if '_' in test_name else test_name  # Remove number prefix

    # Load sizes
    sizes_file = os.path.join(results_dir, f"{test_name}_sizes.json")
    sizes = {"ink": {}, "nocterm": {}}
    if os.path.exists(sizes_file):
        try:
            with open(sizes_file) as f:
                sizes = json.load(f)
        except:
            pass

    # Process Ink results
    ink_runs = []
    ink_startup_sum = 0
    for i in range(1, runs_per_test + 1):
        run_file = os.path.join(results_dir, f"{test_name}_ink_run{i}.json")
        if os.path.exists(run_file):
            try:
                with open(run_file) as f:
                    run = json.load(f)
                    ink_runs.append(run)
                    ink_startup_sum += run.get("startup", {}).get("firstFrameUs", 0)
            except:
                pass

    if ink_runs:
        ink_mean = ink_startup_sum // len(ink_runs) if ink_runs else 0
        results.append({
            "framework": "ink",
            "testName": schema_name,
            "variant": "cold_start",
            "binarySize": {
                "bytes": sizes.get("ink", {}).get("distBytes", 0),
                "bundleSizeBytes": sizes.get("ink", {}).get("nodeModulesBytes", 0)
            },
            "runs": ink_runs,
            "statistics": {
                "startupTime": {"mean": ink_mean}
            }
        })

    # Process Nocterm results
    nocterm_runs = []
    nocterm_startup_sum = 0
    for i in range(1, runs_per_test + 1):
        run_file = os.path.join(results_dir, f"{test_name}_nocterm_run{i}.json")
        if os.path.exists(run_file):
            try:
                with open(run_file) as f:
                    run = json.load(f)
                    nocterm_runs.append(run)
                    nocterm_startup_sum += run.get("startup", {}).get("firstFrameUs", 0)
            except:
                pass

    if nocterm_runs:
        nocterm_mean = nocterm_startup_sum // len(nocterm_runs) if nocterm_runs else 0
        results.append({
            "framework": "nocterm",
            "testName": schema_name,
            "variant": "cold_start",
            "binarySize": {
                "bytes": sizes.get("nocterm", {}).get("exeBytes", 0)
            },
            "runs": nocterm_runs,
            "statistics": {
                "startupTime": {"mean": nocterm_mean}
            }
        })

# Write final results
output = {
    "metadata": {
        "timestamp": "$timestamp",
        "machine": machine,
        "terminalSize": {"cols": 80, "rows": 24},
        "runsPerTest": runs_per_test
    },
    "results": results
}

with open(os.path.join(results_dir, "benchmark_results.json"), "w") as f:
    json.dump(output, f, indent=2)

print(f"Results written with {len(results)} test results")
PYEOF

    success "Results saved to $RESULTS_DIR/benchmark_results.json"
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
    print(f"Runs per test: {data['metadata']['runsPerTest']}\n")

    # Group by test
    tests = {}
    for r in data['results']:
        t = r['testName']
        if t not in tests:
            tests[t] = {}
        tests[t][r['framework']] = r

    # Print comparison table
    print(f"{'Test':<18} {'Metric':<12} {'Ink':<14} {'Nocterm':<14} {'Winner':<10} {'Speedup':<10}")
    print("-" * 78)

    for test in sorted(tests.keys()):
        ink = tests[test].get('ink', {})
        nocterm = tests[test].get('nocterm', {})

        # Startup
        ink_startup = ink.get('statistics', {}).get('startupTime', {}).get('mean', 0)
        nocterm_startup = nocterm.get('statistics', {}).get('startupTime', {}).get('mean', 0)

        ink_ms = ink_startup / 1000
        nocterm_ms = nocterm_startup / 1000

        if ink_ms > 0 and nocterm_ms > 0:
            winner = "Nocterm" if nocterm_ms < ink_ms else "Ink"
            speedup = f"{ink_ms/nocterm_ms:.1f}x" if nocterm_ms < ink_ms else f"{nocterm_ms/ink_ms:.1f}x"
        else:
            winner = "N/A"
            speedup = "N/A"

        print(f"{test:<18} {'Startup(ms)':<12} {ink_ms:<14.2f} {nocterm_ms:<14.2f} {winner:<10} {speedup:<10}")

        # Size
        ink_size = ink.get('binarySize', {})
        ink_bytes = ink_size.get('bytes', 0) + ink_size.get('bundleSizeBytes', 0)
        nocterm_bytes = nocterm.get('binarySize', {}).get('bytes', 0)

        ink_mb = ink_bytes / 1024 / 1024
        nocterm_mb = nocterm_bytes / 1024 / 1024

        if ink_mb > 0 and nocterm_mb > 0:
            size_winner = "Nocterm" if nocterm_mb < ink_mb else "Ink"
            size_ratio = f"{ink_mb/nocterm_mb:.1f}x" if nocterm_mb < ink_mb else f"{nocterm_mb/ink_mb:.1f}x"
        else:
            size_winner = "N/A"
            size_ratio = "N/A"

        print(f"{'':<18} {'Size(MB)':<12} {ink_mb:<14.2f} {nocterm_mb:<14.2f} {size_winner:<10} {size_ratio:<10}")
        print()

except Exception as e:
    print(f"Error: {e}")
PYEOF
}

# Main
main() {
    echo "=========================================="
    echo "  TUI Framework Benchmark Suite"
    echo "  Ink (Node.js) vs Nocterm (Dart)"
    echo "=========================================="

    # Clean old results
    rm -f "$RESULTS_DIR"/*.json "$RESULTS_DIR"/*.stderr

    build_all
    measure_sizes
    run_benchmarks
    generate_results

    export RESULTS_DIR
    print_summary

    success "Benchmark complete!"
}

export RESULTS_DIR
main "$@"
