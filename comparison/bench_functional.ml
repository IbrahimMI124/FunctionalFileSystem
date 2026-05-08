(**********************************************************************)
(* Benchmark driver for the functional filesystem implementation.      *)
(*                                                                    *)
(* Workloads:                                                         *)
(* 1) Single-version throughput: many ops on one live tree.           *)
(* 2) Versioned commit loop: small edits + commits + old reads.        *)
(*                                                                    *)
(* This file is intentionally verbose and heavily commented to make    *)
(* the intent of each step explicit for learning purposes.             *)
(**********************************************************************)

open Printf

(* ------------------------------------------------------------------ *)
(* Timing helpers                                                      *)
(* ------------------------------------------------------------------ *)

(* Run [f], measure wall time in seconds, and print a labeled line. *)
let time label f =
  let t0 = Unix.gettimeofday () in
  let result = f () in
  let t1 = Unix.gettimeofday () in
  printf "%s: %.6f s\n" label (t1 -. t0);
  result

(* Dump a small subset of GC stats so we can compare heap pressure. *)
let print_gc label =
  let s = Gc.stat () in
  printf "%s: live_words=%d heap_words=%d free_words=%d\n"
    label s.Gc.live_words s.Gc.heap_words s.Gc.free_words

(* ------------------------------------------------------------------ *)
(* Small list utilities used to track paths                             *)
(* ------------------------------------------------------------------ *)

(* Pick a random element from a non-empty list. *)
let pick lst =
  match lst with
  | [] -> failwith "pick: empty list"
  | _ -> List.nth lst (Random.int (List.length lst))

(* Replace the last element in a path with [new_name]. *)
let replace_last path new_name =
  let rec go acc = function
    | [] -> failwith "replace_last: empty path"
    | [ _ ] -> List.rev (new_name :: acc)
    | x :: xs -> go (x :: acc) xs
  in
  go [] path

(* Remove the first occurrence of [x] from [lst]. *)
let remove_first x lst =
  let rec go acc = function
    | [] -> List.rev acc
    | y :: ys ->
        if y = x then List.rev_append acc ys
        else go (y :: acc) ys
  in
  go [] lst

(* ------------------------------------------------------------------ *)
(* Workload 1: Single-version throughput                                *)
(* ------------------------------------------------------------------ *)

(* State carried through the throughput workload. *)
type state = {
  fs : Fs.t;
  files : string list list;
  dirs : string list list;
  next_id : int;
}

(* Build a small, deterministic tree to operate on. *)
let build_base () : state =
  let fs_ref = ref Fs.empty in
  let dirs = ref [ [] ] in
  let files = ref [] in
  let dir_count = 20 in
  let sub_count = 5 in
  for i = 1 to dir_count do
    let dir_name = "dir_" ^ string_of_int i in
    fs_ref := Fs.mkdir !fs_ref [ dir_name ];
    dirs := [ dir_name ] :: !dirs;
    for j = 1 to sub_count do
      let sub_name = "sub_" ^ string_of_int j in
      let sub_path = [ dir_name; sub_name ] in
      fs_ref := Fs.mkdir !fs_ref sub_path;
      dirs := sub_path :: !dirs;
      let file_path = sub_path @ [ "file_1.txt" ] in
      fs_ref := Fs.touch !fs_ref file_path "seed";
      files := file_path :: !files
    done
  done;
  { fs = !fs_ref; files = !files; dirs = !dirs; next_id = 0 }

(* Run a fixed mix of operations on a single filesystem value. *)
let run_throughput () : unit =
  let ops = 5000 in
  let state_ref = ref (build_base ()) in
  for i = 1 to ops do
    let s = !state_ref in
    let op = i mod 6 in
    if op = 0 then
      (* mkdir: create a fresh directory under a random existing dir. *)
      let parent = pick s.dirs in
      let name = "new_dir_" ^ string_of_int s.next_id in
      let path = parent @ [ name ] in
      let fs' = Fs.mkdir s.fs path in
      state_ref := { s with fs = fs'; dirs = path :: s.dirs; next_id = s.next_id + 1 }
    else if op = 1 then
      (* touch: overwrite an existing file. *)
      let path = pick s.files in
      let fs' = Fs.touch s.fs path ("v" ^ string_of_int i) in
      state_ref := { s with fs = fs' }
    else if op = 2 then
      (* read: read an existing file. *)
      let path = pick s.files in
      ignore (Fs.read s.fs path);
      state_ref := s
    else if op = 3 then
      (* ls: list a directory. *)
      let path = pick s.dirs in
      ignore (Fs.ls s.fs path);
      state_ref := s
    else if op = 4 then
      (* mv: move a file to a new name in the same directory. *)
      let src = pick s.files in
      let dst = replace_last src ("moved_" ^ string_of_int s.next_id ^ ".txt") in
      let fs' = Fs.mv s.fs src dst in
      let files' = dst :: remove_first src s.files in
      state_ref := { s with fs = fs'; files = files'; next_id = s.next_id + 1 }
    else
      (* cp: copy a file to a new name in the same directory. *)
      let src = pick s.files in
      let dst = replace_last src ("copy_" ^ string_of_int s.next_id ^ ".txt") in
      let fs' = Fs.cp s.fs src dst in
      state_ref := { s with fs = fs'; files = dst :: s.files; next_id = s.next_id + 1 }
  done

(* ------------------------------------------------------------------ *)
(* Workload 2: Versioned commit loop                                    *)
(* ------------------------------------------------------------------ *)

(* Repeated small edits + commits + reads from older snapshots. *)
let run_commit_loop () : unit =
  let commit_count = 300 in
  let fs0 = Fs.mkdir Fs.empty [ "data" ] in
  let repo_ref = ref (History.init fs0) in
  for i = 1 to commit_count do
    let repo = !repo_ref in
    let fs = History.latest repo in
    let file_name = "file_" ^ string_of_int i ^ ".txt" in
    let fs' = Fs.touch fs [ "data"; file_name ] (string_of_int i) in
    let repo' = History.commit { repo with working = fs' } ("c" ^ string_of_int i) in
    if i mod 20 = 0 then (
      let old_id = i / 2 in
      if old_id > 0 then (
        let old_repo = History.checkout repo' old_id in
        let old_file = "file_" ^ string_of_int old_id ^ ".txt" in
        ignore (Fs.read (History.latest old_repo) [ "data"; old_file ])
      )
    );
    repo_ref := repo'
  done

(* ------------------------------------------------------------------ *)
(* Main                                                                 *)
(* ------------------------------------------------------------------ *)

let () =
  (* Fixed seed so runs are repeatable. *)
  Random.init 42;

  print_gc "gc_before";
  time "throughput" run_throughput;
  print_gc "gc_after_throughput";

  time "commit_loop" run_commit_loop;
  print_gc "gc_after_commit_loop";

  printf "done\n"
