#!/usr/bin/env python3
import json
import sys
from functools import reduce
import operator

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
    print("BENCHMARK COMPARISON: Baseline (-O0) vs With Pass (-O0 + pass)")
    print("=" * 80)
    print()
    print(f"{'Benchmark':<20} {'Baseline (ms)':<15} {'With Pass (ms)':<15} {'Speedup':<10} {'% Change'}")
    print("-" * 80)
    
    # Handle both possible JSON structures
    baseline_results = baseline.get('benchmarks', {})
    if not baseline_results:
        baseline_results = baseline.get('speed results', {}).get('detailed speed results', {})
    
    pass_results = with_pass.get('benchmarks', {})
    if not pass_results:
        pass_results = with_pass.get('speed results', {}).get('detailed speed results', {})
    
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
            print(f"Pass IMPROVED performance by {(geomean - 1.0) * 100:.2f}%")
        elif geomean < 1.0:
            print(f"Pass DEGRADED performance by {(1.0 - geomean) * 100:.2f}%")
        else:
            print("Pass had NO EFFECT on performance")
    else:
        print("\nNo valid benchmark comparisons found!")
    
    print()
    print("Raw results saved in:")
    print(f"  Baseline: {baseline_file}")
    print(f"  With Pass: {pass_file}")
    print()

if __name__ == '__main__':
    main()
