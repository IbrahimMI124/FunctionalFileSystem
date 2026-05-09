(* fs.mli — imperative interface with in-place mutation.
   Writes mutate the filesystem directly and return the same [t].
   Use [snapshot] to capture an isolated copy for History commits. *)

type t

val empty : t

val snapshot : t -> t

val mkdir  : t -> string list -> t
val touch  : t -> string list -> string -> t
val read   : t -> string list -> string option
val delete : t -> string list -> t
val ls     : t -> string list -> string list
val mv     : t -> string list -> string list -> t
val cp     : t -> string list -> string list -> t
