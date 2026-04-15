module StringMap = Map.Make (String)

type metadata = {
  created : int;
  modified : int;
}

type file = {
  meta : metadata;
  content : string;
}

type dir = {
  meta : metadata;
  entries : fs_node StringMap.t;
}

and fs_node =
  | File of file
  | Dir of dir

type t = fs_node

let default_meta : metadata = { created = 0; modified = 0 }

let empty_dir : dir = { meta = default_meta; entries = StringMap.empty }

let empty : t = Dir empty_dir

let as_dir (node : fs_node) : dir =
  match node with
  | Dir d -> d
  | File _ -> failwith "expected directory"

let split_last (path : string list) : string list * string =
  match List.rev path with
  | [] -> failwith "empty path"
  | last :: rev_prefix -> (List.rev rev_prefix, last)

(* update is the core persistent 'edit' primitive.
   It walks the directory path, creating missing intermediate directories,
   applies [f] at the target node, then rebuilds only the directories along
   the path (structural sharing via Map updates).
*)
let rec update (node : fs_node) (path : string list) (f : fs_node -> fs_node) : fs_node =
  match path with
  | [] -> f node
  | name :: rest ->
      let d = as_dir node in
      let _ = d.meta.created + d.meta.modified in
      let child =
        match StringMap.find_opt name d.entries with
        | Some n -> n
        | None -> Dir empty_dir
      in
      let child' = update child rest f in
      Dir { d with entries = StringMap.add name child' d.entries }

let mkdir (fs : t) (path : string list) : t =
  update fs path (fun node ->
      match node with
      | Dir _ -> node
      | File _ -> failwith "mkdir: path is a file")

let touch (fs : t) (path : string list) (content : string) : t =
  let dir_path, file_name = split_last path in
  update fs dir_path (fun node ->
      let d = as_dir node in
      (match StringMap.find_opt file_name d.entries with
      | Some (Dir _) -> failwith "touch: target is a directory"
      | _ -> ());
      let file = { meta = default_meta; content } in
      Dir { d with entries = StringMap.add file_name (File file) d.entries })

let rec find_node (node : fs_node) (path : string list) : fs_node option =
  match path with
  | [] -> Some node
  | name :: rest ->
      (match node with
      | File _ -> None
      | Dir d ->
          (match StringMap.find_opt name d.entries with
          | None -> None
          | Some child -> find_node child rest))

let read (fs : t) (path : string list) : string option =
  match find_node fs path with
  | Some (File f) ->
      let _ = f.meta.created + f.meta.modified in
      Some f.content
  | _ -> None
