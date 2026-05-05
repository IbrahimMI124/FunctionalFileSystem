(* main.ml — full usage demo for the imperative filesystem
   Run with: opam exec -- dune exec bin/main.exe
*)

(* ------------------------------------------------------------------ *)
(* Helper: print a section header                                      *)
(* ------------------------------------------------------------------ *)
let section title =
  Printf.printf "\n=== %s ===\n" title

(* ------------------------------------------------------------------ *)
(* 1. PATH UTILITIES                                                   *)
(* ------------------------------------------------------------------ *)
let () =
  section "Path Utilities";

  let p = Path.of_string "/home/user/docs/report.txt" in
  Printf.printf "of_string \"/home/user/docs/report.txt\" -> [%s]\n"
    (String.concat "; " (List.map (fun s -> "\"" ^ s ^ "\"") p));

  Printf.printf "to_string -> \"%s\"\n" (Path.to_string p);
  Printf.printf "root path: \"%s\"\n"  (Path.to_string [])

(* ------------------------------------------------------------------ *)
(* 2. BASIC FILE OPERATIONS                                            *)
(* ------------------------------------------------------------------ *)
let () =
  section "Basic File Operations";

  (* Start with an empty filesystem *)
  let fs = ref Fs.empty in

  (* mkdir — create nested directories *)
  fs := Fs.mkdir !fs ["home"; "user"; "docs"];
  Printf.printf "mkdir /home/user/docs  -> ok\n";

  (* touch — create files *)
  fs := Fs.touch !fs ["home"; "user"; "docs"; "report.txt"] "My first report.";
  fs := Fs.touch !fs ["home"; "user"; "docs"; "notes.txt"]  "Some notes here.";
  Printf.printf "touch report.txt, notes.txt  -> ok\n";

  (* read — get file content *)
  (match Fs.read !fs ["home"; "user"; "docs"; "report.txt"] with
   | Some c -> Printf.printf "read report.txt  -> \"%s\"\n" c
   | None   -> Printf.printf "read report.txt  -> (not found)\n");

  (* read on a directory returns None *)
  (match Fs.read !fs ["home"; "user"; "docs"] with
   | Some _ -> Printf.printf "read /docs -> (content)\n"
   | None   -> Printf.printf "read /docs (dir) -> None  [expected]\n");

  (* ls — list directory contents (always sorted) *)
  let entries = Fs.ls !fs ["home"; "user"; "docs"] in
  Printf.printf "ls /home/user/docs -> [%s]\n" (String.concat ", " entries);

  (* touch again — overwrite existing file *)
  fs := Fs.touch !fs ["home"; "user"; "docs"; "report.txt"] "Updated report!";
  (match Fs.read !fs ["home"; "user"; "docs"; "report.txt"] with
   | Some c -> Printf.printf "after overwrite  -> \"%s\"\n" c
   | None   -> ())

(* ------------------------------------------------------------------ *)
(* 3. COPY AND MOVE                                                    *)
(* ------------------------------------------------------------------ *)
let () =
  section "Copy and Move";

  let fs = ref (Fs.mkdir Fs.empty ["a"]) in
  fs := Fs.touch !fs ["a"; "file.txt"] "hello";

  (* cp — copies file, source still exists *)
  fs := Fs.cp !fs ["a"; "file.txt"] ["a"; "backup.txt"];
  Printf.printf "cp a/file.txt -> a/backup.txt\n";
  Printf.printf "  original: %s\n"
    (Option.value ~default:"missing" (Fs.read !fs ["a"; "file.txt"]));
  Printf.printf "  copy:     %s\n"
    (Option.value ~default:"missing" (Fs.read !fs ["a"; "backup.txt"]));

  (* mv — moves file, source is gone *)
  fs := Fs.mv !fs ["a"; "file.txt"] ["a"; "renamed.txt"];
  Printf.printf "mv a/file.txt -> a/renamed.txt\n";
  Printf.printf "  old path: %s\n"
    (match Fs.read !fs ["a"; "file.txt"] with None -> "None [gone]" | Some s -> s);
  Printf.printf "  new path: %s\n"
    (Option.value ~default:"missing" (Fs.read !fs ["a"; "renamed.txt"]));

  (* cp can also copy whole directories (subtrees) *)
  let fs2 = ref (Fs.mkdir Fs.empty ["src"; "inner"]) in
  fs2 := Fs.touch !fs2 ["src"; "inner"; "data.txt"] "data";
  fs2 := Fs.cp !fs2 ["src"] ["dst"];
  Printf.printf "cp subtree src/ -> dst/\n";
  Printf.printf "  dst/inner/data.txt: %s\n"
    (Option.value ~default:"missing" (Fs.read !fs2 ["dst"; "inner"; "data.txt"]))

