#!/usr/bin/env python3
"""GĐ6 — tổng hợp mean/median/p95 (ms) từ output thô của measure-latency.sh.
Usage: python aggregate.py <label> <file1> [file2 ...]
In ra 1 dòng CSV: label,n,mean_ms,median_ms,p95_ms,min_ms,max_ms
"""
import sys
import statistics

def p95(data):
    s = sorted(data)
    k = max(0, min(len(s) - 1, round(0.95 * (len(s) - 1))))
    return s[k]

def main():
    label = sys.argv[1]
    values_ms = []
    for path in sys.argv[2:]:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if line:
                    values_ms.append(float(line) * 1000.0)
    n = len(values_ms)
    mean_ms = statistics.mean(values_ms)
    median_ms = statistics.median(values_ms)
    p95_ms = p95(values_ms)
    print(f"{label},{n},{mean_ms:.2f},{median_ms:.2f},{p95_ms:.2f},{min(values_ms):.2f},{max(values_ms):.2f}")

if __name__ == "__main__":
    main()
