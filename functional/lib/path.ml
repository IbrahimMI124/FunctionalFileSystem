type t = string list

let of_string (s : string) : t =
  (* Split on '/', ignoring empty segments (so "/a//b/" -> ["a"; "b"]). *)
  String.split_on_char '/' s |> List.filter (fun part -> part <> "")

let to_string (p : t) : string =
  match p with
  | [] -> "/"
  | parts -> "/" ^ String.concat "/" parts
