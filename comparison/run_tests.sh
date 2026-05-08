#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

run_tests() {
  local name=$1
  local dir=$2

  echo "== $name =="
  (cd "$dir" && dune test)
}

run_tests "functional" "$ROOT_DIR/functional"
run_tests "imperative" "$ROOT_DIR/imperative"
