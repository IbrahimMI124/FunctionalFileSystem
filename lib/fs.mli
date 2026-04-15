type t

val empty : t

val mkdir : t -> string list -> t

val touch : t -> string list -> string -> t

val read : t -> string list -> string option
