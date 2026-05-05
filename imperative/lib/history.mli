(* history.mli — identical public interface to the functional version. *)

type snapshot_id = int

type commit = {
  id      : snapshot_id;
  parent  : snapshot_id option;
  fs      : Fs.t;
  message : string;
  time    : int;
}

type history

type repo = {
  working : Fs.t;
  history : history;
}

val init     : Fs.t -> repo
val commit   : repo -> string -> repo
val checkout : repo -> snapshot_id -> repo
val latest   : repo -> Fs.t
val log      : repo -> commit list
