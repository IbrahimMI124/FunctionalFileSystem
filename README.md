# Functional (Persistent) Virtual File System — OCaml

Minimal prototype for a purely functional, immutable virtual file system.

## Build

```bash
dune build
```

## Run

```bash
dune exec ./bin/main.exe
```

## Test

```bash
dune test
```

## Notes

- The core persistent update primitive is `Fs.update` in `lib/fs.ml`.
- Directory entries use `Map.Make(String)` for structural sharing.
