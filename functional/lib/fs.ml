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

let delete (fs : t) (path : string list) : t =
  let dir_path, name = split_last path in
  update fs dir_path (fun node ->
      let d = as_dir node in
      match StringMap.find_opt name d.entries with
      | None -> failwith "delete: path not found"
      | Some _ -> Dir { d with entries = StringMap.remove name d.entries })

let ls (fs : t) (path : string list) : string list =
  match find_node fs path with
  | Some (Dir d) ->
      StringMap.bindings d.entries |> List.map (fun (name, _) -> name)
  | Some (File _) -> failwith "ls: not a directory"
  | None -> failwith "ls: path not found"

let mv (fs : t) (src : string list) (dst : string list) : t =
  let src_node =
    match find_node fs src with
    | None -> failwith "mv: source not found"
    | Some n -> n
  in
  let fs' = delete fs src in
  let dir_path, name = split_last dst in
  update fs' dir_path (fun dir_node ->
      let d = as_dir dir_node in
      if StringMap.mem name d.entries then failwith "mv: target exists";
      Dir { d with entries = StringMap.add name src_node d.entries })

let cp (fs : t) (src : string list) (dst : string list) : t =
  let src_node =
    match find_node fs src with
    | None -> failwith "cp: source not found"
    | Some n -> n
  in
  let dir_path, name = split_last dst in
  update fs dir_path (fun dir_node ->
      let d = as_dir dir_node in
      if StringMap.mem name d.entries then failwith "cp: target exists";
      Dir { d with entries = StringMap.add name src_node d.entries })
