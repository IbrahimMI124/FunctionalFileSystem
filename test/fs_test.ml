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
  assert (Fs.read fs8 [ "d"; "a.txt" ] = None)
