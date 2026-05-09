# Functional Filesystem (OCaml)

A purely functional, persistent in-memory filesystem with structural sharing.
This is the reference implementation the imperative version is compared against.

---

## Project Layout

```
functional/
├── lib/
│   ├── path.ml / path.mli      # Path string utilities
│   ├── fs.ml  / fs.mli         # Core filesystem (persistent tree)
│   └── history.ml / history.mli# Snapshot / commit history
├── bin/
│   └── main.ml                 # Demo entry point
└── test/
    └── fs_test.ml              # Full test suite
```

---

## Modules

### `Path`

Converts between Unix-style path strings and `string list`.

| Function | Signature | Description |
|---|---|---|
| `of_string` | `string -> string list` | Splits on `'/'`, drops empty segments |
| `to_string` | `string list -> string` | Joins with `'/'`; empty list -> `"/"` |

**Functional technique:** uses `String.split_on_char` + list filtering, no mutation.

---

### `Fs`

An immutable, persistent filesystem where every write returns a new snapshot.
Directory entries are stored in an immutable `Map.Make(String)`.

#### Internal Representation

```
fs_node =
  | File { meta; content : string }
  | Dir  { meta; entries : fs_node StringMap.t }

t = fs_node
```

Each update rebuilds only the path you touch and reuses the rest of the tree
(structural sharing).

#### Public API

| Function | Signature | Description |
|---|---|---|
| `empty` | `t` | Fresh empty root directory |
| `mkdir` | `t -> string list -> t` | Creates directory (and intermediates); errors if path hits a file |
| `touch` | `t -> string list -> string -> t` | Creates or overwrites a file |
| `read` | `t -> string list -> string option` | Returns file content, or `None` |
| `delete` | `t -> string list -> t` | Removes a file or directory node |
| `ls` | `t -> string list -> string list` | Lists directory entries |
| `mv` | `t -> string list -> string list -> t` | Moves a node (removes source) |
| `cp` | `t -> string list -> string list -> t` | Copies a node (keeps source) |

#### Functional techniques used

- **Immutable `Map.Make(String)`** for directory entries.
- **Structural sharing**: only the modified path is rebuilt.
- **Pure recursion** for traversal and updates.

---

### `History`

Tracks snapshots of the filesystem as a sequence of commits, analogous to a
simple Git history. Commits store references to immutable `Fs.t` values.

#### Internal Representation

```
history = {
  head    : snapshot_id;
  commits : commit IntMap.t;
  next_id : int;
}

repo = { working : Fs.t; history : history }
```

All fields are immutable; updates create new records.

#### Public API

| Function | Signature | Description |
|---|---|---|
| `init` | `Fs.t -> repo` | Creates repo with a single `"init"` commit |
| `commit` | `repo -> string -> repo` | Records current `working` as a new snapshot |
| `checkout` | `repo -> snapshot_id -> repo` | Restores working fs to a past commit |
| `latest` | `repo -> Fs.t` | Returns the current working filesystem |
| `log` | `repo -> commit list` | Returns commit chain newest-first |

---

## Key Design Decision: Structural Sharing

Every write returns a new snapshot, but only the nodes on the updated path are
recreated. All other subtrees are reused safely because nodes are immutable.
This gives persistent history at low cost.

---

## Build, Run, Test (Single Project)

```bash
# From the repo root:

dune build

dune exec functional/bin/main.exe

dune test functional/test
```
