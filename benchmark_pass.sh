#!/bin/bash

# Benchmark script for comparing baseline -O0 vs -O0 with custom LLVM pass
# This script builds and runs embench-iot benchmarks for speed comparison
#
# Usage: ./benchmark_pass.sh [OPTIONS]
#   --embench-dir <path>    Path to embench-iot directory
#   --pass-so <path>        Path to LLVM pass .so file
#   --iterations <num>      Number of iterations per benchmark (default: 5000)
#   --timeout <sec>         Timeout per benchmark in seconds (default: 120)
#   --baseline-flags <str>  Compiler flags for baseline (default: "-O0")
#   --pass-flags <str>      Additional flags for pass build (default: uses pass-so)
#   --help                  Show this help message

set -e  # Exit on error

# Default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMBENCH_DIR="${SCRIPT_DIR}/embench-iot"
PASS_SO="${SCRIPT_DIR}/llvm-pass-skeleton/build/skeleton/SkeletonPass.so"
ITERATIONS=5000
TIMEOUT=120
BASELINE_FLAGS="-O0"
PASS_FLAGS=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --embench-dir)
            EMBENCH_DIR="$2"
            shift 2
            ;;
        --pass-so)
            PASS_SO="$2"
            shift 2
            ;;
        --iterations)
            ITERATIONS="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --baseline-flags)
            BASELINE_FLAGS="$2"
            shift 2
            ;;
        --pass-flags)
            PASS_FLAGS="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --embench-dir <path>    Path to embench-iot directory (default: ./embench-iot)"
            echo "  --pass-so <path>        Path to LLVM pass .so file (default: ./llvm-pass-skeleton/build/skeleton/SkeletonPass.so)"
            echo "  --iterations <num>      Number of iterations per benchmark (default: 5000)"
            echo "  --timeout <sec>         Timeout per benchmark in seconds (default: 120)"
            echo "  --baseline-flags <str>  Compiler flags for baseline (default: \"-O0\")"
            echo "  --pass-flags <str>      Additional flags for pass build (default: uses --baseline-flags + pass)"
            echo "  --help                  Show this help message"
            echo ""
            echo "Example:"
            echo "  $0 --iterations 10000 --baseline-flags \"-O2\""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Set pass flags if not specified
if [ -z "${PASS_FLAGS}" ]; then
    PASS_FLAGS="${BASELINE_FLAGS} -fpass-plugin=${PASS_SO}"
fi

# Derived paths
BUILD_DIR_BASELINE="${EMBENCH_DIR}/bd_baseline"
BUILD_DIR_WITH_PASS="${EMBENCH_DIR}/bd_with_pass"
LOG_DIR="${EMBENCH_DIR}/logs"
RESULTS_DIR="${EMBENCH_DIR}/benchmark_results"

