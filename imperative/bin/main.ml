(* main.ml — imperative style demo
   Mirrors the functional main.ml exactly in what it does,
   but via imperative operations (mutable references for
   intermediate fs/repo values). *)

let () =
  (* Start with an empty, mutable filesystem snapshot. *)
  let fs = ref Fs.empty in
  fs := Fs.mkdir !fs [ "docs" ];

  let fs_with_file = Fs.touch !fs [ "docs"; "hello.txt" ] "Hello from an imperative FS!" in

  (* Build up history imperatively using mutable repo. *)
  let repo = ref (History.init Fs.empty) in
  repo := History.commit { !repo with working = !fs } "mkdir docs";
  repo := History.commit { !repo with working = fs_with_file } "add hello";
  repo := History.checkout !repo 2;

  (* Read back the file and print it. *)
  match Fs.read (History.latest !repo) [ "docs"; "hello.txt" ] with
  | None   -> print_endline "(missing)"
  | Some s -> print_endline s
