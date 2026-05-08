# Functional Filesystem (OCaml)

Purely functional, persistent in-memory filesystem with structural sharing.

## Project Layout

```
functional/
├── bin/          # Demo executable
├── lib/          # Core implementation (Fs/Path/History)
└── test/         # Test suite
```

## Modules

- `Path`: path parsing and rendering utilities.
- `Fs`: immutable filesystem operations with persistence.
- `History`: snapshot history and commit log.

## Build, Run, Test (Single Project)

```bash
# From the repo root:
dune build
dune exec functional/bin/main.exe
dune test functional/test
```

## Notes

- The core persistent update primitive is `Fs.update` in `lib/fs.ml`.
- Directory entries use `Map.Make(String)` for structural sharing.
