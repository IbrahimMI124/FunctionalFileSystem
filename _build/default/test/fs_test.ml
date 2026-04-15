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
  assert (Fs.read fs3 [ "a"; "b"; "x.txt" ] = Some "bye")
