(* history.ml — imperative style
   Key differences from the functional version:
   - history is a mutable record: commits stored in a Hashtbl,
     head and next_id held in mutable int fields.
   - Each operation that returns a new repo COPIES the history record
     so that mutable mutations (head, next_id) don't alias across repos.
     The commit Hashtbl is shared (it is append-only and commits are
     immutable), which is safe.
   - log walks the parent chain with a while loop instead of recursion.
   All external types and function signatures match the functional version.
*)

(* ------------------------------------------------------------------ *)
(*  Public types (must match history.mli)                               *)
(* ------------------------------------------------------------------ *)

type snapshot_id = int

type commit = {
  id      : snapshot_id;
  parent  : snapshot_id option;
  fs      : Fs.t;
  message : string;
  time    : int;
}

(* history is kept opaque in the .mli; internally it is mutable. *)
type history = {
  mutable head    : snapshot_id;
  commits         : (snapshot_id, commit) Hashtbl.t;   (* shared, append-only *)
  mutable next_id : int;
}

type repo = {
  working : Fs.t;
  history : history;
}

(* ------------------------------------------------------------------ *)
(*  Internal helpers                                                    *)
(* ------------------------------------------------------------------ *)

(* Shallow-copy a history record so that mutations to head/next_id on
   the copy don't affect the original (or any other copy).
   The commits table is intentionally shared: it is append-only and
   all stored commits are immutable records. *)
let copy_history (h : history) : history =
  { head    = h.head;
    commits = h.commits;          (* shared reference — safe, append-only *)
    next_id = h.next_id }

(* ------------------------------------------------------------------ *)
(*  Operations                                                          *)
(* ------------------------------------------------------------------ *)

(* init — create a repository with a single initial commit. *)
let init (fs : Fs.t) : repo =
  let c0 = { id = 0; parent = None; fs; message = "init"; time = 0 } in
  let tbl = Hashtbl.create 16 in
  Hashtbl.add tbl 0 c0;
  let h = { head = 0; commits = tbl; next_id = 1 } in
  { working = fs; history = h }

(* commit — record a new snapshot and advance HEAD imperatively.
   Returns a new repo with an independent history copy so the
   caller's original repo is not affected. *)
let commit (r : repo) (message : string) : repo =
  let h  = copy_history r.history in        (* independent copy *)
  let id = h.next_id in
  let c  = { id;
              parent  = Some h.head;
              fs      = r.working;
              message;
              time    = 0 } in
  Hashtbl.replace h.commits id c;           (* mutate the copy *)
  h.head    <- id;
  h.next_id <- id + 1;
  { working = r.working; history = h }

(* checkout — set HEAD to an existing commit and restore its fs.
   Returns a new repo with an independent history copy. *)
let checkout (r : repo) (id : snapshot_id) : repo =
  match Hashtbl.find_opt r.history.commits id with
  | None   -> failwith "checkout: commit not found"
  | Some c ->
      let h = copy_history r.history in
      h.head <- id;
      { working = c.fs; history = h }

(* latest — return the working filesystem snapshot. *)
let latest (r : repo) : Fs.t = r.working

(* log — walk the parent chain from HEAD using a while loop.
         Walking HEAD (newest) -> root (oldest) while prepending
         gives oldest-first in the accumulator; List.rev converts
         to newest-first to match the functional version ([2;1;0]). *)
let log (r : repo) : commit list =
  let result  = ref [] in
  let current = ref (Some r.history.head) in
  while !current <> None do
    let cid = Option.get !current in
    (match Hashtbl.find_opt r.history.commits cid with
     | None   -> current := None
     | Some c ->
         result  := c :: !result;    (* prepend: oldest-first accumulation *)
         current := c.parent)
  done;
  (* Accumulated oldest-first; reverse to get newest-first. *)
  List.rev !result
