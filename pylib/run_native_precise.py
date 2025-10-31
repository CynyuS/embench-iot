#!/usr/bin/env python3

# Python module to run programs natively with precise timing.

# Based on run_native.py with improved timing precision

"""
Embench module to run benchmark programs natively with precise timing.

This version runs benchmarks multiple times and uses microsecond precision.
"""

__all__ = [
    'get_target_args',
    'build_benchmark_cmd',
    'decode_results',
]

import argparse
import re

from embench_core import log


def get_target_args(remnant):
    """Parse left over arguments"""
    parser = argparse.ArgumentParser(description='Get target specific args')
    
    parser.add_argument(
        '--iterations',
        type=int,
        default=100,
        help='Number of iterations to run each benchmark (default: 100)'
    )

    return parser.parse_args(remnant)


def build_benchmark_cmd(bench, args):
    """Construct the command to run the benchmark multiple times with precise timing.
       "args" is a namespace with target specific arguments"""
    
    iterations = args.iterations if hasattr(args, 'iterations') else 100
    
    # Use Python's time.perf_counter() for microsecond precision
    # Run the benchmark multiple times and report average time
    cmd = f'''python3 -c "
    import subprocess
    import time
    iterations = {iterations}
    total_time = 0
    for _ in range(iterations):
        start = time.perf_counter()
        result = subprocess.run(['./{bench}'], capture_output=True)
        end = time.perf_counter()
        if result.returncode != 0:
            print(f'RET={{result.returncode}}')
            exit(1)
        total_time += (end - start)

    avg_time = total_time / iterations
    print(f'TIME={{avg_time:.9f}}')
    print('RET=0')
    "'''
    
    return ['sh', '-c', cmd]


def decode_results(stdout_str, stderr_str):
    """Extract the results from the output string of the run. Return the
       elapsed time in milliseconds or zero if the run failed."""
    
    # Match "RET=rc"
    rcstr = re.search(r'^RET=(\d+)', stdout_str, re.S | re.M)
    if not rcstr:
        log.debug('Warning: Failed to find return code')
        return 0.0
    
    rc = int(rcstr.group(1))
    if rc != 0:
        log.debug(f'Warning: Benchmark returned non-zero exit code: {rc}')
        return 0.0

    # Match "TIME=s.sssssssss" (seconds with nanosecond precision)
    time_match = re.search(r'^TIME=([\d.]+)', stdout_str, re.S | re.M)
    if time_match:
        seconds = float(time_match.group(1))
        # For fast native execution, report in microseconds for better precision
        # Convert to milliseconds: * 1000, but keep fractional precision
        ms_elapsed = seconds * 1000.0
        # Return value cannot be zero (will be interpreted as error)
        return max(float(ms_elapsed), 0.0001)

    # We must have failed to find a time
    log.debug('Warning: Failed to find timing')
    return 0.0
