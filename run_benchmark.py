"""
Benchmark script for CoreMark CPU performance.

One unit of work: one complete CoreMark run (the compiled coremark binary).
Primary metric : CoreMark score (iterations/sec, higher is better).
Secondary      : self-reported run time and subprocess wall time.
"""

import json
import math
import os
import re
import subprocess
import sys
import timeit

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
NUMBER = 1   # coremark executions per trial
REPEAT = 5   # number of trials

# Performance-run seed parameters (matches Makefile PARAM1 / run1.log target)
_COREMARK_ARGS = ["0x0", "0x0", "0x66", "0", "7", "1", "2000"]

# ---------------------------------------------------------------------------
# Locate binary (Windows .exe or plain Linux/WSL binary in same directory)
# ---------------------------------------------------------------------------
_here = os.path.dirname(os.path.abspath(__file__))
_exe = os.path.join(_here, "coremark.exe")
if not os.path.exists(_exe):
    _exe = os.path.join(_here, "coremark")
if not os.path.exists(_exe):
    print(
        "Error: coremark binary not found.\n"
        "Run one of:\n"
        "  make compile PORT_DIR=posix NO_LIBRT=1   (Windows, scoop gcc)\n"
        "  make compile PORT_DIR=linux               (WSL / Linux)",
        file=sys.stderr,
    )
    sys.exit(1)

_CMD = [_exe] + _COREMARK_ARGS

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def _mean(vals):
    return sum(vals) / len(vals)


def _stdev(vals):
    if len(vals) < 2:
        return 0.0
    m = _mean(vals)
    return math.sqrt(sum((x - m) ** 2 for x in vals) / (len(vals) - 1))


# ---------------------------------------------------------------------------
# Setup — verify the binary produces correct output (excluded from timing)
# ---------------------------------------------------------------------------
print(f"Verifying coremark binary: {_exe}")
_probe = subprocess.run(_CMD, capture_output=True, text=True)
if "Correct operation validated" not in _probe.stdout:
    print("Error: coremark did not validate correctly.", file=sys.stderr)
    print(_probe.stdout[-500:], file=sys.stderr)
    sys.exit(1)
print("Validation OK.\n")

# ---------------------------------------------------------------------------
# Timed loop — collect self-reported scores alongside wall-clock times
# ---------------------------------------------------------------------------
_scores: list[float] = []       # CoreMark iterations/sec (self-reported)
_self_times: list[float] = []   # binary's own "Total time (secs)"


def _run_once():
    result = subprocess.run(_CMD, capture_output=True, text=True, check=True)

    score_m = re.search(r"Iterations/Sec\s*:\s*([\d.]+)", result.stdout)
    time_m = re.search(r"Total time \(secs\)\s*:\s*([\d.]+)", result.stdout)

    if not score_m:
        raise RuntimeError(
            f"Could not parse CoreMark score.\nOutput:\n{result.stdout}"
        )

    _scores.append(float(score_m.group(1)))
    if time_m:
        _self_times.append(float(time_m.group(1)))


print(
    f"Running {REPEAT} trial(s) x {NUMBER} execution(s) each "
    f"(each run ~10-20 s)...\n"
)

_wall_times = timeit.repeat(_run_once, number=NUMBER, repeat=REPEAT)

# ---------------------------------------------------------------------------
# Statistics
# ---------------------------------------------------------------------------
score_mean = _mean(_scores)
score_std = _stdev(_scores)

wall_mean = _mean(_wall_times)
wall_std = _stdev(_wall_times)

self_mean = _mean(_self_times) if _self_times else None
self_std = _stdev(_self_times) if len(_self_times) > 1 else 0.0

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------
results: dict = {
    "benchmark_config": {
        "number": NUMBER,
        "repeat": REPEAT,
        "binary": _exe,
        "args": _COREMARK_ARGS,
    },
    "coremark_score": {
        "unit": "iterations/sec",
        "mean": round(score_mean, 3),
        "std": round(score_std, 3),
    },
    "wall_time_per_trial": {
        "unit": "seconds",
        "mean": round(wall_mean, 3),
        "std": round(wall_std, 3),
    },
}

if self_mean is not None:
    results["self_reported_time"] = {
        "unit": "seconds",
        "mean": round(self_mean, 3),
        "std": round(self_std, 3),
    }

sep = "=" * 52
print(sep)
print(f"  number={NUMBER}  repeat={REPEAT}")
print(sep)
print(f"  CoreMark score  : {score_mean:>10.2f} +/- {score_std:.2f}  iterations/sec")
print(f"  Wall time/trial : {wall_mean:>10.3f} +/- {wall_std:.3f}  s")
if self_mean is not None:
    print(f"  Self-reported t : {self_mean:>10.3f} +/- {self_std:.3f}  s")
print(sep)

_out = os.path.join(_here, "artemis_results.json")
with open(_out, "w") as _f:
    json.dump(results, _f, indent=2)
print(f"\nResults written to {_out}")
