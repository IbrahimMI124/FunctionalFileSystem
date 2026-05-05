(* fs_test.ml — imperative style
   Exact same assertions as the functional fs_test.ml.
   The difference is that intermediate filesystem values are
   stored in mutable ref variables and updated with <- instead
   of being chained with let-bindings.
   History tests are kept identical to allow direct comparison.
*)

let () =
  (* -- mkdir / read ------------------------------------------------- *)
  let fs = ref Fs.empty in
  fs := Fs.mkdir !fs [ "a"; "b" ];
  assert (Fs.read !fs [ "a"; "b"; "missing.txt" ] = None);

  (* touch writes a file, read returns it *)
  let fs2 = ref !fs in
  fs2 := Fs.touch !fs2 [ "a"; "b"; "x.txt" ] "hi";
  assert (Fs.read !fs2 [ "a"; "b"; "x.txt" ] = Some "hi");

  (* overwriting a file: previous snapshot unchanged *)
  let fs3 = ref !fs2 in
  fs3 := Fs.touch !fs3 [ "a"; "b"; "x.txt" ] "bye";
  assert (Fs.read !fs2 [ "a"; "b"; "x.txt" ] = Some "hi");
  assert (Fs.read !fs3 [ "a"; "b"; "x.txt" ] = Some "bye");

  (* -- Path helpers -------------------------------------------------- *)
  let p = Path.of_string "/a//b/c/" in
  assert (p = [ "a"; "b"; "c" ]);
  assert (Path.to_string p = "/a/b/c");
  assert (Path.to_string [] = "/");

  (* read on a directory returns None *)
  assert (Fs.read !fs3 [ "a"; "b" ] = None);
  assert (Fs.read !fs  [ "a"; "b"; "x.txt" ] = None);

  (* -- Error cases --------------------------------------------------- *)

  (* mkdir under a file should fail *)
  let mkdir_failed =
    try
      let _ = Fs.mkdir !fs3 [ "a"; "b"; "x.txt"; "sub" ] in
      false
    with Failure _ -> true
  in
  assert mkdir_failed;

  (* touch where a directory exists should fail *)
  let fs4 = ref !fs3 in
  fs4 := Fs.mkdir !fs4 [ "dir" ];
  let touch_failed =
    try
      let _ = Fs.touch !fs4 [ "dir" ] "nope" in
      false
    with Failure _ -> true
  in
  assert touch_failed;

  (* -- ls ------------------------------------------------------------ *)
  let fs5 = ref Fs.empty in
  fs5 := Fs.mkdir !fs5 [ "d" ];
  fs5 := Fs.touch !fs5 [ "d"; "b.txt" ] "b";
  fs5 := Fs.touch !fs5 [ "d"; "a.txt" ] "a";
  assert (Fs.ls !fs5 [ "d" ] = [ "a.txt"; "b.txt" ]);

  (* -- cp ------------------------------------------------------------ *)
  let fs6 = ref (Fs.cp !fs5 [ "d"; "a.txt" ] [ "d"; "c.txt" ]) in
  assert (Fs.read !fs6 [ "d"; "a.txt" ] = Some "a");
  assert (Fs.read !fs6 [ "d"; "c.txt" ] = Some "a");

  (* -- mv ------------------------------------------------------------ *)
  let fs7 = ref (Fs.mv !fs6 [ "d"; "b.txt" ] [ "d"; "b2.txt" ]) in
  assert (Fs.read !fs7 [ "d"; "b.txt" ]  = None);
  assert (Fs.read !fs7 [ "d"; "b2.txt" ] = Some "b");

  (* -- delete -------------------------------------------------------- *)
  let fs8 = ref (Fs.delete !fs7 [ "d"; "a.txt" ]) in
  assert (Fs.read !fs8 [ "d"; "a.txt" ] = None);

  (* -- Persistence stress test: prior snapshots unchanged ------------ *)
  let fsp0 = ref Fs.empty in
  let fsp1 = ref (Fs.mkdir !fsp0 [ "p" ]) in
  let fsp2 = ref (Fs.touch !fsp1 [ "p"; "f.txt" ] "v") in
  let fsp3 = ref (Fs.delete !fsp2 [ "p"; "f.txt" ]) in
  assert (Fs.read !fsp1 [ "p"; "f.txt" ] = None);
  assert (Fs.read !fsp2 [ "p"; "f.txt" ] = Some "v");
  assert (Fs.read !fsp3 [ "p"; "f.txt" ] = None);

  (* -- Deep path: 100 nested directories ----------------------------- *)
  let make_deep n =
    (* Imperative: build path list using a for loop and a ref. *)
    let acc = ref [] in
    for i = n downto 1 do
      acc := ("d" ^ string_of_int i) :: !acc
    done;
    !acc
  in
  let deep_path = make_deep 100 in
  let fs_deep = ref (Fs.mkdir Fs.empty deep_path) in
  let file_path = deep_path @ [ "leaf.txt" ] in
  fs_deep := Fs.touch !fs_deep file_path "deep";
  assert (Fs.read !fs_deep file_path = Some "deep");

  (* -- Copy directory subtree ---------------------------------------- *)
  let fs_sub = ref Fs.empty in
  fs_sub := Fs.mkdir !fs_sub [ "src" ];
  fs_sub := Fs.mkdir !fs_sub [ "src"; "inner" ];
  fs_sub := Fs.touch !fs_sub [ "src"; "inner"; "note.txt" ] "n";
  fs_sub := Fs.cp !fs_sub [ "src" ] [ "dst" ];
  assert (Fs.read !fs_sub [ "src"; "inner"; "note.txt" ] = Some "n");
  assert (Fs.read !fs_sub [ "dst"; "inner"; "note.txt" ] = Some "n");

  (* -- History layer ------------------------------------------------- *)
  let repo = ref (History.init Fs.empty) in
  repo := History.commit { !repo with working = Fs.mkdir Fs.empty [ "h" ] } "mkdir h";
  let fs_with_x = Fs.touch (History.latest !repo) [ "h"; "x" ] "1" in
  repo := History.commit { !repo with working = fs_with_x } "add x";
  let repo2 = ref !repo in
  let repo2_checked = ref (History.checkout !repo2 1) in
  assert (Fs.read (History.latest !repo2) [ "h"; "x" ] = Some "1");
  assert (Fs.read (History.latest !repo2_checked) [ "h"; "x" ] = None);
  let log_ids =
    History.log !repo2
    |> List.map (fun (c : History.commit) -> c.id)
  in
  assert (log_ids = [ 2; 1; 0 ])
