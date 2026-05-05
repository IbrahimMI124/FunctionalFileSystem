(* fs.ml — imperative style
   Key differences from the functional version:
   - Nodes are mutable records with a Hashtbl for child entries.
   - The filesystem root is held in a mutable ref inside the opaque type t.
   - Operations mutate/copy nodes in-place rather than rebuilding paths.
   - "Snapshot" semantics (needed by History) are achieved by deep-copying
     the entire tree; this is the imperative equivalent of structural sharing.
   - Loops replace recursive map traversal where possible.
*)

(* ------------------------------------------------------------------ *)
(*  Internal representation                                             *)
(* ------------------------------------------------------------------ *)

type metadata = {
  mutable created  : int;
  mutable modified : int;
}

type file_node = {
  meta    : metadata;
  mutable content : string;
} [@@warning "-69"]

type dir_node = {
  meta    : metadata;
  entries : (string, fs_node) Hashtbl.t;   (* mutable by Hashtbl design *)
}

and fs_node =
  | File of file_node
  | Dir  of dir_node

(* The public type t wraps a mutable reference to the root node.
   This lets us return a new t from each operation (value-level copy)
   while still being able to mutate things inside when needed. *)
type t = { mutable root : fs_node } [@@warning "-69"]

(* ------------------------------------------------------------------ *)
(*  Helpers                                                             *)
(* ------------------------------------------------------------------ *)

let default_meta () : metadata = { created = 0; modified = 0 }

let new_dir () : dir_node =
  { meta = default_meta (); entries = Hashtbl.create 8 }

let make_empty_dir () : fs_node = Dir (new_dir ())

(* Deep-copy a node tree so that mutations to the copy don't affect
   the original (giving us persistent-snapshot semantics imperatively). *)
let rec deep_copy_node (node : fs_node) : fs_node =
  match node with
  | File f ->
      File { meta = { created = f.meta.created; modified = f.meta.modified };
             content = f.content }
  | Dir d ->
      let d' = new_dir () in
      d'.meta.created  <- d.meta.created;
      d'.meta.modified <- d.meta.modified;
      Hashtbl.iter (fun name child ->
        Hashtbl.replace d'.entries name (deep_copy_node child)
      ) d.entries;
      Dir d'

(* Deep-copy the whole filesystem, returning a fresh t. *)
let deep_copy (fs : t) : t = { root = deep_copy_node fs.root }

(* Assert that a node is a directory and return its dir_node. *)
let as_dir (node : fs_node) : dir_node =
  match node with
  | Dir d  -> d
  | File _ -> failwith "expected directory"

(* Split the last component off a path (mirrors functional split_last). *)
let split_last (path : string list) : string list * string =
  match List.rev path with
  | []                    -> failwith "empty path"
  | last :: rev_prefix -> (List.rev rev_prefix, last)

(* Walk down `node` following `path`, returning the final node. *)
let rec find_node_inner (node : fs_node) (path : string list) : fs_node option =
  match path with
  | [] -> Some node
  | name :: rest ->
      (match node with
       | File _ -> None
       | Dir d  ->
           match Hashtbl.find_opt d.entries name with
           | None       -> None
           | Some child -> find_node_inner child rest)

(* ------------------------------------------------------------------ *)
(*  Public API                                                          *)
(* ------------------------------------------------------------------ *)

let empty : t = { root = Dir (new_dir ()) }

(* mkdir — walk/create intermediate dirs, confirm leaf is a dir. *)
let mkdir (fs : t) (path : string list) : t =
  let fs' = deep_copy fs in
  (* Iterative descent using a mutable cursor. *)
  let cursor = ref fs'.root in
  let remaining = ref path in
  while !remaining <> [] do
    let name = List.hd !remaining in
    remaining := List.tl !remaining;
    let d = as_dir !cursor in
    (match Hashtbl.find_opt d.entries name with
     | Some (Dir _ as child) -> cursor := child
     | Some (File _) ->
         (* path is a file — caller error *)
         failwith "mkdir: path is a file"
     | None ->
         let new_child = make_empty_dir () in
         Hashtbl.replace d.entries name new_child;
         cursor := new_child)
  done;
  (* cursor now points at the leaf — must be a directory (it is, by construction) *)
  fs'

