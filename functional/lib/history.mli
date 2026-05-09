type snapshot_id = int

type commit = {
  id : snapshot_id;
  parent : snapshot_id option;
  fs : Fs.t;
  message : string;
  time : int;
}

type history

type repo = {
  working : Fs.t;
  history : history;
}

val init : Fs.t -> repo

val commit : repo -> string -> repo

val checkout : repo -> snapshot_id -> repo

val latest : repo -> Fs.t

val checkout_latest : repo -> repo

val latest_head : repo -> snapshot_id

val log : repo -> commit list
