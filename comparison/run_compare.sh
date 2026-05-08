#!/usr/bin/env bash
set -euo pipefail

# This script runs the two benchmark executables under /usr/bin/time
# and saves the full output (stdout + stderr) to a timestamped file.

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
OUT_DIR="$SCRIPT_DIR/results"

mkdir -p "$OUT_DIR"
TS=$(date +"%Y%m%d_%H%M%S")
OUT_FILE="$OUT_DIR/compare_${TS}.txt"

run_bench() {
  local name=$1
  local exe=$2

  echo "== $name ==" | tee -a "$OUT_FILE"
  (cd "$SCRIPT_DIR" && /usr/bin/time -v dune exec "$exe") 2>&1 | tee -a "$OUT_FILE"
  echo "" | tee -a "$OUT_FILE"
}

run_bench "functional" "./bench_functional.exe"
run_bench "imperative" "./bench_imperative.exe"

echo "Saved results to $OUT_FILE"
