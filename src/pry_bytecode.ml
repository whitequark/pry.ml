open Instruct

type error =
| Bad_magic_number
| No_section of string

exception Error of error

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
