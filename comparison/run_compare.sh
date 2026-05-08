#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_DIR="$SCRIPT_DIR/results"

mkdir -p "$OUT_DIR"
TS=$(date +"%Y%m%d_%H%M%S")
OUT_FILE="$OUT_DIR/compare_${TS}.txt"

run_compare() {
  local name=$1
  local dir=$2

  echo "== $name ==" | tee -a "$OUT_FILE"
  (cd "$dir" && /usr/bin/time -v dune exec ./bin/main.exe) 2>&1 | tee -a "$OUT_FILE"
  echo "" | tee -a "$OUT_FILE"
}

run_compare "functional" "$ROOT_DIR/functional"
run_compare "imperative" "$ROOT_DIR/imperative"

echo "Saved results to $OUT_FILE"
