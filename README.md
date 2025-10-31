# Benchmark Pass Script

## Overview

The `benchmark_pass.sh` script automates the process of benchmarking your LLVM pass against a baseline using the embench-iot benchmark suite.

## Basic Usage

### Reference Platform (from Embench documentation)
- **CPU**: ARM Cortex-M4 @ 16 MHz
- **Architecture**: Embedded microcontroller (ARMv7-M)
- **Target**: Real embedded hardware (STM32F4 Discovery Board)
- **Typical speeds**: 2,000-4,000 milliseconds per benchmark

### Cynthia's Platform
- **CPU**: AMD Ryzen 7 PRO 8840HS w/ Radeon 780M Graphics  (3.30 GHz)
- **Architecture**: CPU on Thinkpad
- **Target**: Native execution on Linux
- **Typical speeds**: 2-5 milliseconds per benchmark

## One-Line Commands

```bash
# Quick test (low precision, ~2-5 min)
./benchmark_pass.sh --iterations 100 --timeout 30

# Standard benchmark (recommended, ~10-15 min)
./benchmark_pass.sh

# High precision (publication quality, ~30-45 min)
./benchmark_pass.sh --iterations 10000 --timeout 300

# Compare against -O2
./benchmark_pass.sh --baseline-flags "-O2"

# Custom pass location
./benchmark_pass.sh --pass-so /path/to/MyPass.so

# Custom embench location
./benchmark_pass.sh --embench-dir /path/to/embench-iot

# Help
./benchmark_pass.sh --help
```

## All Options

| Option | Description | Default |
|--------|-------------|---------|
| `--embench-dir <path>` | Embench directory | `./embench-iot` |
| `--pass-so <path>` | LLVM pass .so file | `./llvm-pass-skeleton/build/skeleton/SkeletonPass.so` |
| `--iterations <num>` | Iterations per benchmark | `5000` |
| `--timeout <sec>` | Timeout per benchmark | `120` |
| `--baseline-flags <str>` | Baseline compiler flags | `"-O0"` |
| `--pass-flags <str>` | Pass compiler flags | `"<baseline> -fpass-plugin=<pass>"` |
| `--help` | Show help | - |

## Results Location

```
embench-iot/benchmark_results/
├── speed_baseline.json          # Baseline results (JSON)
├── speed_baseline.txt           # Baseline results (text)
├── speed_with_pass.json         # Pass results (JSON)
├── speed_with_pass.txt          # Pass results (text)
└── comparison_report.txt        # Comparison with geometric mean
```

## Interpreting Results

- **Speedup > 1.0**: Pass improved performance
- **Speedup = 1.0**: No effect
- **Speedup < 1.0**: Pass degraded performance

Focus on **Geometric Mean Speedup** as your primary metric.


### Default Configuration
```bash
./benchmark_pass.sh
```

This uses default settings:
- Embench directory: `./embench-iot`
- Pass location: `./llvm-pass-skeleton/build/skeleton/SkeletonPass.so`
- Iterations: 5000 per benchmark
- Timeout: 120 seconds per benchmark
- Baseline flags: `-O0`
- Pass flags: `-O0 -fpass-plugin=<path-to-pass>`

## Command Line Options

### Specify Custom Paths

```bash
./benchmark_pass.sh \
    --embench-dir /path/to/embench-iot \
    --pass-so /path/to/YourPass.so
```

### Adjust Benchmark Parameters

```bash
# Faster benchmarking (less precise)
./benchmark_pass.sh --iterations 1000 --timeout 60

# More precise benchmarking (slower)
./benchmark_pass.sh --iterations 10000 --timeout 300
```

### Different Optimization Levels

```bash
# Compare against -O2 baseline
./benchmark_pass.sh --baseline-flags "-O2"

# Compare against -O3 baseline
./benchmark_pass.sh --baseline-flags "-O3"

# Custom baseline with multiple flags
./benchmark_pass.sh --baseline-flags "-O2 -march=native -mtune=native"
```

### Custom Pass Flags

```bash
# Override the default pass flags completely
./benchmark_pass.sh \
    --baseline-flags "-O0" \
    --pass-flags "-O0 -fpass-plugin=/path/to/pass.so -mllvm -enable-loop-unroll"
```

## Complete Examples

### Example 1: Quick Test (Low Precision)
```bash
./benchmark_pass.sh --iterations 100 --timeout 30
```
- Fast execution (~2-5 minutes)
- Lower precision
- Good for initial testing

### Example 2: Standard Benchmark (Recommended)
```bash
./benchmark_pass.sh
```
- Medium execution time (~10-15 minutes)
- Good precision
- Default settings

### Example 3: High Precision Benchmark
```bash
./benchmark_pass.sh --iterations 10000 --timeout 300
```
- Longer execution (~30-45 minutes)
- High precision
- Use for final results

### Example 4: Compare Against Optimized Baseline
```bash
./benchmark_pass.sh \
    --baseline-flags "-O2" \
    --iterations 5000
```
- Tests if your pass improves upon -O2
- More realistic comparison

### Example 5: Custom Everything
```bash
./benchmark_pass.sh \
    --embench-dir ~/benchmarks/embench-iot \
    --pass-so ~/my-llvm-passes/build/MyPass.so \
    --iterations 5000 \
    --timeout 120 \
    --baseline-flags "-O1 -fno-unroll-loops" \
    --pass-flags "-O1 -fno-unroll-loops -fpass-plugin=~/my-llvm-passes/build/MyPass.so"
```

## Output

Results are saved in `embench-iot/benchmark_results/`:
- `speed_baseline.json` - Raw baseline results in JSON
- `speed_baseline.txt` - Human-readable baseline results
- `speed_with_pass.json` - Raw pass results in JSON
- `speed_with_pass.txt` - Human-readable pass results
- `comparison_report.txt` - Detailed comparison with geometric mean

## Interpreting Results

### Speedup Values
- `Speedup > 1.0` → Your pass **improved** performance
- `Speedup = 1.0` → Your pass had **no effect**
- `Speedup < 1.0` → Your pass **degraded** performance

### Geometric Mean
The geometric mean is the standard metric for benchmark suites:
- Accounts for variance across different benchmarks
- More robust than arithmetic mean
- Industry standard for reporting compiler performance

### Example Output
```
Benchmark            Baseline (ms)   With Pass (ms)  Speedup    % Change
--------------------------------------------------------------------------------
crc32                3.45            2.30            1.500       -33.33%
nbody                5.67            2.84            2.000       -50.00%
...
--------------------------------------------------------------------------------

Geometric Mean Speedup: 1.051x
Arithmetic Mean Speedup: 1.068x

Pass IMPROVED performance by 5.12%
```

## Troubleshooting

### Pass not found
```bash
# Build the pass first
cd llvm-pass-skeleton/build
make
cd ../..
./benchmark_pass.sh
```

### Timeouts occurring
```bash
# Increase timeout or reduce iterations
./benchmark_pass.sh --timeout 300 --iterations 2000
```

### Low precision results
```bash
# Increase iterations
./benchmark_pass.sh --iterations 10000
```

### Different machine speeds
The absolute times will vary by machine, but relative speedup (baseline vs pass) 
remains meaningful for comparison on the same machine.

## Tips

1. **Close background applications** before benchmarking for consistency
2. **Run multiple times** to verify reproducibility
3. **Use high iterations** (5000-10000) for publication-quality results
4. **Compare on same machine** - absolute times vary across hardware
5. **Focus on geometric mean** as your primary performance metric

## Help

```bash
./benchmark_pass.sh --help
```
