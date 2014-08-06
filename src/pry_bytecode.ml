open Instruct

type error =
| Bad_magic_number
| No_section of string

exception Error of error

let pp_ident_tbl pp fmt tbl =
  Format.fprintf fmt "{@[<hov> ";
  tbl |> Ident.iter (fun id x ->
    Format.fprintf fmt "%s.%d => %a;@ " id.Ident.name id.Ident.stamp pp x);
  Format.fprintf fmt " @]}"

type compilation_env = Instruct.compilation_env =
  { ce_stack: int Ident.tbl [@polyprinter pp_ident_tbl];
    ce_heap: int Ident.tbl [@polyprinter pp_ident_tbl];
    ce_rec: int Ident.tbl [@polyprinter pp_ident_tbl] }

and debug_event = Instruct.debug_event =
  { mutable ev_pos: int;
    ev_module: string;
    ev_loc: Location.t [@printer Location.print_loc];
    ev_kind: debug_event_kind;
    ev_info: debug_event_info;
    ev_typenv: Env.summary [@opaque];
    ev_typsubst: Subst.t [@opaque];
    ev_compenv: compilation_env;
    ev_stacksize: int;
    ev_repr: debug_event_repr }

and debug_event_kind = Instruct.debug_event_kind =
    Event_before
  | Event_after of Types.type_expr [@printer Printtyp.type_expr]
  | Event_pseudo

and debug_event_info = Instruct.debug_event_info =
    Event_function
  | Event_return of int
  | Event_other

and debug_event_repr = Instruct.debug_event_repr =
    Event_none
  | Event_parent of int ref
  | Event_child of int ref

[@@deriving Show]

let compare_debug_event { ev_pos = a } { ev_pos = b } =
  compare a b

type debug_info = {
  di_paths  : string list;
  di_events : Instruct.debug_event list;
}

let read_toc ic =
  let pos_trailer = in_channel_length ic - 16 in
  seek_in ic pos_trailer;
  let num_sections = input_binary_int ic in
  let header = really_input_string ic (String.length Config.exec_magic_number) in
  if header <> Config.exec_magic_number then failwith "Bad_magic_number";
  seek_in ic (pos_trailer - 8 * num_sections);
  let rec read_section_table idx sections =
    if idx < num_sections then
      let name = really_input_string ic 4 in
      let len = input_binary_int ic in
      read_section_table (idx + 1) ((name, len) :: sections)
    else
      sections
  in
  read_section_table 0 []

let seek_section ic toc target =
  let rec loop offset sections =
    match sections with
    | [] -> raise (Error (No_section target))
    | (name, len) :: _ when name = target ->
      seek_in ic (offset - len); len
    | (_, len) :: sections ->
      loop (offset - len) sections
  in
  loop (in_channel_length ic - 16 - 8 * List.length toc) toc

module StringSet = Set.Make(String)

let relocate_event origin ev =
  ev.ev_pos <- origin + ev.ev_pos;
  match ev.ev_repr with
  | Event_parent repr -> repr := ev.ev_pos; ev
  | _                 -> ev

let read_dbug ic toc =
  ignore (seek_section ic toc "DBUG");
  let rec loop events paths i =
    if i = 0 then
      events, StringSet.elements paths
    else
      let origin = input_binary_int ic in
      let events = (List.map (relocate_event origin) (input_value ic)) @ events in
      let paths  = (List.fold_right StringSet.add (input_value ic) paths) in
      loop events paths (i - 1)
  in
  loop [] StringSet.empty (input_binary_int ic)

let read ic =
  let toc = read_toc ic in
  let di_events, di_paths = read_dbug ic toc in
  { di_paths; di_events }
