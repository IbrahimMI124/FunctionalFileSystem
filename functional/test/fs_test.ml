let () =
  (* mkdir creates (or confirms) a directory *)
  let fs1 = Fs.mkdir Fs.empty [ "a"; "b" ] in
  assert (Fs.read fs1 [ "a"; "b"; "missing.txt" ] = None);

  (* touch writes a file, read returns it *)
  let fs2 = Fs.touch fs1 [ "a"; "b"; "x.txt" ] "hi" in
  assert (Fs.read fs2 [ "a"; "b"; "x.txt" ] = Some "hi");

  (* overwriting a file returns a new version *)
  let fs3 = Fs.touch fs2 [ "a"; "b"; "x.txt" ] "bye" in
  assert (Fs.read fs2 [ "a"; "b"; "x.txt" ] = Some "hi");
  assert (Fs.read fs3 [ "a"; "b"; "x.txt" ] = Some "bye");

  (* Path helpers *)
  let p = Path.of_string "/a//b/c/" in
  assert (p = [ "a"; "b"; "c" ]);
  assert (Path.to_string p = "/a/b/c");
  assert (Path.to_string [] = "/");

  (* read on a directory returns None *)
  assert (Fs.read fs3 [ "a"; "b" ] = None);
  assert (Fs.read fs1 [ "a"; "b"; "x.txt" ] = None);


  (* invalid traversal: mkdir under a file should fail *)
  let mkdir_failed =
    try
      let _ = Fs.mkdir fs3 [ "a"; "b"; "x.txt"; "sub" ] in
      false
    with Failure _ -> true
  in
  assert mkdir_failed;

  (* invalid target: touch where a directory exists should fail *)
  let fs4 = Fs.mkdir fs3 [ "dir" ] in
  let touch_failed =
    try
      let _ = Fs.touch fs4 [ "dir" ] "nope" in
      false
    with Failure _ -> true
  in
  assert touch_failed;

  (* ls lists directory entries (sorted by name) *)
  let fs5_0 = Fs.mkdir Fs.empty [ "d" ] in
  let fs5_1 = Fs.touch fs5_0 [ "d"; "b.txt" ] "b" in
  let fs5 = Fs.touch fs5_1 [ "d"; "a.txt" ] "a" in
  assert (Fs.ls fs5 [ "d" ] = [ "a.txt"; "b.txt" ]);

  (* cp copies a node without removing source *)
  let fs6 = Fs.cp fs5 [ "d"; "a.txt" ] [ "d"; "c.txt" ] in
  assert (Fs.read fs6 [ "d"; "a.txt" ] = Some "a");
  assert (Fs.read fs6 [ "d"; "c.txt" ] = Some "a");

  (* mv moves a node and removes source *)
  let fs7 = Fs.mv fs6 [ "d"; "b.txt" ] [ "d"; "b2.txt" ] in
  assert (Fs.read fs7 [ "d"; "b.txt" ] = None);
  assert (Fs.read fs7 [ "d"; "b2.txt" ] = Some "b");

  (* delete removes a node *)
  let fs8 = Fs.delete fs7 [ "d"; "a.txt" ] in
  assert (Fs.read fs8 [ "d"; "a.txt" ] = None);

  (* persistence stress test: prior versions unchanged *)
  let fs0 = Fs.empty in
  let fs1_p = Fs.mkdir fs0 [ "p" ] in
  let fs2_p = Fs.touch fs1_p [ "p"; "f.txt" ] "v" in
  let fs3_p = Fs.delete fs2_p [ "p"; "f.txt" ] in
  assert (Fs.read fs1_p [ "p"; "f.txt" ] = None);
  assert (Fs.read fs2_p [ "p"; "f.txt" ] = Some "v");
  assert (Fs.read fs3_p [ "p"; "f.txt" ] = None);

  (* deep path test: 100 nested directories *)
  let rec make_deep n acc =
    if n = 0 then acc else make_deep (n - 1) (acc @ [ "d" ^ string_of_int n ])
  in
  let deep_path = make_deep 100 [] in
  let fs_deep = Fs.mkdir Fs.empty deep_path in
  let file_path = deep_path @ [ "leaf.txt" ] in
  let fs_deep2 = Fs.touch fs_deep file_path "deep" in
  assert (Fs.read fs_deep2 file_path = Some "deep");

  (* copy directory test: copy subtree *)
  let fs_sub0 = Fs.mkdir Fs.empty [ "src" ] in
  let fs_sub1 = Fs.mkdir fs_sub0 [ "src"; "inner" ] in
  let fs_sub2 = Fs.touch fs_sub1 [ "src"; "inner"; "note.txt" ] "n" in
  let fs_sub3 = Fs.cp fs_sub2 [ "src" ] [ "dst" ] in
  assert (Fs.read fs_sub3 [ "src"; "inner"; "note.txt" ] = Some "n");
  assert (Fs.read fs_sub3 [ "dst"; "inner"; "note.txt" ] = Some "n");

  (* history layer tests *)
  let repo0 = History.init Fs.empty in
  let repo1 = History.commit { repo0 with working = Fs.mkdir Fs.empty [ "h" ] } "mkdir h" in
  let repo2 = History.commit { repo1 with working = Fs.touch (History.latest repo1) [ "h"; "x" ] "1" } "add x" in
  let repo2_checked = History.checkout repo2 1 in
  assert (Fs.read (History.latest repo2) [ "h"; "x" ] = Some "1");
  assert (Fs.read (History.latest repo2_checked) [ "h"; "x" ] = None);
  let log_ids =
    History.log repo2
    |> List.map (fun (c : History.commit) -> c.id)
  in
  assert (log_ids = [ 2; 1; 0 ])