(* ------------------------------------------------------------------ *)
(* 4. DELETE                                                           *)
(* ------------------------------------------------------------------ *)
let () =
  section "Delete";

  let fs = ref (Fs.mkdir Fs.empty ["d"]) in
  fs := Fs.touch !fs ["d"; "tmp.txt"] "throwaway";
  Printf.printf "before delete: %s\n"
    (Option.value ~default:"missing" (Fs.read !fs ["d"; "tmp.txt"]));
  fs := Fs.delete !fs ["d"; "tmp.txt"];
  Printf.printf "after  delete: %s\n"
    (match Fs.read !fs ["d"; "tmp.txt"] with None -> "None [deleted]" | Some s -> s)

(* ------------------------------------------------------------------ *)
(* 5. SNAPSHOT ISOLATION (persistence)                                 *)
(* ------------------------------------------------------------------ *)
let () =
  section "Snapshot Isolation";

  (* Each operation returns a NEW snapshot; old ones are unaffected *)
  let snap1 = Fs.touch Fs.empty ["file.txt"] "version 1" in
  let snap2 = Fs.touch snap1    ["file.txt"] "version 2" in
  let snap3 = Fs.delete snap2   ["file.txt"] in

  Printf.printf "snap1 -> %s\n"
    (Option.value ~default:"gone" (Fs.read snap1 ["file.txt"]));
  Printf.printf "snap2 -> %s\n"
    (Option.value ~default:"gone" (Fs.read snap2 ["file.txt"]));
  Printf.printf "snap3 -> %s\n"
    (match Fs.read snap3 ["file.txt"] with None -> "None [deleted]" | Some s -> s)

(* ------------------------------------------------------------------ *)
(* 6. HISTORY / COMMITS                                                *)
(* ------------------------------------------------------------------ *)
let () =
  section "History (Commits & Checkout)";

  (* init creates a repo around a starting filesystem *)
  let repo = ref (History.init Fs.empty) in

  (* Make some changes, then commit each one *)
  let fs1 = Fs.mkdir Fs.empty ["projects"] in
  repo := History.commit { !repo with working = fs1 } "create /projects";

  let fs2 = Fs.touch (History.latest !repo) ["projects"; "todo.txt"] "Buy milk" in
  repo := History.commit { !repo with working = fs2 } "add todo.txt";

  let fs3 = Fs.touch (History.latest !repo) ["projects"; "todo.txt"] "Buy milk\nWrite code" in
  repo := History.commit { !repo with working = fs3 } "update todo.txt";

  (* Read the latest working file *)
  Printf.printf "latest todo.txt:\n  %s\n"
    (Option.value ~default:"(missing)"
      (Fs.read (History.latest !repo) ["projects"; "todo.txt"]));

  (* log — list all commits, newest first *)
  Printf.printf "\nCommit log (newest first):\n";
  List.iter (fun (c : History.commit) ->
    Printf.printf "  [%d] %s\n" c.id c.message
  ) (History.log !repo);

  (* checkout — go back to commit 1 (just /projects dir, no file) *)
  let old_repo = History.checkout !repo 1 in
  Printf.printf "\nAfter checkout to commit 1:\n";
  Printf.printf "  todo.txt exists? %s\n"
    (match Fs.read (History.latest old_repo) ["projects"; "todo.txt"] with
     | None   -> "No [as expected]"
     | Some _ -> "Yes");

  (* original repo unchanged by checkout *)
  Printf.printf "  original repo still has todo.txt? %s\n"
    (match Fs.read (History.latest !repo) ["projects"; "todo.txt"] with
     | Some _ -> "Yes [snapshot preserved]"
     | None   -> "No [bug!]")