# Create results directory if it doesn't exist
mkdir -p "${RESULTS_DIR}"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Embench-IoT Pass Benchmark Script${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Configuration:"
echo "  Embench directory: ${EMBENCH_DIR}"
echo "  Pass .so file:     ${PASS_SO}"
echo "  Iterations:        ${ITERATIONS}"
echo "  Timeout:           ${TIMEOUT}s"
echo "  Baseline flags:    ${BASELINE_FLAGS}"
echo "  Pass flags:        ${PASS_FLAGS}"
echo ""

# Check if pass exists
if [ ! -f "${PASS_SO}" ]; then
    echo -e "${YELLOW}Warning: Pass not found at ${PASS_SO}${NC}"
    echo "Building the pass first..."
    cd /home/cynyu_s/6120CS/loop_opt/llvm-pass-skeleton/build
    make
    cd -
fi

# Navigate to embench directory
cd "${EMBENCH_DIR}"

# ============================================
# Step 1: Build baseline (without pass)
# ============================================
echo -e "${GREEN}Step 1: Building baseline benchmarks with ${BASELINE_FLAGS}${NC}"
python3 build_all.py \
    --arch native \
    --chip speed-test-gcc \
    --board default \
    --cc clang \
    --cflags="${BASELINE_FLAGS}" \
    --builddir "${BUILD_DIR_BASELINE}" \
    --logdir "${LOG_DIR}" \
    --clean

echo ""
echo -e "${GREEN}Baseline build complete!${NC}"
echo ""

# ============================================
# Step 2: Build with pass
# ============================================
echo -e "${GREEN}Step 2: Building benchmarks with custom pass${NC}"
python3 build_all.py \
    --arch native \
    --chip speed-test-gcc \
    --board default \
    --cc clang \
    --cflags="${PASS_FLAGS}" \
    --builddir "${BUILD_DIR_WITH_PASS}" \
    --logdir "${LOG_DIR}" \
    --clean

echo ""
echo -e "${GREEN}Pass-enabled build complete!${NC}"
echo ""

# ============================================
# Step 3: Run baseline speed benchmark
# ============================================
echo -e "${GREEN}Step 3: Running baseline speed benchmark${NC}"
python3 benchmark_speed.py \
    --builddir "${BUILD_DIR_BASELINE}" \
    --logdir "${LOG_DIR}" \
    --target-module run_native_precise \
    --absolute \
    --json-output \
    --timeout ${TIMEOUT} \
    --iterations ${ITERATIONS} > "${RESULTS_DIR}/speed_baseline.json"

echo ""
echo -e "${GREEN}Baseline benchmark complete!${NC}"
echo ""

# Also save text output for easy reading
python3 benchmark_speed.py \
    --builddir "${BUILD_DIR_BASELINE}" \
    --logdir "${LOG_DIR}" \
    --target-module run_native_precise \
    --absolute \
    --text-output \
    --timeout ${TIMEOUT} \
    --iterations ${ITERATIONS} > "${RESULTS_DIR}/speed_baseline.txt"

# ============================================
# Step 4: Run speed benchmark with pass
# ============================================
echo -e "${GREEN}Step 4: Running speed benchmark with pass${NC}"
python3 benchmark_speed.py \
    --builddir "${BUILD_DIR_WITH_PASS}" \
    --logdir "${LOG_DIR}" \
    --target-module run_native_precise \
    --absolute \
    --json-output \
    --timeout ${TIMEOUT} \
    --iterations ${ITERATIONS} > "${RESULTS_DIR}/speed_with_pass.json"

echo ""
echo -e "${GREEN}Pass-enabled benchmark complete!${NC}"
echo ""

# Also save text output for easy reading
python3 benchmark_speed.py \
    --builddir "${BUILD_DIR_WITH_PASS}" \
    --logdir "${LOG_DIR}" \
    --target-module run_native_precise \
    --absolute \
    --text-output \
    --timeout ${TIMEOUT} \
    --iterations ${ITERATIONS} > "${RESULTS_DIR}/speed_with_pass.txt"

# ============================================
# Step 5: Generate comparison report
# ============================================
echo -e "${GREEN}Step 5: Generating comparison report${NC}"

# Create a Python script to compare results
cat > "${RESULTS_DIR}/compare_results.py" << 'EOF'
#!/usr/bin/env python3
import json
import sys

def load_results(filename):
    with open(filename, 'r') as f:
        data = json.load(f)
    return data

def main():
    baseline_file = sys.argv[1]
    pass_file = sys.argv[2]
    
    baseline = load_results(baseline_file)
    with_pass = load_results(pass_file)
    
    print("=" * 80)
    print("BENCHMARK COMPARISON: Baseline vs With Pass")
    print("=" * 80)
    print()
    print(f"{'Benchmark':<20} {'Baseline (ms)':<15} {'With Pass (ms)':<15} {'Speedup':<10} {'% Change'}")
    print("-" * 80)
    
    baseline_results = baseline.get('benchmarks', {})
    pass_results = with_pass.get('benchmarks', {})
    
    speedups = []
    
    for bench_name in sorted(baseline_results.keys()):
        if bench_name in pass_results:
            baseline_time = baseline_results[bench_name]
            pass_time = pass_results[bench_name]
            
            if pass_time > 0:
                speedup = baseline_time / pass_time
                pct_change = ((pass_time - baseline_time) / baseline_time) * 100
                speedups.append(speedup)
                
                print(f"{bench_name:<20} {baseline_time:<15.2f} {pass_time:<15.2f} {speedup:<10.3f} {pct_change:>+7.2f}%")
    
    print("-" * 80)
    
    if speedups:
        # Geometric mean
        from functools import reduce
        import operator
        geomean = reduce(operator.mul, speedups, 1.0) ** (1.0 / len(speedups))
        print(f"\nGeometric Mean Speedup: {geomean:.3f}x")
        
        avg_speedup = sum(speedups) / len(speedups)
        print(f"Arithmetic Mean Speedup: {avg_speedup:.3f}x")
        print()
        
        if geomean > 1.0:
            print(f"✓ Pass IMPROVED performance by {(geomean - 1.0) * 100:.2f}%")
        elif geomean < 1.0:
            print(f"✗ Pass DEGRADED performance by {(1.0 - geomean) * 100:.2f}%")
        else:
            print("= Pass had NO EFFECT on performance")
    
    print()
    print("Raw results saved in:")
    print(f"  Baseline: {baseline_file}")
    print(f"  With Pass: {pass_file}")
    print()

if __name__ == '__main__':
    main()
EOF

chmod +x "${RESULTS_DIR}/compare_results.py"

python3 "${RESULTS_DIR}/compare_results.py" \
    "${RESULTS_DIR}/speed_baseline.json" \
    "${RESULTS_DIR}/speed_with_pass.json" | tee "${RESULTS_DIR}/comparison_report.txt"

echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}Benchmark Complete!${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo "Results saved to: ${RESULTS_DIR}"
echo "  - speed_baseline.json/txt"
echo "  - speed_with_pass.json/txt"
echo "  - comparison_report.txt"
echo ""