(* touch — create or overwrite a file at path. *)
let touch (fs : t) (path : string list) (content : string) : t =
  let fs' = deep_copy fs in
  let dir_path, file_name = split_last path in
  (* Navigate to the parent directory. *)
  let cursor = ref fs'.root in
  List.iter (fun name ->
    let d = as_dir !cursor in
    (match Hashtbl.find_opt d.entries name with
     | Some (Dir _ as child) -> cursor := child
     | Some (File _) -> failwith "touch: intermediate path is a file"
     | None ->
         let new_child = make_empty_dir () in
         Hashtbl.replace d.entries name new_child;
         cursor := new_child)
  ) dir_path;
  let parent_d = as_dir !cursor in
  (* Reject touching where a directory already exists. *)
  (match Hashtbl.find_opt parent_d.entries file_name with
   | Some (Dir _) -> failwith "touch: target is a directory"
   | _ -> ());
  let new_file =
    File { meta = default_meta (); content }
  in
  Hashtbl.replace parent_d.entries file_name new_file;
  fs'

(* read — returns Some content if path points to a file, None otherwise. *)
let read (fs : t) (path : string list) : string option =
  match find_node_inner fs.root path with
  | Some (File f) -> Some f.content
  | _             -> None

(* delete — remove a named node from its parent directory. *)
let delete (fs : t) (path : string list) : t =
  let fs' = deep_copy fs in
  let dir_path, name = split_last path in
  let cursor = ref fs'.root in
  List.iter (fun seg ->
    let d = as_dir !cursor in
    (match Hashtbl.find_opt d.entries seg with
     | Some child -> cursor := child
     | None       -> failwith "delete: path not found")
  ) dir_path;
  let parent_d = as_dir !cursor in
  (match Hashtbl.find_opt parent_d.entries name with
   | None   -> failwith "delete: path not found"
   | Some _ -> Hashtbl.remove parent_d.entries name);
  fs'

(* ls — list names in a directory, sorted alphabetically. *)
let ls (fs : t) (path : string list) : string list =
  match find_node_inner fs.root path with
  | Some (Dir d) ->
      let names = ref [] in
      Hashtbl.iter (fun name _ -> names := name :: !names) d.entries;
      List.sort String.compare !names
  | Some (File _) -> failwith "ls: not a directory"
  | None          -> failwith "ls: path not found"

(* mv — copy node from src to dst, then remove src. *)
let mv (fs : t) (src : string list) (dst : string list) : t =
  (* Find the source node in the current tree. *)
  let src_node =
    match find_node_inner fs.root src with
    | None   -> failwith "mv: source not found"
    | Some n -> n
  in
  (* Work on a deep copy so src/dst manipulations don't interfere. *)
  let fs' = deep_copy fs in
  (* Remove source. *)
  let src_dir_path, src_name = split_last src in
  let cursor = ref fs'.root in
  List.iter (fun seg ->
    let d = as_dir !cursor in
    cursor := Hashtbl.find d.entries seg
  ) src_dir_path;
  let src_parent = as_dir !cursor in
  Hashtbl.remove src_parent.entries src_name;
  (* Insert at destination. *)
  let dst_dir_path, dst_name = split_last dst in
  let cursor2 = ref fs'.root in
  List.iter (fun seg ->
    let d = as_dir !cursor2 in
    (match Hashtbl.find_opt d.entries seg with
     | Some (Dir _ as child) -> cursor2 := child
     | Some (File _) -> failwith "mv: intermediate path is a file"
     | None ->
         let new_child = make_empty_dir () in
         Hashtbl.replace d.entries seg new_child;
         cursor2 := new_child)
  ) dst_dir_path;
  let dst_parent = as_dir !cursor2 in
  if Hashtbl.mem dst_parent.entries dst_name then
    failwith "mv: target exists";
  (* Use a deep copy of the original src_node so history stays clean. *)
  Hashtbl.replace dst_parent.entries dst_name (deep_copy_node src_node);
  fs'

(* cp — like mv but does not remove the source. *)
let cp (fs : t) (src : string list) (dst : string list) : t =
  let src_node =
    match find_node_inner fs.root src with
    | None   -> failwith "cp: source not found"
    | Some n -> n
  in
  let fs' = deep_copy fs in
  let dst_dir_path, dst_name = split_last dst in
  let cursor = ref fs'.root in
  List.iter (fun seg ->
    let d = as_dir !cursor in
    (match Hashtbl.find_opt d.entries seg with
     | Some (Dir _ as child) -> cursor := child
     | Some (File _) -> failwith "cp: intermediate path is a file"
     | None ->
         let new_child = make_empty_dir () in
         Hashtbl.replace d.entries seg new_child;
         cursor := new_child)
  ) dst_dir_path;
  let dst_parent = as_dir !cursor in
  if Hashtbl.mem dst_parent.entries dst_name then
    failwith "cp: target exists";
  Hashtbl.replace dst_parent.entries dst_name (deep_copy_node src_node);
  fs'
