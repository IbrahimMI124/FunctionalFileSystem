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
  assert touch_failed
