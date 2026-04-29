let () =
  let fs0 = Fs.empty in
  let fs1 = Fs.mkdir fs0 [ "docs" ] in
  let fs2 = Fs.touch fs1 [ "docs"; "hello.txt" ] "Hello from an immutable FS!" in
  let repo0 = History.init fs0 in
  let repo1 = History.commit { repo0 with working = fs1 } "mkdir docs" in
  let repo2 = History.commit { repo1 with working = fs2 } "add hello" in
  let repo2 = History.checkout repo2 2 in
  match Fs.read (History.latest repo2) [ "docs"; "hello.txt" ] with
  | None -> print_endline "(missing)"
  | Some s -> print_endline s
