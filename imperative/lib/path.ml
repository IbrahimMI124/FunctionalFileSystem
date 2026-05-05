(* path.ml — imperative style
   Same public interface as the functional version.
   Path is simply a string list; the two helpers use
   imperative Buffer / String operations instead of
   pure-functional combinators. *)

type t = string list

(* Split a Unix-style path string on '/', dropping empty segments
   (handles leading/trailing slashes and double slashes). *)
let of_string (s : string) : t =
  let parts = ref [] in
  let buf = Buffer.create 16 in
  (* Iterate character-by-character — purely imperative. *)
  for i = 0 to String.length s - 1 do
    let c = s.[i] in
    if c = '/' then begin
      if Buffer.length buf > 0 then begin
        parts := Buffer.contents buf :: !parts;
        Buffer.clear buf
      end
    end else
      Buffer.add_char buf c
  done;
  (* Don't forget the last segment if there is no trailing '/'. *)
  if Buffer.length buf > 0 then
    parts := Buffer.contents buf :: !parts;
  List.rev !parts

(* Join a path list back to a slash-separated string. *)
let to_string (p : t) : string =
  match p with
  | [] -> "/"
  | parts ->
      let buf = Buffer.create 64 in
      List.iter (fun seg ->
        Buffer.add_char buf '/';
        Buffer.add_string buf seg
      ) parts;
      Buffer.contents buf
