# FunctionalFileSystem (OCaml)

Two implementations of an in-memory virtual filesystem:

- Functional: persistent, immutable data structures with structural sharing.
- Imperative: mutable tree with explicit snapshot isolation.

Both expose the same public API so they can be compared on behavior and style.

## Project Layout

```
.
├── bin/           # Functional demo executable
├── lib/           # Functional implementation (Fs/Path/History)
├── test/          # Functional test suite
├── imperative/    # Imperative re-implementation with same API
├── comparison/    # Scripts to compare time, memory, and tests
├── dune-project   # Workspace metadata (top-level)
└── README.md
```

### Folder Details

- [bin](bin): Top-level demo program for the functional filesystem.
- [lib](lib): Core functional implementation:
	- `fs.ml` / `fs.mli`: filesystem operations and persistence.
	- `path.ml`: path parsing and rendering utilities.
	- `history.ml`: snapshot history and commits.
- [test](test): Functional tests driven by dune.
- [imperative](imperative): Separate dune project with an imperative-style
	implementation. See its own README for design notes and API overview.
- [comparison](comparison): Scripts to compare execution time, memory, and
	correctness between implementations.

## Build, Run, Test (Functional)

```bash
dune build
dune exec ./bin/main.exe
dune test
```

## Build, Run, Test (Imperative)

```bash
cd imperative
dune build
dune exec ./bin/main.exe
dune test
```

## Notes

- The core persistent update primitive is `Fs.update` in [lib/fs.ml](lib/fs.ml).
- Directory entries use `Map.Make(String)` for structural sharing.
