# FunctionalFileSystem (OCaml)

This repository contains two implementations of an in-memory filesystem:

- Functional: persistent, immutable data structures with structural sharing.
- Imperative: mutable tree with explicit snapshot isolation.

The APIs are aligned, but the imperative version mutates in place and provides
an explicit snapshot function for History commits.

## Project Layout

```
.
├── functional/    # Functional implementation + tests + demo
├── imperative/    # Imperative implementation + tests + demo
├── comparison/    # Benchmarks and comparison script
├── dune-project   # Single top-level dune project
└── README.md
```

### Folder Details

- [functional](functional): Functional implementation (Fs/Path/History), demo, tests.
- [imperative](imperative): Imperative re-implementation with the same API.
- [comparison](comparison): Benchmarks and scripts to compare time and memory.

## Build, Run, Test (Single Project)

```bash
# From the repo root:
dune build

# Run the functional demo
dune exec functional/bin/main.exe

# Run the imperative demo
dune exec imperative/bin/main.exe

# Run all tests (functional + imperative)
dune test

# Run only functional tests
dune test functional/test

# Run only imperative tests
dune test imperative/test
```


## Notes

- The core persistent update primitive is `Fs.update` in [functional/lib/fs.ml](functional/lib/fs.ml).
- Directory entries use `Map.Make(String)` for structural sharing.
