type error =
| Bad_magic_number
| No_section of string

exception Error of error

type debug_info = {
  di_paths  : string list;
  di_events : Instruct.debug_event list;
}

val read : in_channel -> debug_info
