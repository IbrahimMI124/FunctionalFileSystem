# Comparison (Functional vs Imperative)

This folder contains scripts to compare the two implementations on:

- Execution time
- Memory usage
- Correctness via tests

## Scripts

- `run_tests.sh`: runs the dune test suite in both projects.
- `run_compare.sh`: runs both demo executables under `/usr/bin/time -v` and
  saves output to `comparison/results/`.

## Usage

```bash
# From the repo root:
./comparison/run_tests.sh
./comparison/run_compare.sh
```

## Notes

- The comparison uses each project's `bin/main.exe` demo as the workload.
- For more stable timing, run comparisons multiple times and compare the
  `Elapsed (wall clock) time` and `Maximum resident set size` values.
