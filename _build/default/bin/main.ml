let () =
  let fs0 = Fs.empty in
  let fs1 = Fs.mkdir fs0 [ "docs" ] in
  let fs = Fs.touch fs1 [ "docs"; "hello.txt" ] "Hello from an immutable FS!" in
  match Fs.read fs [ "docs"; "hello.txt" ] with
  | None -> print_endline "(missing)"
  | Some s -> print_endline s
