type error =
| Bad_magic_number
| No_section of string

exception Error of error

type debug_info = {
  di_paths  : string list;
  di_events : Instruct.debug_event list;
}

val pp_debug_event      : Format.formatter -> Instruct.debug_event -> unit
val show_debug_event    : Instruct.debug_event -> string
val compare_debug_event : Instruct.debug_event -> Instruct.debug_event -> int

val read : in_channel -> debug_info
