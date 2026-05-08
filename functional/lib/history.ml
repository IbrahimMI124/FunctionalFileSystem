module IntMap = Map.Make (Int)

type snapshot_id = int

type commit = {
  id : snapshot_id;
  parent : snapshot_id option;
  fs : Fs.t;
  message : string;
  time : int;
}

type history = {
  head : snapshot_id;
  commits : commit IntMap.t;
  next_id : int;
}

type repo = {
  working : Fs.t;
  history : history;
}

let init (fs : Fs.t) : repo =
  let c0 = { id = 0; parent = None; fs; message = "init"; time = 0 } in
  let history = { head = 0; commits = IntMap.add 0 c0 IntMap.empty; next_id = 1 } in
  { working = fs; history }

let commit (r : repo) (message : string) : repo =
  let id = r.history.next_id in
  let c = { id; parent = Some r.history.head; fs = r.working; message; time = 0 } in
  let commits = IntMap.add id c r.history.commits in
  let history = { head = id; commits; next_id = id + 1 } in
  { r with history }

let checkout (r : repo) (id : snapshot_id) : repo =
  match IntMap.find_opt id r.history.commits with
  | None -> failwith "checkout: commit not found"
  | Some c -> { working = c.fs; history = { r.history with head = id } }

let latest (r : repo) : Fs.t =
  r.working

let log (r : repo) : commit list =
  let rec walk acc current_id =
    match IntMap.find_opt current_id r.history.commits with
    | None -> List.rev acc
    | Some c ->
        let acc' = c :: acc in
        (match c.parent with
        | None -> List.rev acc'
        | Some p -> walk acc' p)
  in
  walk [] r.history.head
