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
opam exec -- dune build               # compile everything
opam exec -- dune test                # run the test suite
opam exec -- dune exec bin/main.exe   # run the full usage demo
```

---

## How to Use (Normal User Guide)

Everything lives in three modules: **`Path`**, **`Fs`**, and **`History`**.
You write your own code in `bin/main.ml` (or add a new executable) and call their functions.

### Step 1 — Parse Paths

```ocaml
(* Turn a Unix path string into a list of segments *)
let p = Path.of_string "/home/user/docs/report.txt"
(* p = ["home"; "user"; "docs"; "report.txt"] *)

(* Turn it back into a string *)
let s = Path.to_string p        (* "/home/user/docs/report.txt" *)
let r = Path.to_string []       (* "/" — the root *)
```

You can also just write path lists directly: `["docs"; "report.txt"]`.

---

### Step 2 — Create Directories and Files

```ocaml
(* Always start from Fs.empty *)
let fs = ref Fs.empty

(* mkdir: creates the directory and any missing parents *)
fs := Fs.mkdir !fs ["home"; "user"; "docs"]

(* touch: create a new file (or overwrite if it already exists) *)
fs := Fs.touch !fs ["home"; "user"; "docs"; "report.txt"] "Hello, world!"
fs := Fs.touch !fs ["home"; "user"; "docs"; "notes.txt"]  "My notes."
```

---

### Step 3 — Read and List

```ocaml
(* read: returns Some "content" for a file, or None for missing/directory *)
match Fs.read !fs ["home"; "user"; "docs"; "report.txt"] with
| Some content -> print_endline content   (* "Hello, world!" *)
| None         -> print_endline "not found"

(* ls: lists entries in a directory, always sorted alphabetically *)
let entries = Fs.ls !fs ["home"; "user"; "docs"]
(* entries = ["notes.txt"; "report.txt"] *)
```

---

### Step 4 — Copy, Move, Delete

```ocaml
(* cp: copies a file or whole directory subtree; source stays *)
fs := Fs.cp !fs ["home"; "user"; "docs"; "report.txt"]
                ["home"; "user"; "docs"; "report_backup.txt"]

(* mv: moves a node; source is removed *)
fs := Fs.mv !fs ["home"; "user"; "docs"; "notes.txt"]
                ["home"; "user"; "notes_archive.txt"]

(* delete: removes a file or directory *)
fs := Fs.delete !fs ["home"; "user"; "docs"; "report_backup.txt"]
```

---

### Step 5 — Snapshots (Old Values Stay Safe)

Every operation returns a **brand-new snapshot**. Storing the old value in a
separate variable gives you a free "undo" — the old snapshot is unaffected.

```ocaml
let snap1 = Fs.touch Fs.empty ["file.txt"] "v1"
let snap2 = Fs.touch snap1    ["file.txt"] "v2"   (* snap1 still has "v1" *)
let snap3 = Fs.delete snap2   ["file.txt"]         (* snap2 still has "v2" *)

Fs.read snap1 ["file.txt"]   (* Some "v1" *)
Fs.read snap2 ["file.txt"]   (* Some "v2" *)
Fs.read snap3 ["file.txt"]   (* None      *)
```

---

### Step 6 — History (Commits and Checkout)

Use `History` when you want named, numbered snapshots you can jump between —
like a very small Git.

```ocaml
(* Wrap any filesystem in a repo *)
let repo = ref (History.init Fs.empty)

(* Make changes, then commit *)
let fs1 = Fs.mkdir Fs.empty ["projects"]
repo := History.commit { !repo with working = fs1 } "create /projects"

let fs2 = Fs.touch (History.latest !repo) ["projects"; "todo.txt"] "Buy milk"
repo := History.commit { !repo with working = fs2 } "add todo.txt"

(* See what's in the working filesystem right now *)
Fs.read (History.latest !repo) ["projects"; "todo.txt"]   (* Some "Buy milk" *)

(* Print the commit log (newest first) *)
List.iter (fun (c : History.commit) ->
  Printf.printf "[%d] %s\n" c.id c.message
) (History.log !repo)
(* [2] add todo.txt
   [1] create /projects
   [0] init              *)

(* Go back to an earlier commit by ID *)
let old = History.checkout !repo 1
Fs.read (History.latest old) ["projects"; "todo.txt"]   (* None — file didn't exist yet *)

(* !repo itself is unaffected — checkout does NOT mutate the original *)
Fs.read (History.latest !repo) ["projects"; "todo.txt"]  (* Some "Buy milk" *)
```

---

### Running Your Code

Edit `bin/main.ml` with your own calls, then:

```bash
opam exec -- dune exec bin/main.exe
```

The file `bin/main.ml` already contains a full working demo of every operation above.

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
