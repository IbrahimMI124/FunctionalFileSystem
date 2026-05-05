(* fs.mli — identical public interface to the functional version.
   Consumers cannot distinguish between the two implementations. *)

type t

val empty : t

val mkdir  : t -> string list -> t
val touch  : t -> string list -> string -> t
val read   : t -> string list -> string option
val delete : t -> string list -> t
val ls     : t -> string list -> string list
val mv     : t -> string list -> string list -> t
val cp     : t -> string list -> string list -> t
