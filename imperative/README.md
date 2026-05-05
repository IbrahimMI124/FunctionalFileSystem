# Imperative Functional Filesystem (OCaml)

An **imperative-style** re-implementation of the same in-memory filesystem originally written in pure functional OCaml. Both implementations expose **identical public interfaces** so they can be compared directly on correctness and style.

---

## Project Layout

```
imperative/
├── dune-project
├── lib/
│   ├── path.ml / path.mli      # Path string utilities
│   ├── fs.ml  / fs.mli         # Core filesystem (mutable tree)
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
| `to_string` | `string list -> string` | Joins with `'/'`; empty list → `"/"` |

**Imperative technique:** Uses a mutable `Buffer` and a `for` loop over characters instead of `String.split_on_char` + `List.filter`.

---

### `Fs`

An in-memory, tree-structured filesystem. The opaque type `t` wraps a **mutable Hashtbl-based node tree**.

#### Internal Representation

```
fs_node =
  | File  { meta; mutable content : string }
  | Dir   { meta; entries : (string, fs_node) Hashtbl.t }

t = { mutable root : fs_node }
```

Directories store their children in a `Hashtbl` (string → fs_node), mutated in-place. Each public operation **deep-copies the entire tree first**, then mutates the copy — this gives the same snapshot/persistence semantics as the functional version's structural sharing, but imperatively.

#### Public API

| Function | Signature | Description |
|---|---|---|
| `empty` | `t` | Fresh empty root directory |
| `mkdir` | `t -> string list -> t` | Creates directory (and intermediates); errors if path hits a file |
| `touch` | `t -> string list -> string -> t` | Creates or overwrites a file |
| `read` | `t -> string list -> string option` | Returns file content, or `None` |
| `delete` | `t -> string list -> t` | Removes a file or directory node |
| `ls` | `t -> string list -> string list` | Lists directory entries, sorted alphabetically |
| `mv` | `t -> string list -> string list -> t` | Moves a node (removes source) |
| `cp` | `t -> string list -> string list -> t` | Copies a node (keeps source) |

#### Imperative techniques used

- **`Hashtbl.t`** for directory entries (mutable, O(1) average lookup/insert).
- **`ref` cursor** (`let cursor = ref fs'.root`) walked with `List.iter` or `while` loops instead of recursive path descent.
- **`deep_copy_node`** — a recursive deep-copy that clones the entire tree before each mutation, preserving snapshot isolation.
- **Mutable record fields** (`mutable content`, `mutable created/modified`) for in-place updates where appropriate.

---

### `History`

Tracks snapshots of the filesystem as a sequence of commits, analogous to a simple Git history.

#### Internal Representation

```
history = {
  mutable head    : snapshot_id;
  commits         : (snapshot_id, commit) Hashtbl.t;  (* append-only *)
  mutable next_id : int;
}

repo = { working : Fs.t;  history : history }
```

The commit store is a `Hashtbl` keyed by integer ID. `head` and `next_id` are mutable fields advanced imperatively on each commit.

#### Public API

| Function | Signature | Description |
|---|---|---|
| `init` | `Fs.t -> repo` | Creates repo with a single `"init"` commit |
| `commit` | `repo -> string -> repo` | Records current `working` as a new snapshot |
| `checkout` | `repo -> snapshot_id -> repo` | Restores working fs to a past commit |
| `latest` | `repo -> Fs.t` | Returns the current working filesystem |
| `log` | `repo -> commit list` | Returns commit chain newest-first |

#### Imperative techniques used

- **Mutable `head` / `next_id`** fields updated with `<-` instead of rebuilding a record.
- **`Hashtbl.replace`** to insert new commits in-place.
- **`copy_history`** — shallow-copies the history record on every `commit`/`checkout` so that mutations to `head`/`next_id` on one repo don't alias into another. The `commits` table is shared (safe — it is append-only).
- **`while` loop** in `log` replaces the tail-recursive accumulator walk of the functional version.

---

## Key Design Decision: Snapshot Isolation

The functional version gets snapshot isolation *for free* via immutable persistent maps (structural sharing). The imperative version must **explicitly deep-copy** the filesystem tree on every write operation to achieve the same guarantee — earlier `t` values remain valid and unchanged after any subsequent operation.

```
Functional:  let fs2 = Fs.touch fs1 ...   (* fs1 untouched via structural sharing *)
Imperative:  fs2 := Fs.touch !fs1 ...     (* deep_copy inside touch protects !fs1 *)
```

---

## Building & Running

```bash
# From the imperative/ directory:
opam exec -- dune build       # compile everything
opam exec -- dune test        # run the test suite (all assertions must pass)
opam exec -- dune exec bin/main.exe   # run the demo
```

Expected output of the demo:
```
Hello from an imperative FS!
```

---

## Functional vs. Imperative: Side-by-Side

| Aspect | Functional (`lib/`) | Imperative (`imperative/lib/`) |
|---|---|---|
| Directory store | `Map.Make(String)` | `Hashtbl.t` |
| Tree updates | Rebuild path (structural sharing) | `deep_copy` + in-place mutation |
| Path traversal | Recursive `update` / `find_node` | `ref cursor` + `List.iter` / `while` |
| State threading | `let fs2 = f fs1` | `fs := f !fs` |
| History store | `IntMap` (immutable) | `Hashtbl` (mutable) |
| HEAD tracking | Rebuilt record field | `mutable head <- id` |
| Log walk | Tail-recursive accumulator | `while` loop + `ref` list |
| Aliasing risk | None (values are immutable) | Prevented via `copy_history` |
| Public interface | Identical | Identical |
